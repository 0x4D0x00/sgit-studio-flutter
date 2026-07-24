import 'package:flutter/foundation.dart';

import 'desktop_window_impl.dart'
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
