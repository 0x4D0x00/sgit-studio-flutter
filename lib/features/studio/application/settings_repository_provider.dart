import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/settings_repository.dart';

/// 配置仓储。按平台分流：桌面/移动走 FFI 本地 + 上行，Web 直通 gateway。
///
/// ⚠️ 测试里要 `overrideWithValue` 注入假实现 —— 桌面工厂会加载
/// `sgit_ffi.dll`，测试环境里必然失败。别依赖工厂的平台默认值
/// （`layout_test.dart` 上次就栽在这个假设上）。
final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => createSettingsRepository());
