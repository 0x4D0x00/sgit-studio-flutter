/// 聊天气泡尺寸令牌 —— 用户气泡与助手回复**两套形态共用的一份量纲**。
///
/// ## 为什么不塞进 [WorkspaceMetrics] / [ComposerMetrics]
///
/// `WorkspaceMetrics` 管外壳（左右栏、导航行、内容列宽），`ComposerMetrics` 管输入框内部，
/// 两者都是「页面级」的。这份只管**对话流里的一条消息**，跟着气泡组件走 ——
/// 换一版气泡设计只动这里，不该惊动外壳或输入框。
///
/// 【为什么落 design/ 而不是 layout/】`ui/` 层按依赖方向禁止 import `layout/`
/// （ARCHITECTURE.md 第一节），而气泡在 `ui/components/chat/` 下。
class ChatBubbleMetrics {
  ChatBubbleMetrics._();

  // ---- 用户气泡 ----

  /// 用户气泡的宽度上限。
  ///
  /// ⚠️ 只对**用户**生效。助手回复不设上限，直接吃满外壳给的转录列宽
  /// （`TranscriptWidth` 的 640/800/960 三档）—— 否则设置页那个开关
  /// 对回复正文等于没生效。
  static const double maxWidthUser = 680;

  /// 用户气泡内边距。左右 16 是视觉留白，上下 12 比左右小一档 ——
  /// 单行气泡上下各 12 才像个方块而不是胶囊。
  static const double paddingInline = 16;
  static const double paddingBlock = 12;

  // ---- 助手回复（无气泡框）----

  /// 助手回复的上下内边距。
  ///
  /// ⚠️ **不是随手取的 16**：气泡去掉后，原来每条占的纵向空间是
  /// margin 4×2 + padding 12×2 = 32，这里用 16 上下正好**逐像素复刻**，
  /// 相邻回复的疏密不会因为这次重做而变。
  static const double assistantPaddingBlock = 16;

  // ---- 「正在思考」状态行 ----

  /// 状态行的左缩进。
  ///
  /// ⚠️ **0 是有意的**：助手回复是**无气泡框**的纯文字，正文从列首（x=0）起排。
  /// 给状态行加缩进反而会和它下面那段正文错开，看着像两条不相干的条目。
  /// 留这个令牌而不是直接写 0，是为了以后正文真有了左内边距时，改一处就跟上。
  static const double thinkingInline = 0;

  /// 状态行的上下留白。取助手正文的**一半** —— 它是过渡态，不该像一条真回答
  /// 那样占满整段节奏；给满 16 会让人觉得这是个已经结束了的东西。
  static const double thinkingPaddingBlock = 8;

  /// 状态行星形标记的边长。
  static const double thinkingMarkSize = 15;

  /// 状态行文字字号。比助手正文（14）小一档 —— 它是旁白，不是回答本身。
  static const double thinkingFontSize = 13;

  // ---- Markdown 块 ----

  /// 块间距(段落、列表、代码块之间的纵向留白)。
  static const double blockGap = 12;

  /// 代码块内边距。
  static const double codeBlockPadding = 12;

  /// 代码块圆角。
  static const double codeBlockRadius = 8;

  // ---- 正文里的横向滚动条（代码块 / 表格下方那条"可以右滑"的指示条）----

  /// 滑条粗细。
  ///
  /// 与 Material 默认(6)同档，但**必须显式写**：这是"这里能滑"的一句提示，
  /// 不是一件控件，再粗一点就会盖过代码正文。
  static const double hScrollThickness = 4;

  /// 滑条圆角。取 [hScrollThickness] 的一半 —— 滑块两端是半圆而不是方头。
  static const double hScrollRadius = 3;

  /// 滑条与内容底边的距离。留 1px 让它不贴着边框线画。
  static const double hScrollCrossAxisMargin = 1;

  /// 内容底边之下、留给滑条的那条空带高度。
  ///
  /// ⚠️ **这条空带是滑条能被画在"内容下方"的前提**：滑条的绘制区域就是
  /// 横向滚动视图的盒子，想画在正文外面，只能让那个盒子比正文高一点。
  /// 取 [hScrollThickness] + [hScrollCrossAxisMargin] 再多 1 —— 刚好容下，
  /// 且不显空。**溢出时才留**（见 `HorizontalScrollArea`），否则短代码块
  /// 底下会莫名其妙多出一道空白。
  static const double hScrollGutter = 8;

  /// 滑块不透明度。底色取 `skin.textTertiary`（明暗各一档由皮肤决定），
  /// 这里再压一层 —— 与 [hoverAlpha] 同一套「在既有色上叠不透明度」的写法，
  /// 组件不判 `isDark`。
  static const double hScrollThumbAlpha = 0.4;

  /// 产物文件卡片的最大宽度。
  ///
  /// ⚠️ **不能撑满转录列宽**：一张"文件卡"横贯整列会被读成一块区域分隔条，
  /// 而它其实是正文末尾的一个附属入口。贴合内容、到这就封顶。
  /// 取 [maxWidthUser] 的约 3/4 —— 比用户气泡窄一档，视觉上退到次要层。
  static const double artifactCardMaxWidth = 520;

  /// 产物文件卡片的左侧类型图标格边长。
  static const double artifactCardIconBox = 36;

  /// 列表项左侧缩进(每增加一层)。
  static const double listIndentPerLevel = 20;

  /// 列表标记与正文之间的间距。
  static const double listMarkerGap = 8;

  /// 引用块左侧竖条宽度。
  static const double quoteBarWidth = 3;

  /// 引用块左侧竖条与正文之间的间距。
  static const double quoteBarGap = 12;

  /// 标题字号档(level 1..6)。
  static const List<double> headingSizes = [18, 16, 14, 13, 12, 10];

  // ---- 「回到底部」浮出按钮 ----

  /// 按钮直径。与发送键同尺寸（32），浮在对话流上时不会比它更抢眼。
  static const double jumpButtonSize = 32;
  static const double jumpButtonIconSize = 18;

  /// 按钮与列表底边之间的距离。
  static const double jumpButtonMarginBottom = 12;

  /// 按钮浮出/收回的时长。比 [hoverFade] 略慢 —— 它是个整块的浮层出现，
  /// 不是给一行加底色，太快会像闪了一下。
  static const Duration jumpButtonFade = Duration(milliseconds: 180);

  /// 用户滚动后，按钮**还要再等这么久**才浮出来。
  ///
  /// 不是装饰性的延迟，是这个按钮能不能用的前提：把一段长回答滚到末尾时，
  /// 内容一边长高一边把视口顶离底部，中途的每一帧都满足"不在底部"。
  /// 少了这段停顿，滚动过程中按钮就会一路闪出来 —— 用户想看的恰恰是它挡住的
  /// 那部分内容。停顿是「我停下来了」和「内容还在长」的分界线。
  static const Duration scrollDwell = Duration(milliseconds: 600);

  // ---- 悬停 ----

  /// 悬停底色的不透明度。
  ///
  /// ⚠️ **和 `NavRow` 的行悬停是同一个值（0.06）**：两处都是「在既有底色上叠一层
  /// 文字色」。取两个值的话，同一份悬停手感会在导航栏和代码块之间出现温差。
  /// 底色由 `skin.text` 生成，明暗/透明三种模式自动跟着走，组件不判 `isDark`。
  static const double hoverAlpha = 0.06;

  /// 悬停态的过渡时长。全站悬停交互统一 150ms（同 `SkillCard`），
  /// 这里取名是为了不让组件各自写一遍魔法数字。
  static const Duration hoverFade = Duration(milliseconds: 150);
}
