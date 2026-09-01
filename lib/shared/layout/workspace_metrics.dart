/// 工作台外壳尺寸令牌 —— 1:1 对齐 sgit-studio 登录后主界面。
///
/// 数值出处（sgit-studio）：
/// - 外层 padding 8 / 内框圆角：`routes/(main)/_layout/DesktopLayoutContainer.tsx:22-60`
/// - 左栏 280 / 240 / 400：`store/global/initialState.ts:403`、`selectors/systemStatus.ts:65-66`
/// - 右栏 280 / 240 / 480：`features/RightPanel/index.tsx:36-79`
/// - 折叠 0 + 200ms ease-out：`@lobehub/ui DraggablePanel.mjs:377-378`
/// - 导航行 48 / 圆角 8 / padding 8×16：`features/NavPanel/components/NavItem.tsx:129-160`
/// - 中栏空态 44/10vh、内容列 min(960,100%)、输入框 768：
///   `home/features/Workspace/index.tsx:56-65`、`features/WideScreenContainer/index.tsx:42-53`、
///   `home/features/InputArea/index.tsx:125`
class WorkspaceMetrics {
  WorkspaceMetrics._();

  /// 外框留白 + 内框圆角/描边。
  static const double framePadding = 8;
  static const double frameRadius = 12;
  static const double frameBorder = 1;

  /// 左栏（在圆角卡外面）。
  static const double navDefaultWidth = 280;
  static const double navMinWidth = 240;
  static const double navMaxWidth = 400;

  /// 右栏（在圆角卡里面）。
  static const double outputDefaultWidth = 280;
  static const double outputMinWidth = 240;
  static const double outputMaxWidth = 480;

  /// 面板展开/折叠动画。
  static const Duration panelAnim = Duration(milliseconds: 200);

  /// 拖拽把手命中宽度（studio 是 DraggablePanel 的边缘 resizer）。
  static const double resizerHitWidth = 6;

  /// 左栏内部。
  static const double navPanelPaddingBlock = 16;
  static const double navPanelPaddingInline = 24;
  static const double navItemHeight = 48;
  static const double navItemRadius = 8;
  static const double navItemPaddingInline = 16;
  static const double navItemGap = 8;
  static const double navIconSize = 18;

  /// 左栏品牌行。
  static const double brandMarkWidth = 39;
  static const double brandMarkHeight = 47;
  static const double brandGap = 10;
  static const double brandFontSize = 22;

  /// 顶栏（仅左栏折叠时出现，只放展开按钮）。
  static const double headerHeight = 44;

  /// 右栏内部。
  static const double outputHeaderPaddingInline = 14;
  static const double outputTitleFontSize = 13;

  /// 中栏空态。
  static const double centerPaddingTop = 44;
  static const double contentMaxWidth = 960;
  static const double contentPaddingInline = 16;
  static const double inputAreaWidth = 768;
  static const double inputAreaRadius = 24;
  static const double heroAvatarSize = 96;
  static const double welcomeFontSize = 24;
  static const double skillChipHeight = 40;
}
