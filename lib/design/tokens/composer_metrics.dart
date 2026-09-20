/// 输入框尺寸令牌 —— **1:1 对齐 sgit-studio（React）的 ChatInput**。
///
/// 每一项都标了 React 侧的出处。改这里之前先去那边确认，别凭手感调 ——
/// `test/composer_metrics_test.dart` 钉住了这些值，改动即红，逼你回来看一眼出处。
///
/// ## 为什么不塞进 [WorkspaceMetrics]
///
/// 那份管的是**外壳**（左右栏宽度、导航行高、内容列宽），一页一份；
/// 这份管的是**输入框内部**，跟着组件走。两者生命周期不同：换一版输入框设计
/// 只动这份，不该惊动布局。
class ComposerMetrics {
  ComposerMetrics._();

  // ---- 玻璃外壳 ----
  // 出处：features/ChatInput/glassInputStyle.ts:7-17

  /// 外壳圆角。⚠️ 与 `WorkspaceMetrics.inputAreaRadius` 同值（24），但**不复用它** ——
  /// 那个是布局给输入区预留的位置圆角，这个是输入框自己的。两者恰好相等是巧合。
  static const double shellRadius = 24;

  /// 外壳四边内边距。React 是 `padding: 16` 一个值（**四边相同**）。
  /// 旧版 Flutter 写成 `symmetric(horizontal: 16, vertical: 8)`，上下少了一半。
  static const double shellPadding = 16;

  static const double shellBorderWidth = 1;

  /// 磨砂模糊半径。React: `backdrop-filter: blur(12px) saturate(160%)`。
  ///
  /// ⚠️ 不用 `AppSkin.blurSigma`（16）—— 那是玻璃卡片的值，比输入框重。
  /// 但仍要尊重 `blurSigma <= 0` 的特效降级（见 `composer_shell.dart`）。
  static const double shellBlurSigma = 12;

  /// 顶部 1px 高光的高度。React 用 `inset 0 1px 0 ...` 实现，
  /// Flutter 的 `BoxDecoration` 没有 inset shadow，用一条渐变顶边代替。
  static const double shellInsetHighlightHeight = 1;

  // ---- 编辑区 ----
  // 出处：Desktop/index.tsx:181-188（会话态）、home/features/InputArea/index.tsx:144-153（空态）

  /// 会话态最小高度。
  static const double editorMinHeightConversation = 36;

  /// 空态最小高度。React 注释：「编辑区最小高度:整框砍掉约 1/3(184→~123)」。
  static const double editorMinHeightEmpty = 60;

  /// 最大高度（两态相同）。超过后内部滚动。
  static const double editorMaxHeight = 320;

  /// 拖拽把手的命中高度。React 的 `resize={true}` 在底边给一条可拖区。
  static const double editorResizeHandleHeight = 6;

  // ---- 动作栏 ----
  // 出处：ActionBar/Plus/index.tsx:706、components/Action.tsx:76-81

  /// 图标按钮的方块边长（React 的 `blockSize`）。
  static const double actionButtonSize = 32;

  /// 图标本身的字号（React 的 `size`）。
  static const double actionIconSize = 18;

  static const double actionButtonRadius = 8;

  /// 动作栏左内边距。出处：ActionBar/index.tsx:90 `paddingLeft: 6`。
  static const double actionBarPaddingStart = 6;

  /// 动作栏右内边距。出处：Desktop/index.tsx:192 `paddingRight: 8`。
  static const double actionBarPaddingEnd = 8;

  /// 编辑区与动作栏之间的竖直间隔。
  static const double actionBarGapTop = 8;

  /// 发送区内各元素的横向间距。出处：SendArea/index.tsx:30 `gap={12}`。
  static const double sendAreaGap = 12;

  // ---- 模型名标签（空态右侧）----
  // 出处：ActionBar/ModelLabel/index.tsx:17-49,88-100

