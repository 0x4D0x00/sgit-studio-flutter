import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

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
        _free = lib.lookupFunction<_FreeC, _FreeDart>('free_string');

  final _ProbeDart _probe;
  final _CaptchaDart _captcha;
  final _LoginDart _login;
  final _RequestDart _request;
  final _FreeDart _free;

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
      if (m['error'] != null) throw StateError(m['error'].toString());
      return m;
    } finally {
      malloc.free(pOp);
      if (pAct != nullptr) malloc.free(pAct);
      malloc.free(pPayload);
    }
  }

  /// 会话查询/清理 —— 与 Web 实现同签名。
  ///
  /// 桌面端真正的会话由 `.so` 内部的 sgcode-datasystem 持有（per-cid sqlite），
  /// 这里的 LocalStorage token 只是给路由判「要不要跳登录页」用的一个标记；
  /// 请求里的身份注入由 `.so` 自己完成，Dart 不参与。
  /// 桌面 `.so` 暂无会话校验符号 —— 退回本地判断。
  /// 补上 `sgit_validate_session` 后改成真校验（同 Web）。
  Future<bool> validateSession() async => isAuthenticated();

  bool isAuthenticated() =>
      (LocalStorage.instance.authToken ?? '').isNotEmpty;

  /// 桌面端 cid 不落 Dart —— `.so` 自己知道。UI 需要时另走接口取。
  String currentCid() => '';

  void logout() {
    // 只清本地标记；.so 侧会话随进程/下次登录覆盖。
    LocalStorage.instance.setAuthToken(null);
  }
}
