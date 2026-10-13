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

  /// 助手回复末尾品牌头像的直径。
  static const double avatarSize = 28;

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

  /// 工具行与末尾头像之间的间距。
  ///
  /// ⚠️ 头像现在在整段对话最后一组回答的末尾 ——
  /// 这个值量的是「工具行下方到头像」那道缝，改位置时别当成左内边距用。
  static const double avatarGap = 12;
}