  static const double modelLabelHeight = 28;
  static const double modelLabelPaddingInline = 6;
  static const double modelLabelRadius = 4;
  static const double modelLabelFontSize = 12;
  static const double modelLabelMaxWidth = 160;
  static const double modelLabelChevronSize = 12;

  /// 名字与 chevron 之间。React: `<Flexbox gap={2}>`。
  static const double modelLabelGap = 2;

  // ---- 动作栏项之间 ----

  /// 动作栏里相邻小控件之间的间隔（模型图标 ↔ `+` ↔ 审批策略）。
  ///
  /// ⚠️ studio 那排里还有一个「已选定场景」小标签（它的 SkillTag，高 24 的青绿胶囊）。
  /// **我们没做** —— 那个标签要有"当前选了哪个场景"这个状态才有东西可显示，而本仓
  /// 首页的技能标签目前还是写死的占位数据（见 `workspace_hero.dart` 的 `TODO(P2)`），
  /// 压根没有选定态。等场景选定接上来，再照 `ActionBar/SkillTag/index.tsx:18-51`
  /// 补：高 24 / 左右 8 / 全圆角 / 字 12 粗 500 / `#009688`，底 8%、边 20%。
  static const double actionItemGap = 4;

  /// chip 上那个 × 的字号（附件 chip 用）。
  static const double chipCloseIconSize = 12;

  // ---- 上下文窗口标签 ----
  // 出处：ActionBar/Token/TokenTag.tsx:244-247

  static const double tokenTagHeight = 28;
  static const double tokenTagIconSize = 18;

  /// 占用低于这个比例时整个标签**不渲染**。
  /// 出处：TokenTag.tsx:158 `if (!isDevMode && maxTokens > 0 && totalToken / maxTokens <= 0.5) return null`。
  static const double tokenTagVisibleThreshold = 0.5;

  /// 环形进度的线宽。
  static const double tokenTagRingStroke = 2;

  // ---- 附件区 ----
  // 出处：Desktop/ContextContainer/index.tsx:13 `paddingInline={8}`

  static const double attachmentAreaPaddingInline = 8;
  static const double attachmentChipHeight = 28;
  static const double attachmentChipRadius = 6;
  static const double attachmentChipPaddingInline = 8;
  static const double attachmentChipIconSize = 16;
  static const double attachmentChipFontSize = 12;
  static const double attachmentChipGap = 4;

  /// 附件名最大宽度（超出省略）。
  static const double attachmentChipMaxNameWidth = 150;

  // ---- 发送键 ----
  // 出处：MainChatInput/index.tsx:54 `sendButtonProps: { shape: 'round' }`

  /// 圆形发送键直径。与动作栏图标按钮同高，视觉基线才对齐。
  static const double sendButtonSize = 32;
  static const double sendButtonIconSize = 18;

  // ---- 控制条（输入框下方那一行）----
  // 出处：ControlBar/index.tsx:16-40

  static const double controlBarHeight = 28;
  static const double controlBarPaddingInline = 4;
  static const double controlBarGap = 4;

  // 控制条上的按钮。出处：ControlBar/ModeSelector.tsx:45-67
  static const double controlButtonHeight = 28;
  static const double controlButtonPaddingInline = 8;
  static const double controlButtonRadius = 6;
  static const double controlButtonFontSize = 12;
  static const double controlButtonIconSize = 14;
  static const double controlButtonChevronSize = 12;
  static const double controlButtonGap = 6;

  // ---- 弹出面板 ----
  // 出处：ApprovalPolicy/index.tsx:130 `minWidth: 260`、ModeSelector.tsx:187 `{maxWidth:320,minWidth:280}`

  static const double popoverMinWidth = 260;
  static const double popoverMaxWidth = 320;

  /// 带描述的两行项里，左侧图标方块的边长。
  /// 出处：ModeSelector.tsx:199-206 `height={32} width={32}`。
  static const double richItemIconBoxSize = 32;
  static const double richItemIconSize = 16;
}
