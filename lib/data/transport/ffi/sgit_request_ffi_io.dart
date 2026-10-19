import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'package:sgit_studio_flutter/core/storage/local_storage.dart';
import 'package:sgit_studio_flutter/data/transport/ffi/sgit_request_ffi_types.dart';

// ---- C 函数签名（对齐 sgit-ffi/src/lib.rs） ----
typedef _ProbeC = Pointer<Utf8> Function();
typedef _ProbeDart = Pointer<Utf8> Function();

typedef _CaptchaC = Pointer<Utf8> Function();
typedef _CaptchaDart = Pointer<Utf8> Function();

typedef _LoginC = Pointer<Utf8> Function(
    Pointer<Utf8> id, Pointer<Utf8> pwd, Pointer<Utf8> cid, Pointer<Utf8> code);
typedef _LoginDart = Pointer<Utf8> Function(
    Pointer<Utf8> id, Pointer<Utf8> pwd, Pointer<Utf8> cid, Pointer<Utf8> code);

typedef _RequestC = Pointer<Utf8> Function(
    Pointer<Utf8> operation, Pointer<Utf8> action, Pointer<Utf8> payload);
typedef _RequestDart = Pointer<Utf8> Function(
    Pointer<Utf8> operation, Pointer<Utf8> action, Pointer<Utf8> payload);

typedef _FreeC = Void Function(Pointer<Utf8> ptr);
typedef _FreeDart = void Function(Pointer<Utf8> ptr);

// 会话符号（对齐 sgit-ffi/src/lib.rs 的 `sgit_is_authenticated` /
// `sgit_validate_session` / `sgit_logout`）。
typedef _BoolC = Bool Function();
typedef _BoolDart = bool Function();
typedef _VoidC = Void Function();
typedef _VoidDart = void Function();

/// FFI 封装 sgit-ffi.dll —— 全部委托 sgcode sgit-services 现成实现。
///
/// 登录 / 加密请求 / 端点池 / 图形验证码全在 Rust 侧完成，Dart 只传参拿 JSON。
/// 详见 memory `flutter-kernel-access-ffi-only`。
class SgitRequestFfi {
  SgitRequestFfi._(DynamicLibrary lib)
      : _probe = lib.lookupFunction<_ProbeC, _ProbeDart>('sgit_probe_endpoint'),
        _captcha = lib.lookupFunction<_CaptchaC, _CaptchaDart>('sgit_image_captcha'),
        _login = lib.lookupFunction<_LoginC, _LoginDart>('sgit_login_v2'),
        _request = lib.lookupFunction<_RequestC, _RequestDart>('sgit_request'),
        _free = lib.lookupFunction<_FreeC, _FreeDart>('free_string'),
        // 会话符号：`sgit_is_authenticated` / `sgit_logout` 早就导出
        // （lib.rs:524 / :542），Dart 侧一直没绑 —— 于是桌面端「是否已登录」
        // 只看 LocalStorage 的一个字符串标记，Rust 说没会话它也不知道。
        // 这是「token 过期后永远进不了登录页」的根因。
        _isAuthenticated = _lookupBool(lib, 'sgit_is_authenticated'),
        _validateSession = _lookupBool(lib, 'sgit_validate_session'),
        _logout = _lookupVoid(lib, 'sgit_logout');

  final _ProbeDart _probe;
  final _CaptchaDart _captcha;
  final _LoginDart _login;
  final _RequestDart _request;
  final _FreeDart _free;

  /// 进程内是否有会话。**同步、不发网络**（Rust 只查内存槽）。
  final _BoolDart? _isAuthenticated;

  /// 向服务端校验会话是否仍然有效。Rust 侧可能还没这个符号（旧 DLL）→ null。
  final _BoolDart? _validateSession;

  final _VoidDart? _logout;

