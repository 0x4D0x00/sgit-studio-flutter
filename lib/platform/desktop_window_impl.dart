import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'package:sgit_studio_flutter/services/brand/brand_config.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

/// 桌面无边框真透明窗口配置。window_manager 设置窗口背景透明 + 无边框。
Future<void> setupDesktopWindow() async {
  await windowManager.ensureInitialized();

  // 默认窗口尺寸：1800x1120（约 2560x1600 的 70%）。
  // TODO: 用 screen_retriever 包动态获取屏幕尺寸并计算 70%。
  final windowOptions = WindowOptions(
    size: const Size(1800, 1120),
    minimumSize: const Size(AppWindow.minWidth, AppWindow.minHeight),
    center: true,
    backgroundColor: const Color(0x00000000), // 完全透明
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // 无边框
    // 窗口标题同样来自 brand.json,禁止写死产品名。
    title: BrandConfig.instance.title,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
