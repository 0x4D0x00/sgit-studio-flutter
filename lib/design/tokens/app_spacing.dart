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

/// 弹出菜单尺寸 —— `ui/components/menu/app_menu.dart` 的单一真源。
///
/// 菜单是「一处定样式、全站复用」的组件，尺寸集中在这里，避免各页各写一遍
/// `offset` / `padding` / 圆角(历史上 nav_panel 与 artifacts_page 各写过一份 8)。
class AppMenuMetrics {
  AppMenuMetrics._();

  static const double radius = 8;

  /// 单行高度。图标 18 + 上下 9 的视觉重心，和导航行的 48 区分开。
  static const double itemHeight = 36;

  /// 带描述的两行项高度（`AppMenuRichAction`）。
  /// 标题 20 + 描述 17 + 上下各 8 ≈ 56。用 [itemHeight] 会把描述挤掉。
  static const double richItemHeight = 56;

  /// 两行项左侧图标方块。对齐 studio 的 `optionIcon`
  /// （`ControlBar/ModeSelector.tsx:199-206` 的 32×32）。
  static const double richItemIconBox = 32;
  static const double richItemIconSize = 16;

  /// 默认菜单宽度。快捷键/当前值要右对齐，所以菜单必须定宽而非按内容撑开。
  ///
  /// 别调太大：项的文案通常很短（「今日」「无」），菜单越宽，文案与右侧
  /// 对勾/当前值之间的空档越难看。
  static const double minWidth = 180;

  static const double iconSize = 18;

  /// 项的左内边距。
  static const double itemPadStart = 12;

  /// 项的右内边距。比左侧大一点 —— 右侧那一格（对勾/快捷键/当前值）
  /// 紧贴描边会显得挤。
  static const double itemPadEnd = 16;

  /// 文案与右侧那一格之间的**最小**间距。
  static const double trailingGap = 12;

  /// 触发器与菜单之间的缝。
  static const double gap = 6;

  /// 悬停菜单「鼠标移开后多久关」的容差。
  ///
  /// 菜单面板是 overlay，不在触发器的子树里 —— 鼠标从触发器移到面板上，
  /// 中间那道 [gap] 会先发一次「移出」。这段容差就是让光标有时间跨过那道缝，
  /// 太短会关不掉手、太长会觉得菜单赖着不走。
  static const Duration hoverCloseDelay = Duration(milliseconds: 220);
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
