import 'package:flutter/widgets.dart';

import '../../core/theme/app_spacing.dart';

enum DeviceType { mobile, tablet, desktop }

extension ResponsiveContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  DeviceType get deviceType {
    final w = screenWidth;
    if (w < AppBreakpoints.mobile) return DeviceType.mobile;
    if (w < AppBreakpoints.tablet) return DeviceType.tablet;
    return DeviceType.desktop;
  }

  bool get isMobile => deviceType == DeviceType.mobile;
  bool get isTablet => deviceType == DeviceType.tablet;
  bool get isDesktop => deviceType == DeviceType.desktop;

  /// 移动端用抽屉侧栏，桌面/平板常驻侧栏。
  bool get useDrawerNav => isMobile;
}
