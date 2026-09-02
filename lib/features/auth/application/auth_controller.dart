import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/core/storage/local_storage.dart';
import 'package:sgit_studio_flutter/data/transport/ffi/sgit_request_ffi.dart';
import 'package:sgit_studio_flutter/data/repositories/auth_repository.dart';

/// 登录态。`token == null` 即未登录。
@immutable
class AuthState {
  const AuthState({
    this.token,
    this.cid,
    this.loading = false,
    this.error,
  });

  final String? token;
  final String? cid;
  final bool loading;
  final String? error;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  AuthState copyWith({
    String? token,
    String? cid,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      AuthState(
        token: token ?? this.token,
        cid: cid ?? this.cid,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthController extends Notifier<AuthState> {
  final AuthRepository _service = const AuthRepository();

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
    final looksLoggedIn = SgitRequestFfi.instance.isAuthenticated();
    if (looksLoggedIn) {
      // 不 await：让界面先渲染，校验结果回来再纠正。
      Future.microtask(validateSession);
    }
    return AuthState(token: looksLoggedIn ? _kSessionMark : null);
  }

  /// 校验缓存会话是否仍然有效，失效则清掉登录态（路由会自动跳登录页）。
  ///
  /// ⚠️ 为什么必须有这一步：`isAuthenticated()` 只看本地有没有令牌，**不校验**。
  /// 令牌过期或换了登录路径后，应用会以为已登录 → 进主界面 → 每个请求都报
  /// "用户未登录" → 用户还回不到登录页，只能手动清 localStorage。真踩过这个坑。
  Future<void> validateSession() async {
    final ok = await SgitRequestFfi.instance.validateSession();
    if (ok || !state.isAuthenticated) return;
    await LocalStorage.instance.setAuthToken(null);
    state = const AuthState();
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
      return true;
    } catch (e) {
      final msg = e.toString().replaceFirst(RegExp(r'^ApiException\([^)]*\):\s*'), '');
      state = AuthState(error: msg);
      return false;
    }
  }

  Future<void> logout() async {
    // 清 FFI 侧会话(Web = wasm + localStorage;桌面 = 本地标记)。
    SgitRequestFfi.instance.logout();
    await LocalStorage.instance.setAuthToken(null);
    state = const AuthState();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
