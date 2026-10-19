import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/core/result/auth_failure.dart';
import 'package:sgit_studio_flutter/core/storage/local_storage.dart';
import 'package:sgit_studio_flutter/data/transport/ffi/sgit_request_ffi.dart';
import 'package:sgit_studio_flutter/data/repositories/auth_repository.dart';
import 'package:sgit_studio_flutter/features/chat/application/session_sync_controller.dart';

/// 登录态。`token == null` 即未登录。
@immutable
class AuthState {
  const AuthState({
    this.token,
    this.cid,
    this.loading = false,
    this.error,
    this.sessionExpired = false,
  });

  final String? token;
  final String? cid;
  final bool loading;

  /// 登录失败的具体原因（登录页直接展示）。
  final String? error;

  /// 是被动失效（token 过期 / 服务端判未登录）踢出来的，不是用户自己登出。
  ///
  /// 登录页据此显示「登录已过期，请重新登录」而不是后端那句
  /// `认证失败: 无效的user_auth_token: ...` —— 后者对用户没有任何意义。
  final bool sessionExpired;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  AuthState copyWith({
    String? token,
    String? cid,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? sessionExpired,
  }) =>
      AuthState(
        token: token ?? this.token,
        cid: cid ?? this.cid,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        sessionExpired: sessionExpired ?? this.sessionExpired,
      );
}

class AuthController extends Notifier<AuthState> {
  final AuthRepository _service = const AuthRepository();

  /// 已销毁标记。`Notifier` 的 ref 在 Riverpod 2 里没有 `mounted`，
  /// 而 [_onAuthFailure] 要在一帧之后的微任务里改 state —— 那时 provider
  /// 可能已经不在了（热重载、测试拆容器）。自己记一个。
  bool _disposed = false;

  /// 登录态标记。真令牌在 FFI 侧会话里（Web 甚至不回传给 Dart），
  /// AuthState.token 只用来表示「已登录」，不参与任何请求。
  static const String _kSessionMark = 'authenticated';

  /// 登录态以 **FFI 侧会话**为准（桌面 = .so，Web = wasm，各自持有真会话），
  /// Dart 不自己判定身份。
  ///
  /// 这里先用**同步**的本地判断（有没有令牌）给个初值，避免启动闪一下登录页；
  /// 随后 [validateSession] 异步校验令牌**是否还有效**。
  @override
  AuthState build() {
    // 订阅全局鉴权失败信号：任何仓储/控制器识别到 token 失效都会广播到
    // 这里，统一清会话 → 路由监听随之跳登录页。
    //
    // ⚠️ 这是「登录态运行中失效」唯一的兜底路径。没有它，各控制器只能各自
    // catch 住咽掉，用户看到的就是"点了没反应、列表空白"，永远回不到登录页。
    AuthFailure.addListener(_onAuthFailure);
    ref.onDispose(() {
      _disposed = true;
      AuthFailure.removeListener(_onAuthFailure);
    });

    final looksLoggedIn = SgitRequestFfi.instance.isAuthenticated();
    if (looksLoggedIn) {
      // 不 await：让界面先渲染，校验结果回来再纠正。
      Future.microtask(validateSession);
    }
    return AuthState(token: looksLoggedIn ? _kSessionMark : null);
  }

  void _onAuthFailure(AuthFailureEvent event) {
    // 已经未登录就不用再动 —— 否则每次失败都会重置一次 state，把登录页上
    // 用户正在输入时挂着的错误提示反复冲刷掉。
    if (!state.isAuthenticated) return;
    // ⚠️ 不能在这里同步改 state。信号可能来自某个 provider 的 `build()` 里
    // 发起的请求回调，而 Riverpod 在 build 期间禁止改 provider
    // （`Tried to modify a provider while the widget tree was building`），
    // 异常会被 listener guard 吞掉，表现为「什么也没发生」—— 正是要修的症状。
    //
    // 与 `thread_list_controller._scheduleReload` 同一个绕法。
    Future<void>.microtask(() {
      if (_disposed || !state.isAuthenticated) return;
      invalidate(reason: event.message);
    });
  }

