import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import 'package:sgit_studio_flutter/services/brand/brand_config.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

/// 取不到屏幕尺寸时的兜底（原代码写死的那组数字）。
const Size _kFallbackSize = Size(1800, 1120);

/// 桌面无边框真透明窗口配置。window_manager 设置窗口背景透明 + 无边框。
Future<void> setupDesktopWindow() async {
  await windowManager.ensureInitialized();

  final size = await _computeInitialSize();
  final windowOptions = WindowOptions(
    size: size,
    minimumSize: const Size(AppWindow.minWidth, AppWindow.minHeight),
    center: true,
    backgroundColor: const Color(0x00000000), // 完全透明
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // 无边框
    // 窗口标题同样来自 brand.json,禁止写死产品名。
    title: BrandConfig.instance.title,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // 先在隐藏状态下 maximize()，再 show()，避免先显示「恢复」态窗口
    // 再跳到最大化态的闪烁；Windows 11 也只在最大化后才会去掉圆角。
    await windowManager.maximize();
    await windowManager.show();
    await windowManager.focus();
  });
}

/// 按主屏可用尺寸（去掉任务栏等系统占用区域后的 `visibleSize`）铺满启动窗口，
/// 下限不低于 [AppWindow.minWidth] / [AppWindow.minHeight]
/// `screen_retriever` 取不到屏幕信息时（个别 Linux 桌面环境没实现）就退回旧代码写死的那组数字，保证窗口总能弹出来。
Future<Size> _computeInitialSize() async {
  try {
    final display = await screenRetriever.getPrimaryDisplay();
    final screenSize = display.visibleSize ?? display.size;
    if (screenSize.width <= 0 || screenSize.height <= 0) {
      return _kFallbackSize;
    }
    return Size(
      screenSize.width.clamp(AppWindow.minWidth, screenSize.width),
      screenSize.height.clamp(AppWindow.minHeight, screenSize.height),
    );
  } catch (_) {
    return _kFallbackSize;
  }
}

/// 再启动一个独立的客户端进程（新窗口）。
Future<void> openNewWindow() async {
  await Process.start(
    Platform.resolvedExecutable,
    const [],
    mode: ProcessStartMode.detached,
  );
}

Future<void> minimizeWindow() => windowManager.minimize();

/// 关闭客户端（退出进程）。
Future<void> quitApp() => windowManager.destroy();
