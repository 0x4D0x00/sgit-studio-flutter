import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sgit_studio_flutter/core/storage/local_storage.dart';

/// 用户配置信息状态
class UserProfile {
  const UserProfile({
    this.username = 'User',
    this.avatarUrl,
  });

  final String username;

  /// data URI 形式（`data:image/<ext>;base64,<...>`），随 [LocalStorage] 持久化。
  final String? avatarUrl;

  /// 解码后的头像字节，供 [MemoryImage] 直接展示；无头像或格式非法时为 null。
  Uint8List? get avatarBytes {
    final url = avatarUrl;
    if (url == null) return null;
    final commaIndex = url.indexOf(',');
    if (commaIndex == -1) return null;
    try {
      return base64Decode(url.substring(commaIndex + 1));
    } on FormatException {
      return null;
    }
  }

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
    final s = LocalStorage.instance;
    return UserProfile(
      username: s.username ?? 'User',
      avatarUrl: s.avatar,
    );
  }

  /// 更新用户名
  Future<void> updateUsername(String username) async {
    if (username.trim().isEmpty) return;

    final trimmedUsername = username.trim();
    await LocalStorage.instance.setUsername(trimmedUsername);
    state = state.copyWith(username: trimmedUsername);
  }

  /// 更新头像。[bytes] 为图片原始字节，[extension] 为文件扩展名（如 `png`/`jpg`），
  /// 编码为 data URI 后落盘，SharedPreferences 全端通用，无需额外文件系统权限。
  Future<void> updateAvatar(Uint8List bytes, String extension) async {
    final mimeType = _mimeTypeFor(extension);
    final avatarUrl = 'data:$mimeType;base64,${base64Encode(bytes)}';
    await LocalStorage.instance.setAvatar(avatarUrl);
    state = state.copyWith(avatarUrl: avatarUrl);
  }

  String _mimeTypeFor(String extension) {
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'png':
      default:
        return 'image/png';
    }
  }
}

final userProfileControllerProvider =
    NotifierProvider<UserProfileController, UserProfile>(
  UserProfileController.new,
);
