/// 间距 / 圆角 / 断点 / 窗口令牌。8pt 栅格。组件禁止写魔法数字。
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  AppRadius._();

  static const double sm = 6;
  static const double md = 12;
  static const double lg = 18;
  static const double pill = 999;
}

/// 响应式断点。
class AppBreakpoints {
  AppBreakpoints._();

  static const double mobile = 600;
  static const double tablet = 1024;

  static const double sidebarExpanded = 240;
  static const double sidebarCollapsed = 72;
  static const double contentMaxWidth = 1600;
}

/// 桌面窗口相关。
class AppWindow {
  AppWindow._();

  /// 透明窗口 bar 高度。
  static const double titleBarHeight = 44;

  static const double minWidth = 960;
  static const double minHeight = 640;
}
