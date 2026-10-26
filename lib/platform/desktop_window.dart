import 'package:flutter/foundation.dart';

import 'package:sgit_studio_flutter/platform/desktop_window_impl.dart'
    if (dart.library.html) 'desktop_window_stub.dart';

/// 桌面窗口初始化入口。仅桌面平台生效(无边框 + 透明)。
Future<void> initDesktopWindow() async {
  if (kIsWeb) return;
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    await setupDesktopWindow();
  }
}

bool get _isDesktop =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// 新窗口 = 再打开一个客户端。
Future<void> openNewClientWindow() async {
  if (_isDesktop) await openNewWindow();
}

/// 最小化客户端窗口。
Future<void> minimizeClient() async {
  if (_isDesktop) await minimizeWindow();
}

/// 退出客户端（桌面版）或退出应用（Web）。
Future<void> quitClient() async {
  if (_isDesktop) await quitApp();
}
