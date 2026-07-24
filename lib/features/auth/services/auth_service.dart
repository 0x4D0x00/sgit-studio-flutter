import '../../../core/network/api_exception.dart';
import '../../../core/network/ffi/sgit_request_ffi.dart';

/// 登录结果：token（cid 已由 Rust 侧激活会话，后续请求自动带 token）。
class LoginResult {
  const LoginResult({required this.token, required this.cid});
  final String token;
  final String cid;
}

/// 鉴权服务。全部走 FFI 委托 sgcode（login_with_password_v2 + 图形验证码）。
class AuthService {
  const AuthService();

  /// 拉图形验证码（captcha_id + svg）。
  Captcha fetchCaptcha() => SgitRequestFfi.instance.imageCaptcha();

  /// V2 登录：手机号/用户名 + 密码 + 图形验证码。
  Future<LoginResult> login({
    required String identifier,
    required String password,
    required String captchaId,
    required String captchaCode,
  }) async {
    final m = SgitRequestFfi.instance.loginV2(
      identifier: identifier,
      password: password,
      captchaId: captchaId,
      captchaCode: captchaCode,
    );

    final status = m['status']?.toString();
    if (status != 'success') {
      throw ApiException(m['message']?.toString() ?? '登录失败');
    }
    final token = (m['auth_token'] ?? '').toString();
    final cid = (m['cid'] ?? '').toString();
    if (token.isEmpty) {
      throw const ApiException('登录失败：未获取到令牌');
    }
    return LoginResult(token: token, cid: cid);
  }
}
