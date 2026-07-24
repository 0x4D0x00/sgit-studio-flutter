import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import '../theme/app_spacing.dart';

/// 桌面无边框真透明窗口配置。window_manager 设置窗口背景透明 + 无边框。
Future<void> setupDesktopWindow() async {
  await windowManager.ensureInitialized();

  // 默认窗口尺寸：1800x1120（约 2560x1600 的 70%）。
  // TODO: 用 screen_retriever 包动态获取屏幕尺寸并计算 70%。
  const windowOptions = WindowOptions(
    size: Size(1800, 1120),
    minimumSize: Size(AppWindow.minWidth, AppWindow.minHeight),
    center: true,
    backgroundColor: Color(0x00000000), // 完全透明
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // 无边框
    title: 'SGiT-Nexus',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
