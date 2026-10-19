/// sgit_request_ffi 的纯数据类型（无 dart:io/dart:ffi），io / web 两端共享，
/// 保证跨平台类型身份一致（否则条件导入两侧各自定义会导致类型不兼容）。

/// 图形验证码：id + svg 图片内容。
class Captcha {
  const Captcha({required this.captchaId, required this.svg});
  final String captchaId;
  final String svg;
}

/// native / wasm 回的业务失败。
///
/// 两端（`.so` 与 wasm）现在都会在 `{"error":..}` 里附带 `code`：
///
/// ```json
/// {"error":"认证失败: 无效的user_auth_token: ...","code":"auth_expired"}
/// ```
///
/// [code] 是**结构化判据**，比按中文 message 猜可靠得多。旧版 DLL 没有这个字段，
/// 那时 [code] 为 null，调用方退回 `auth_failure.dart` 的关键词判据。
class FfiFailure implements Exception {
  const FfiFailure(this.message, {this.code});

  final String message;

  /// `auth_expired` / `endpoint_unreachable` / `other`。见 Rust 的
  /// `sgit_services::http::service::FailureCode`。
  final String? code;

  bool get isAuthExpired => code == 'auth_expired';

  @override
  String toString() => message;
}

/// 解析 `{"error":..,"code":..}` 信封；没有 error 时返回 null。
FfiFailure? parseFfiError(Map<String, dynamic> m) {
  final e = m['error'];
  if (e == null) return null;
  final code = m['code']?.toString();
  return FfiFailure(e.toString(), code: code);
}

/// 探测结果：可用端点 + 是否密码登录。
class EndpointInfo {
  const EndpointInfo({
    required this.baseUrl,
    required this.preferPasswordLogin,
    this.gatewayUrl = '',
  });
  final String baseUrl;
  final bool preferPasswordLogin;

  /// 云端引擎连的 gateway 基址。**与 [baseUrl] 不是同一个端口**
  /// （Rust `ApiConfig::gateway_base_url`）。空 = 这端给不出。
  final String gatewayUrl;
}
