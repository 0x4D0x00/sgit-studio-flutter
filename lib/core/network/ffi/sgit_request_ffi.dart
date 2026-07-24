import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

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

/// 图形验证码：id + svg 图片内容。
class Captcha {
  const Captcha({required this.captchaId, required this.svg});
  final String captchaId;
  final String svg;
}

/// 探测结果：可用端点 + 是否密码登录。
class EndpointInfo {
  const EndpointInfo({required this.baseUrl, required this.preferPasswordLogin});
  final String baseUrl;
  final bool preferPasswordLogin;
}

/// FFI 封装 sgit-ffi.dll —— 全部委托 sgcode sgit-services 现成实现。
///
/// 登录 / 加密请求 / 端点池 / 图形验证码全在 Rust 侧完成，Dart 只传参拿 JSON。
/// 详见 memory `sgit-nexus-ffi-rule`。
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

  /// 拉图形验证码。
  Captcha imageCaptcha() {
    final m = _call(_captcha);
    if (m['error'] != null) throw StateError(m['error'].toString());
    return Captcha(
      captchaId: (m['captcha_id'] ?? m['captchaId'] ?? '').toString(),
      svg: (m['svg'] ?? '').toString(),
    );
  }

  /// 登录 V2（手机号/用户名 + 密码 + 图形验证码）。返回原始结果 map。
  Map<String, dynamic> loginV2({
    required String identifier,
    required String password,
    required String captchaId,
    required String captchaCode,
  }) {
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
  Map<String, dynamic> request({
    required String operation,
    String? action,
    Map<String, dynamic>? payload,
  }) {
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
}