  /// 校验缓存会话是否仍然有效，失效则清掉登录态（路由会自动跳登录页）。
  ///
  /// ⚠️ 为什么必须有这一步：`isAuthenticated()` 只回答「有没有会话」，
  /// **不向服务端校验**。令牌过期后应用会以为已登录 → 进主界面 → 每个请求
  /// 都报未登录 → 用户还回不到登录页，只能手动清 localStorage。真踩过这个坑。
  ///
  /// 桌面端原来这一步是退化成 `isAuthenticated()` 的空转（见
  /// `sgit_request_ffi_io.dart` 的注释）；现在两端都走真校验。
  Future<void> validateSession() async {
    final ok = await SgitRequestFfi.instance.validateSession();
    if (ok) {
      // 成功也留一行：失败路径各有各的日志，成功路径一个字都不打的话，
      // 「校验过了」和「压根没跑」在日志上长得一模一样（`kernel` 建连那处
      // 踩过同一个坑）。排查「为什么弹回登录页」时这条是基线。
      debugPrint('[auth] 启动会话校验通过');
      return;
    }
    if (!state.isAuthenticated) return;
    debugPrint('[auth] 启动会话校验未通过，清会话并回登录页');
    await LocalStorage.instance.setAuthToken(null);
    // 用 `invalidate` 而不是裸状态：它会同步通知 Rust 侧清进程内会话，
    // 并让登录页显示「登录已过期」而不是一片空白。
    invalidate();
  }

  /// 运行中判定身份失效：清会话并留在登录页。
  ///
  /// ⚠️ 与 [logout] 分开：登出是用户主动操作，不该报错；这里是**被动失效**，
  /// 要在登录页上说清楚「为什么被踢出来」，否则用户以为是应用坏了。
  ///
  /// 不 await [SgitRequestFfi.logout]（它是同步的，但语义上是副作用）：
  /// 调用方可能是 `catch` 分支，状态切换越快越好。
  void invalidate({String? reason}) {
    SgitRequestFfi.instance.logout();
    unawaited(LocalStorage.instance.setAuthToken(null));
    // 不透传后端原话：`认证失败: 无效的user_auth_token: ...` 对用户没有意义，
    // 登录页统一显示本地化的「登录已过期」。原话留在 debugPrint 里供排查。
    if (reason != null && reason.isNotEmpty) {
      debugPrint('[auth] 会话失效：$reason');
    }
    state = const AuthState(sessionExpired: true);
  }

  /// V2 登录：手机号/用户名 + 密码 + 图形验证码。成功返回 true。
  Future<bool> login({
    required String identifier,
    required String password,
    required String captchaId,
    required String captchaCode,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await _service.login(
        identifier: identifier,
        password: password,
        captchaId: captchaId,
        captchaCode: captchaCode,
      );
      // 桌面端 .so 会回传令牌，落一份本地标记供刷新后判断；Web 端令牌留在 wasm 会话里
      // (result.token 为空)，这里只记一个标记。两端都不用它发请求。
      if (result.token.isNotEmpty) {
        await LocalStorage.instance.setAuthToken(result.token);
      }
      state = AuthState(token: _kSessionMark, cid: result.cid);

      // ⚠️ **登录后同步一次会话历史**，别等第一轮对话结束。
      //
      // 同步器原本只有三个触发点（一轮对话结束去抖 30s / 切云端前 / 退出前），
      // 全都要求用户**先做点什么**。于是「换台机器登录」这个最需要历史的时刻
      // 反而一条都没有：本机 `<cid_home>/sessions/` 是空的，列表也就是空的，
      // 而服务器上那份好好地在。
      //
      // 同步本身是双向的，但这个时机的重点在**下行**；顺带把上次离线期间
      // 没推上去的补齐也没坏处。
      //
      // 不 await：登录要立刻进主界面。列表那边自己会在内核连上时再拉一次
      // （thread_list_controller 监听 capabilities），所以同步落地后不需要
      // 这里再去戳它 —— 用户看到的是"进去先有旧的、稍后补齐"。
      //
      // 未启用同步时（服务端进程）是 no-op，不会白跑。
      unawaited(ref.read(sessionSyncProvider).syncNow());
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst(RegExp(r'^ApiException\([^)]*\):\s*'), '');
      // 登录请求本身被判鉴权失败（极少见，比如服务端刚重启导致会话表丢了）时，
      // 不要把失败再广播回 invalidate —— 那会把用户正在填的表单清掉。
      state = AuthState(error: msg);
      return false;
    }
  }

  Future<void> logout() async {
    // 清 FFI 侧会话(Web = wasm + localStorage;桌面 = `.so` 会话 + 内核/聊天连接)。
    SgitRequestFfi.instance.logout();
    await LocalStorage.instance.setAuthToken(null);
    state = const AuthState();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
