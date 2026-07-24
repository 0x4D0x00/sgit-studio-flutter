import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_user.dart';
import 'services/user_service.dart';

final userServiceProvider = Provider<UserService>((_) => const UserService());

/// 用户列表控制器。加载全部用户，支持刷新 / 注册 / 改状态后自动重载。
class UsersController extends AsyncNotifier<List<AppUser>> {
  UserService get _service => ref.read(userServiceProvider);

  @override
  Future<List<AppUser>> build() => _service.listUsers();

  Future<void> refreshUsers() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_service.listUsers);
  }

  /// 注册新用户，成功后刷新列表。抛出异常由 UI 层捕获展示。
  Future<void> register({
    String? username,
    String? phone,
    String? email,
    String? nickname,
  }) async {
    await _service.registerUser(
      username: username,
      phone: phone,
      email: email,
      nickname: nickname,
    );
    await refreshUsers();
  }

  /// 切换用户启用/禁用状态。
  Future<void> toggleStatus(AppUser user) async {
    await _service.updateStatus(user.userId, user.isActive ? 0 : 1);
    await refreshUsers();
  }
}

final usersControllerProvider =
    AsyncNotifierProvider<UsersController, List<AppUser>>(UsersController.new);
