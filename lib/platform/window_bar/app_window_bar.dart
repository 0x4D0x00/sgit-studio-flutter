import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/platform/window_bar/window_buttons.dart'
    if (dart.library.html) 'window_buttons_stub.dart';

/// 桌面透明窗口 bar(全局基础组件)。
///
/// - **无边框**:窗口本身在 [initDesktopWindow] 里设为无标题栏，这个 bar 就是全部窗口顶饰。
/// - **透明**:不铺底色，与下方内容(经三层结构)融为一体。
/// - 整条可拖拽移动窗口，右侧最小化/最大化/关闭按钮。
/// - 非桌面平台(Web/移动)自动折叠为 0 高，不占位。
class AppWindowBar extends StatelessWidget {
  const AppWindowBar({super.key, this.leading, this.center});

  /// 左侧内容(如 logo / 标题)。
  final Widget? leading;

  /// 居中内容(可选)。
  final Widget? center;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Widget build(BuildContext context) {
    if (!_isDesktop) return const SizedBox.shrink();
    return WindowBarView(leading: leading, center: center);
  }
}
