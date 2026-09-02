import 'dart:convert';
import 'dart:js_interop';

import 'package:dio/dio.dart';

import 'package:sgit_studio_flutter/data/endpoints/api_endpoints.dart';
import 'package:sgit_studio_flutter/data/transport/ffi/sgit_request_ffi_types.dart';

/// SgitRequestFfi 的 **Web 实现** —— 桌面 `libsgit_ffi.so` 的对应物。
///
/// ## 铁律：sgcode 已实现的东西，Dart 不重写
/// 登录、业务请求、加密、会话（token/cid）全部在 `sgit-ffi-web` 的 WASM 里，与桌面
/// `.so` 共用同一份协议实现（`sgit-protocol` crate）。本文件只做**参数传递与 JSON 解析**。
///
/// 曾经踩过的坑（别重犯）：把协议编排手抄进 Dart，漏了「nonce 一次性、取公钥与发请求
/// 各取一个」→ 线上报「无效请求」；把身份拼装留在 Dart，漏了 `communication_id`
/// → 菜单判权拿不到数据。这些都是 Rust 侧本来就写好的。
///
/// 唯一还在 Dart 走 HTTP 的是图形验证码：它是 `GET`，后端 `browser_crypto` 中间件对
/// GET/HEAD 整类豁免加密（`is_exempt`），没有任何协议逻辑可言，只是取一张图。
class SgitRequestFfi {
  SgitRequestFfi._();

  static final SgitRequestFfi _instance = SgitRequestFfi._();
  static SgitRequestFfi get instance => _instance;

  /// 同源 dio（仅用于验证码这类明文 GET）。相对路径按文档 origin 解析，免配 IP。
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
    responseType: ResponseType.json,
  ));

  /// Web 端不做端点探测：后端就是同源 nginx，由它反代。
  EndpointInfo probeEndpoint() =>
      const EndpointInfo(baseUrl: '', preferPasswordLogin: true);

  /// 等 WASM 实例化完成。登录页 mount 时调。
  Future<void> warmupCrypto() async => _ready();

  Future<void> _ready() async {
    final p = _sgitCryptoReady;
    if (p == null) {
      throw StateError('sgit_ffi_web WASM 未引导（web/index.html 的 module glue 丢了？）');
    }
    await p.toDart;
  }

  /// 拉图形验证码（同源 GET，明文）。
  Future<Captcha> imageCaptcha() async {
    final Response<dynamic> res =
        await _dio.get<dynamic>(ApiEndpoints.authImageCaptcha);
    final data = res.data;
    if (data is! Map) throw StateError('验证码响应格式异常');
    // 后端转发失败时回的是 {"error": "..."}，不是异常，得显式识别。
    if (data['error'] != null) throw StateError(data['error'].toString());
    return Captcha(
      captchaId: (data['captcha_id'] ?? data['captchaId'] ?? '').toString(),
      svg: (data['svg'] ?? '').toString(),
    );
  }

  /// 登录 V2。整套流程（加密、打后端、解响应、存会话）都在 WASM 里。
  ///
  /// 返回**与桌面 FFI 同形状**的 map。注意 `auth_token` 不回传 —— 令牌留在 Rust 侧会话里，
  /// 后续 [request] 自动注入，Dart 不必持有（也就不会写错）。
  Future<Map<String, dynamic>> loginV2({
    required String identifier,
    required String password,
    required String captchaId,
    required String captchaCode,
  }) async {
    await _ready();
    final out = await _wasm
        .loginV2(identifier.toJS, password.toJS, captchaId.toJS, captchaCode.toJS)
        .toDart;
    final decoded = jsonDecode(out.toDart);
    if (decoded is! Map) throw StateError('登录响应格式异常');
    return Map<String, dynamic>.from(decoded);
  }

  /// 通用业务请求（type:command）。身份由 WASM 侧自动注入。
  Future<Map<String, dynamic>> request({
    required String operation,
    String? action,
    Map<String, dynamic>? payload,
  }) async {
    await _ready();
    final out = await _wasm
        .request(
          operation.toJS,
          action?.toJS,
          jsonEncode(payload ?? const <String, dynamic>{}).toJS,
        )
        .toDart;
    final decoded = jsonDecode(out.toDart);
    if (decoded is! Map) throw StateError('业务响应格式异常');
    final data = Map<String, dynamic>.from(decoded);
    // Rust 侧把任何失败都归一成 {"error": "..."}。
    if (data['error'] != null) throw StateError(data['error'].toString());
    return data;
  }

  /// 是否已登录（读 WASM 会话，页面刷新后仍有效）。
  bool isAuthenticated() => _sgitFfi?.isAuthenticated() ?? false;

  /// 校验缓存会话是否**仍然有效**（无效时 wasm 会顺手清掉本地会话）。
  ///
  /// ⚠️ 必须在启动时调一次。只看 [isAuthenticated] 会被过期令牌骗过去：
  /// 应用以为已登录 → 进主界面 → 处处报"用户未登录" → 用户还回不到登录页。
  Future<bool> validateSession() async {
    final f = _sgitFfi;
    if (f == null) return false;
    return (await f.validateSession().toDart).toDart;
  }

  /// 当前 communication_id（空串=未登录）。
  String currentCid() => _sgitFfi?.currentCid().toDart ?? '';

  /// 退出登录（清 WASM 会话 + localStorage）。
  void logout() => _sgitFfi?.logout();

  _SgitFfiJs get _wasm {
    final f = _sgitFfi;
    if (f == null) throw StateError('sgit_ffi_web WASM 尚未就绪（先 await warmupCrypto()）');
    return f;
  }
}

// ---- JS interop：window.__sgitFfi（由 index.html 的 module glue 挂载）----

@JS('__sgitCryptoReady')
external JSPromise<JSAny?>? get _sgitCryptoReady;

@JS('__sgitFfi')
external _SgitFfiJs? get _sgitFfi;

/// `sgit-ffi-web` 的 wasm-bindgen 导出。async fn → JS Promise。
extension type _SgitFfiJs._(JSObject _) implements JSObject {
  external JSPromise<JSString> request(
    JSString operation,
    JSString? action,
    JSString payloadJson,
  );

  external JSPromise<JSString> loginV2(
    JSString identifier,
    JSString password,
    JSString captchaId,
    JSString captchaCode,
  );

  external bool isAuthenticated();
  external JSPromise<JSBoolean> validateSession();
  external JSString currentCid();
  external void logout();
}
