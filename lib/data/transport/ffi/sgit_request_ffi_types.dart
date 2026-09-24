/// sgit_request_ffi 的纯数据类型（无 dart:io/dart:ffi），io / web 两端共享，
/// 保证跨平台类型身份一致（否则条件导入两侧各自定义会导致类型不兼容）。

/// 图形验证码：id + svg 图片内容。
class Captcha {
  const Captcha({required this.captchaId, required this.svg});
  final String captchaId;
  final String svg;
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
