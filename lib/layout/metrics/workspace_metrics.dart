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
  static const double navMaxWidth = 300;

  /// 右栏（在圆角卡里面）。
  static const double outputDefaultWidth = 280;
  static const double outputMinWidth = 240;
  static const double outputMaxWidth = 480;

  /// 面板展开/折叠动画。
  static const Duration panelAnim = Duration(
    milliseconds: 200,
  );

  /// 拖拽把手命中宽度（studio 是 DraggablePanel 的边缘 resizer）。
  static const double resizerHitWidth = 6;

  /// 左栏内部。
  static const double navPanelPaddingBlock = 10;
  static const double navPanelPaddingInline = 24;
  static const double navItemHeight = 30;
  static const double navItemRadius = 8;
  static const double navItemPaddingInline = 16;
  static const double navItemGap = 8;
  static const double navIconSize = 18;

  /// 左栏品牌行。
  static const double brandMarkWidth = 39;
  static const double brandMarkHeight = 47;
  static const double brandGap = 10;
  static const double brandFontSize = 20;

  /// 顶栏（仅左栏折叠时出现，只放展开按钮）。
  static const double headerHeight = 44;

  /// 右栏内部。
  static const double outputHeaderPaddingInline = 14;
  static const double outputTitleFontSize = 13;

  /// 中栏空态。
  static const double centerPaddingTop = 44;
  static const double contentPaddingInline = 16;

  /// 中栏内容列宽三档（设置页「转录宽度」）。
  ///
  /// 空态 / 转录 / 输入列共用同一档 —— 三者宽度必须一致，否则宽档下输入框
  /// 比正文窄，看着像设置没生效。档位与文案见 `services/layout` 的 `TranscriptWidth`。
  ///
  /// [transcriptMediumWidth] 取 800 是**等于历史值**（原先的 `contentMaxWidth`）：
  /// 新增这档设置不该改变任何人的现有界面，默认档必须与改之前逐像素相同。
  /// [transcriptWideWidth] 的 960 是 studio 内容列的原始出处
  /// （`features/WideScreenContainer/index.tsx:42-53` 的 `min(960, 100%)`），
  /// 之前被中栏统一限宽压到了 800。Narrow 640 是往回收一档。
  static const double transcriptNarrowWidth = 640;
  static const double transcriptMediumWidth = 800;
  static const double transcriptWideWidth = 960;

  /// 输入区外壳的**默认**宽度。三档生效时由
  /// `TranscriptWidth.composerWidth` 算出实际值，这个常量只剩「单独摆一个输入框」（测试、无外壳场景）时用。
  /// = [transcriptMediumWidth] - 2 × [contentPaddingInline]，两者本来就该相等。
  static const double inputAreaWidth = 768;
  static const double inputAreaRadius = 24;
  static const double heroAvatarSize = 72;
  static const double welcomeFontSize = 24;
  static const double skillChipHeight = 40;
}