  /// 可选符号：旧版 `sgit_ffi.dll` 没有时返回 null，调用方自行降级。
  ///
  /// ⚠️ 不能让「库缺一个符号」把整个 FFI 门面构造炸掉 —— 那样连登录页都起不来。
  ///
  /// 两个函数各写一份而不是抽泛型：`lookupFunction` 的类型参数必须是**字面量**
  /// native 函数类型，泛型形参传进去直接编译不过（`must_be_a_native_function_type`）。
  static _BoolDart? _lookupBool(DynamicLibrary lib, String name) {
    try {
      return lib.lookupFunction<_BoolC, _BoolDart>(name);
    } catch (_) {
      return null;
    }
  }

  static _VoidDart? _lookupVoid(DynamicLibrary lib, String name) {
    try {
      return lib.lookupFunction<_VoidC, _VoidDart>(name);
    } catch (_) {
      return null;
    }
  }

  static SgitRequestFfi? _instance;
  static SgitRequestFfi get instance => _instance ??= SgitRequestFfi._(_open());

  static DynamicLibrary _open() {
    if (Platform.isWindows) return DynamicLibrary.open('sgit_ffi.dll');
    if (Platform.isMacOS) return DynamicLibrary.open('libsgit_ffi.dylib');
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('libsgit_ffi.so');
    }
    throw UnsupportedError('当前平台不支持 sgit_ffi');
  }

  Map<String, dynamic> _call(Pointer<Utf8> Function() fn) {
    final result = fn();
    if (result == nullptr) throw StateError('FFI 返回空');
    final out = result.toDartString();
    _free(result);
    final decoded = jsonDecode(out);
    return decoded is Map<String, dynamic> ? decoded : {'data': decoded};
  }

  /// 探测端点。
  EndpointInfo probeEndpoint() {
    final m = _call(_probe);
    if (m['error'] != null) throw StateError(m['error'].toString());
    return EndpointInfo(
      baseUrl: m['base_url'].toString(),
      preferPasswordLogin: m['prefer_password_login'] == true,
      gatewayUrl: (m['gateway_url'] ?? '').toString(),
    );
  }

  /// 与 Web 实现同签名的空实现。
  ///
  /// Web 端这里要实例化 sgit_crypto WASM + 预生成会话临时 RSA（浏览器↔auth-server 那一跳
  /// 的应用层加密）；桌面端 Dart→.so 是进程内调用，加密在 .so 内部做掉，**没有需要预热的
  /// 东西**，故为空。
  Future<void> warmupCrypto() async {}

  /// 拉图形验证码。
  ///
  /// FFI 调用本身是阻塞的，签名声明成 `Future` 是为了**与 Web 实现保持同一套 API**
  /// （Web 走同源 HTTP，天然异步），调用方两端零分叉。
  Future<Captcha> imageCaptcha() async {
    final m = _call(_captcha);
    if (m['error'] != null) throw StateError(m['error'].toString());
    return Captcha(
      captchaId: (m['captcha_id'] ?? m['captchaId'] ?? '').toString(),
      svg: (m['svg'] ?? '').toString(),
    );
  }

  /// 登录 V2（手机号/用户名 + 密码 + 图形验证码）。返回原始结果 map。
  /// 同上，签名异步只为对齐 Web 实现。
  Future<Map<String, dynamic>> loginV2({
    required String identifier,
    required String password,
    required String captchaId,
    required String captchaCode,
  }) async {
    final pId = identifier.toNativeUtf8();
    final pPwd = password.toNativeUtf8();
    final pCid = captchaId.toNativeUtf8();
    final pCode = captchaCode.toNativeUtf8();
    try {
      return _call(() => _login(pId, pPwd, pCid, pCode));
    } finally {
      malloc.free(pId);
      malloc.free(pPwd);
      malloc.free(pCid);
      malloc.free(pCode);
    }
  }

  /// 通用加密业务请求（type:command）。返回解包后的 data map。
  ///
  /// FFI 调用本身阻塞，声明成 `Future` 是为了**与 Web 实现同签名**（Web 走 HTTP，
  /// 天生异步），调用方两端零分叉。
  Future<Map<String, dynamic>> request({
    required String operation,
    String? action,
    Map<String, dynamic>? payload,
  }) async {
    final pOp = operation.toNativeUtf8();
    final pAct = action?.toNativeUtf8() ?? nullptr;
    final pPayload = jsonEncode(payload ?? const {}).toNativeUtf8();
    try {
      final m = _call(() => _request(pOp, pAct, pPayload));
      // ⚠️ 抛 `FfiFailure` 而不是 `StateError` —— 后者只带一句中文，上层没法
      // 区分「令牌过期」和「后端连不上」。`ApiClient` 会把它转成 ApiException
      // 并把 `code` 一起带出去。
      final failure = parseFfiError(m);
      if (failure != null) throw failure;
      return m;
    } finally {
      malloc.free(pOp);
      if (pAct != nullptr) malloc.free(pAct);
      malloc.free(pPayload);
    }
  }

  /// 会话查询/清理 —— 与 Web 实现同签名。
  ///
  /// 桌面端真正的会话由 `.so` 内部持有（per-cid sqlite + 进程内槽位）。
  /// LocalStorage 里那个 token **只是给路由判「要不要跳登录页」用的标记**，
  /// 请求里的身份注入由 `.so` 自己完成，Dart 不参与。
  ///
  /// ⚠️ 但「标记」不能当成「登录态」用 —— 这正是原来的错。现在以 `.so` 为准：
  /// - [isAuthenticated] 问 `.so`；符号缺失（旧 DLL）才退回本地标记；
  /// - [validateSession] 走 `.so` 的真校验，并**顺手清掉失效的本地标记**。
  Future<bool> validateSession() async {
    if (_validateSession == null) {
      // 旧 DLL：没有校验符号，只能退回「有没有会话」的同步判断。
      // 这时过期令牌骗得过我们 —— 只能等业务请求报鉴权失败来兜底
      // （见 core/result/auth_failure.dart）。
      return isAuthenticated();
    }
    // ⚠️ **必须换 isolate 跑。**
    //
    // 这个符号会打一次 `/auth/validateCachedToken`（超时 10s）。FFI 调用是
    // 同步的 —— 在主 isolate 上就是 UI 线程冻住，而它的触发点是启动时
    // `AuthController.build()`，正好卡在首屏。
    //
    // 与 `settings_repository_io.dart` 的 `_ffiCall` 同一个理由、同一个写法：
    // 函数指针不能跨 isolate，所以在里面重新 open + lookup。
    final ok = await Isolate.run(
      () => _open().lookupFunction<_BoolC, _BoolDart>('sgit_validate_session')(),
    );
    // 失效时顺手清掉本地标记 —— Rust 那边已经清了进程内会话。
    if (!ok) await LocalStorage.instance.setAuthToken(null);
    return ok;
  }

  /// 是否持有会话。**同步、不发网络**（Rust 只读内存槽）。
  ///
  /// 进程刚启动时 Rust 会从本地库恢复一次会话（`session()` 里的 `restore_session`），
  /// 所以这里能反映「上次登录过、这次还没登录」。恢复失败即 false。
  bool isAuthenticated() {
    final ffi = _isAuthenticated;
    // 桌面端以 `.so` 为准；本地标记只是它的镜像，用于旧 DLL 的降级。
    if (ffi != null) return ffi();
    return (LocalStorage.instance.authToken ?? '').isNotEmpty;
  }

  /// 桌面端 cid 不落 Dart —— `.so` 自己知道。UI 需要时另走接口取。
  String currentCid() => '';

  /// 清会话。
  ///
  /// ⚠️ **必须同时通知 `.so`**。原来只清 LocalStorage，Rust 进程内的会话、
  /// 内核中继连接、团队协同聊天连接全都还活着 —— 退出登录后仍能收发消息。
  void logout() {
    _logout?.call();
    LocalStorage.instance.setAuthToken(null);
  }
}
