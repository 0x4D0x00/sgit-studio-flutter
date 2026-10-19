import 'package:sgit_studio_flutter/core/result/api_exception.dart';
import 'package:sgit_studio_flutter/core/result/auth_failure.dart';
import 'package:sgit_studio_flutter/data/transport/ffi/sgit_request_ffi.dart';

/// HTTP 客户端(单一真源)。
///
/// 铁律：所有与 SGiT-Server 的通信全部走 Rust FFI（[SgitRequestFfi] → sgit_ffi.dll），
/// 委托 sgcode sgit-services 现成实现。加密/端点/token 全在 Rust 侧，Dart 只传参拿结果。
/// 详见 memory `flutter-kernel-access-ffi-only`。
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
      final result = await SgitRequestFfi.instance.request(
        operation: operation,
        action: action,
        payload: payload,
      );
      return _unwrapEnvelope(result);
    } on FfiFailure catch (e) {
      throw _failure(e.message, code: e.code);
    } on StateError catch (e) {
      throw _failure(e.message);
    }
  }

  /// 把任何失败统一成 [ApiException]，并**在判定为鉴权失败时广播一次**。
  ///
  /// ⚠️ 广播是必需的：本方法是所有业务请求的收敛点，但**调用方常常会把它
  /// catch 掉**（菜单判权、模型列表都这么做）。在那里再抛没有意义 —— 上层
  /// 已经决定"静默回落"。所以失效信号必须从这里直接发给 `AuthController`，
  /// 不能指望异常一路冒泡到路由。
  ///
  /// 判定优先级：native 的 `code` > message 关键词。`code` 是结构化的，
  /// 关键词只是旧 DLL 的降级路径。
  static ApiException _failure(String message, {String? code}) {
    // `code` 命中就不再让关键词判据重复广播一次。
    final byCode = code == 'auth_expired';
    final byMessage = !byCode && isAuthFailureMessage(message);
    final expired = byCode || byMessage;
    if (expired) AuthFailure.report(message);
    return ApiException(
      message.isEmpty ? '请求失败' : message,
      isAuthExpired: expired,
    );
  }

  /// 解 sgcode `{status,message,data}` 信封。
  dynamic _unwrapEnvelope(Map<String, dynamic> body) {
    final status = body['status']?.toString();
    final message = body['message']?.toString() ?? '';
    if (status == 'fail' || status == 'error') {
      throw _failure(message);
    }
    return body.containsKey('data') ? body['data'] : body;
  }
}
