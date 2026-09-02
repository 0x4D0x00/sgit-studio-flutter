/// 统一 API 异常。业务失败 / 网络失败 / 鉴权过期归一到这里。
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.isAuthExpired = false});

  final String message;
  final int? statusCode;

  /// token 过期(后端 `[auth_expired]` 或 401/403)，UI 层据此跳登录页。
  final bool isAuthExpired;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
