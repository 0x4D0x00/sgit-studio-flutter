import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/menu_repository.dart';
import 'package:sgit_studio_flutter/data/repositories/session_sync_repository.dart';
import 'package:sgit_studio_flutter/data/repositories/settings_repository.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_factory.dart';
import 'package:sgit_studio_flutter/domain/models/accessible_menus.dart';

/// 跨 feature 共用的基础 provider 装配点。
///
/// 这三个原先放在 `features/studio/application/`，导致 chat / customize /
/// settings 都得 import studio。上移后 studio 只是普通 feature，可整目录删。

/// 内核通道 provider。让各仓储共用同一条连接（wasm 侧本来也只有一条）。
final kernelClientProvider = Provider((ref) => createKernelClient());

/// 配置仓储。按平台分流：桌面/移动走 FFI 本地 + 上行，Web 直通 gateway。
///
/// ⚠️ 测试里要 `overrideWithValue` 注入假实现 —— 桌面工厂会加载
/// `sgit_ffi.dll`，测试环境里必然失败。别依赖工厂的平台默认值
/// （`layout_test.dart` 上次就栽在这个假设上）。
final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => createSettingsRepository());

/// 菜单判权。登录后拉一次，登出/换账号自动重拉。
///
/// 只负责「后端说哪些 menu_key 可见」这件事，**不掺和任何 feature 的菜单清单** ——
/// 谁要用就自己 watch 它去过滤自己的注册表（见 `features/studio/studio_feature.dart`）。
final accessibleMenusProvider = FutureProvider<AccessibleMenus>((ref) {
  return const MenuRepository().listAccessible();
});

/// 会话同步仓储（桌面走 FFI，Web 为空实现）。
final sessionSyncRepositoryProvider = Provider<SessionSyncRepository>(
  (ref) => createSessionSyncRepository(),
);
