import '../../../core/network/api_exception.dart';
import '../../../core/network/ffi/sgit_request_ffi.dart';

/// 登录结果：token（cid 已由 Rust 侧激活会话，后续请求自动带 token）。
class LoginResult {
  const LoginResult({required this.token, required this.cid});
  final String token;
  final String cid;
}

/// 鉴权服务。桌面端全部走 FFI 委托 sgcode（login_with_password_v2 + 图形验证码）；
/// Web 端没有 .so，由 `sgit_request_ffi_web.dart` 换成同源 HTTP（详见该文件）。
class AuthService {
  const AuthService();

  /// 预热加密（Web 端实例化 WASM + 生成会话临时密钥；桌面端空实现）。登录页 mount 时调。
  Future<void> warmupCrypto() => SgitRequestFfi.instance.warmupCrypto();

  /// 拉图形验证码（captcha_id + svg）。
  Future<Captcha> fetchCaptcha() => SgitRequestFfi.instance.imageCaptcha();

  /// V2 登录：手机号/用户名 + 密码 + 图形验证码。
  Future<LoginResult> login({
    required String identifier,
    required String password,
    required String captchaId,
    required String captchaCode,
  }) async {
    final m = await SgitRequestFfi.instance.loginV2(
      identifier: identifier,
      password: password,
      captchaId: captchaId,
      captchaCode: captchaCode,
    );

    final status = m['status']?.toString();
    if (status != 'success') {
      throw ApiException(m['message']?.toString() ?? '登录失败');
    }
    // ⚠️ token 可能为空:Web 端(wasm)登录成功后令牌留在 Rust 会话里、**有意不回传**,
    // 只有桌面 .so 会带回来。所以不能拿 token 是否为空判成败 —— status 才是判据。
    return LoginResult(
      token: (m['auth_token'] ?? '').toString(),
      cid: (m['cid'] ?? '').toString(),
    );
  }
}
