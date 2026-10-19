import 'package:sgit_studio_flutter/core/result/auth_failure.dart';

/// 统一 API 异常。业务失败 / 网络失败 / 鉴权过期归一到这里。
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    bool? isAuthExpired,
  }) : _authExpired = isAuthExpired;

  final String message;
  final int? statusCode;

  /// 调用方显式给的判定；null = 交给 [isAuthExpired] 按统一判据自动识别。
  ///
  /// 之所以留一层显式覆盖：有些失败是「本地已经没有会话了」，message 里
  /// 未必带任何关键词（例如 Rust 侧返回的 `未找到有效的认证信息`）。
  final bool? _authExpired;

  /// token 过期 / 未登录导致的失败。UI 层据此跳登录页。
  ///
  /// 判定真源是 [isAuthFailureMessage] —— 各处仓储构造异常时通常只给
  /// message，自动识别能覆盖到它们，不必逐个改调用点。
  bool get isAuthExpired => _authExpired ?? isAuthFailureMessage(message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
