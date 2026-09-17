import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sgit_studio_flutter/core/storage/local_storage.dart';

/// 用户配置信息状态
class UserProfile {
  const UserProfile({
    this.username = 'User',
    this.avatarUrl,
  });

  final String username;
  final String? avatarUrl;

  UserProfile copyWith({
    String? username,
    String? avatarUrl,
  }) =>
      UserProfile(
        username: username ?? this.username,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );
}

/// 用户配置控制器：管理用户名、头像等本地配置
class UserProfileController extends Notifier<UserProfile> {
  @override
  UserProfile build() {
    // 从本地存储加载用户配置
    _loadProfile();
    return const UserProfile();
  }

  Future<void> _loadProfile() async {
    final storage = LocalStorage.instance;
    final username = storage.username;
    final avatarUrl = storage.avatar;

    state = UserProfile(
      username: username ?? 'User',
      avatarUrl: avatarUrl,
    );
  }

  /// 更新用户名
  Future<void> updateUsername(String username) async {
    if (username.trim().isEmpty) return;

    final trimmedUsername = username.trim();
    await LocalStorage.instance.setUsername(trimmedUsername);
    state = state.copyWith(username: trimmedUsername);
  }

  /// 更新头像
  Future<void> updateAvatar(String avatarUrl) async {
    await LocalStorage.instance.setAvatar(avatarUrl);
    state = state.copyWith(avatarUrl: avatarUrl);
  }
}

final userProfileControllerProvider =
    NotifierProvider<UserProfileController, UserProfile>(
  UserProfileController.new,
);
