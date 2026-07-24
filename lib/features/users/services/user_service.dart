import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/app_user.dart';

/// 用户管理接口服务。走 SGiT-Server 统一入口 `command/basic_information/<action>`。
class UserService {
  const UserService();

  /// 获取全部用户列表。后端返回 `{ users: [...], total: n }`。
  Future<List<AppUser>> listUsers() async {
    final d = ApiDispatch.userList;
    final data = await ApiClient.instance.dispatch(
      type: d.type,
      operation: d.operation,
      action: d.action,
    );

    final list = _extractUsers(data);
    return list.map(AppUser.fromJson).toList();
  }

  /// 注册新用户。username/phone/email 至少提供一个。
  Future<void> registerUser({
    String? username,
    String? phone,
    String? email,
    String? nickname,
  }) async {
    final d = ApiDispatch.userRegister;
    await ApiClient.instance.dispatch(
      type: d.type,
      operation: d.operation,
      action: d.action,
      payload: {
        if (username != null && username.isNotEmpty) 'username': username,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (email != null && email.isNotEmpty) 'email': email,
        if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
      },
    );
  }

  /// 更新用户状态（1-正常 / 0-禁用）。
  Future<void> updateStatus(String userId, int status) async {
    final d = ApiDispatch.userStatusUpdate;
    await ApiClient.instance.dispatch(
      type: d.type,
      operation: d.operation,
      action: d.action,
      payload: {'user_id': userId, 'status': status},
    );
  }

  /// 从 dispatch 解包结果里稳妥地取出 users 数组。
  List<Map<String, dynamic>> _extractUsers(dynamic data) {
    dynamic raw = data;
    if (raw is Map && raw['users'] != null) raw = raw['users'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return const [];
  }
}
