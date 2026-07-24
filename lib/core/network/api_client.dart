import 'api_exception.dart';
import 'ffi/sgit_request_ffi.dart';

/// HTTP 客户端(单一真源)。
///
/// 铁律：所有与 SGiT-Server 的通信全部走 Rust FFI（[SgitRequestFfi] → sgit_ffi.dll），
/// 委托 sgcode sgit-services 现成实现。加密/端点/token 全在 Rust 侧，Dart 只传参拿结果。
/// 详见 memory `sgit-nexus-ffi-rule`。
class ApiClient {
  ApiClient._();

  static ApiClient? _instance;
  static ApiClient get instance => _instance ??= ApiClient._();

  /// 分发一次业务请求（type:command）。返回解包后的业务 data。
  ///
  /// [operation] 如 `basic_information`；[action] 如 `user_list`；[payload] 业务数据。
  Future<dynamic> dispatch({
    required String type, // 保留签名兼容；FFI 固定 type:command
    String? operation,
    String? action,
    Map<String, dynamic>? payload,
  }) async {
    if (operation == null) {
      throw const ApiException('缺少 operation');
    }
    try {
      final result = SgitRequestFfi.instance.request(
        operation: operation,
        action: action,
        payload: payload,
      );
      return _unwrapEnvelope(result);
    } on StateError catch (e) {
      throw ApiException(e.message);
    }
  }

  /// 解 sgcode `{status,message,data}` 信封。
  dynamic _unwrapEnvelope(Map<String, dynamic> body) {
    final status = body['status']?.toString();
    final message = body['message']?.toString() ?? '';
    if (status == 'fail' || status == 'error') {
      final authExpired =
          message.contains('[auth_expired]') || message.contains('令牌已过期');
      throw ApiException(message.isEmpty ? '请求失败' : message,
          isAuthExpired: authExpired);
    }
    return body.containsKey('data') ? body['data'] : body;
  }
}
