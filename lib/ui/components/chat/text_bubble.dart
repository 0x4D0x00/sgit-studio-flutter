import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/design/tokens/bubble_metrics.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/export/artifact_exporter.dart';
import 'package:sgit_studio_flutter/services/layout/layout_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/bubble_actions_row.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/markdown_view.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/markdown_view_cache.dart';

/// 文本气泡。**流式期间只有它自己重建。**
///
/// 订阅的是 [TextItem.revision] 这一条 `ValueListenable`，不是整个列表的状态 ——
/// 所以 native 推来一条 delta，重建范围就是这一个气泡，而不是 `ListView` 全体。
/// 这是长回答不掉帧的关键，改之前先读 `docs/KERNEL_FFI.md` §4。
///
/// ## 两种角色是两套形态，不是同一套换个颜色
///
/// - **用户消息**：实心中性灰气泡（[AppSkin.bubbleUserBg]）、圆角、无描边，宽度贴合内容；
/// - **助手回复**：**没有气泡框** —— 纯文字浮在背景上，铺满转录列宽。
///
/// 所以下面按角色分支成两条子树，而不是在一个 `Container` 上做三元：两者连
/// 「有没有 Container」都不一样，硬合并只会得到一个满是条件的分支。
class TextBubble extends ConsumerStatefulWidget {
  const TextBubble({
    super.key,
    required this.item,
    required this.truncatedHint,
    this.isLastAnswer = false,
    this.replyComplete = false,
    this.onEditSave,
  });

  final TextItem item;

  /// 「内容可能不完整」提示文案（native 背压丢过 delta 时显示）。
  final String truncatedHint;

  /// 这条是不是当前会话最后一组回答的末尾气泡 —— 是的话工具行常驻显示，
  /// 不需要悬停（用户气泡从不常驻，只有回答气泡走这条）。
  ///
  /// ⚠️ 光有它**不够**：跑动期间列表末尾那条就是正在流出来的那条，所以它
  /// 一轮里会先后落在每一段回答上。必须与 [replyComplete] 一起用。
  final bool isLastAnswer;

  /// 这条所在的**整轮回答**是否已经结束（内核的 turn 跑完了）。
  ///
  /// ⚠️ **false 时工具行整块不渲染，连那 24px 占位高度都不留。** 两件事各有
  /// 各的理由，但都由这一个开关管：
  ///
  /// 1. **内容**：回复还在往外吐的时候，底下不该冒出一排「复制 / 朗读 / 重试」
  ///    —— 那些按钮对一段还会变长的文本没有意义，而且鼠标一移上去就闪。
  /// 2. **占位**：答案常常由**多段**组成（`itemStarted`/`itemCompleted` 成对出现，
  ///    中间还夹着工具卡）。每段都是一个独立的 [TextBubble]，若只把工具行挖空、
  ///    留着固定高度，回答中间就会凭空多出一道 24px 的缝 —— 看着像正文缺了一块。
  ///
  /// 默认 false（**失败时偏向不显示**）：谁忘了传，最坏结果是工具行不出现，
  /// 而不是在流式回答中间冒出一排按钮。历史回放与历史消息一律传 true。
  final bool replyComplete;

  /// 仅用户气泡传入：气泡内联编辑保存后调用，参数是编辑后的文本。
  /// 调用方（[ChatTranscript]）据此丢弃这条之后的内容并重新发送。
  final void Function(String text)? onEditSave;

  @override
  ConsumerState<TextBubble> createState() => _TextBubbleState();
}

class _TextBubbleState extends ConsumerState<TextBubble> {
  bool _hovering = false;

  /// 正在气泡内编辑。非 null 时气泡内容替换成输入框。
  TextEditingController? _editCtl;

  /// Markdown 块级缓存 —— 流式追加时只重解析最后一块。
  final _mdCache = MarkdownViewCache();

  /// 链接的 [TapGestureRecognizer] 列表。每次重建前逐个 `dispose()` 旧列表，
  /// 新列表由 [MarkdownSpans.build] 填充 —— 不释放就每条 delta 泄漏几个。
  var _recognizers = <TapGestureRecognizer>[];

  void _startEdit(String text) {
    setState(() => _editCtl = TextEditingController(text: text)
      ..selection = TextSelection.collapsed(offset: text.length));
  }

  void _cancelEdit() {
    _editCtl?.dispose();
    setState(() => _editCtl = null);
  }

  void _saveEdit() {
    final text = _editCtl!.text.trim();
    if (text.isEmpty || text == widget.item.text.trim()) return;
    widget.onEditSave?.call(text);
    _editCtl!.dispose();
    setState(() => _editCtl = null);
  }

  @override
  void dispose() {
    _editCtl?.dispose();
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final item = widget.item;
    final isUser = item.role == ChatRole.user;
    // 用户气泡从不常驻，只有"当前回答"的末尾气泡才常驻。
    // ⚠️ 助手那边还要再过一道 [replyComplete]，见 [_assistantReply]。
    final showActions = _hovering || (widget.isLastAnswer && !isUser);
    final editing = _editCtl != null;

    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: item.revision,
        builder: (context, _, _) {
          // 产物从**已经解析好的块**里提取，不另扫一遍原文 —— 围栏识别只有
          // 解析器一处实现。流式期也提取：卡片头要跟着 delta 一起长出来。
          // ⚠️ 用 [TextItem.displayText] 而不是 `item.text`：助手回复开头的
          //    「技能 / 工具调用抬头」在协议层仍然存在（回放要用），但界面上
          //    不该出现 —— 也不该被复制走，所以解析与产物提取都走同一份文本。
          final body = item.displayText;
          final blocks = _mdCache.parse(body);
          final artifacts = ChatArtifact.fromBlocks(blocks, body);

          final bubble = editing
              ? _buildEditor(context, skin)
              : (isUser
                  ? _userBubble(context, skin, item, showActions, artifacts)
                  : _assistantReply(
                      skin, item, blocks, showActions, artifacts));

          return MouseRegion(
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: bubble,
          );
        },
      ),
    );
  }

  /// 用户消息：实心灰气泡，宽度贴合内容。
  ///
  /// ⚠️ **没有 `border`**。去掉描边后内缩少了 1px，是有意的视觉变化 ——
  /// 描边的气泡在浅灰填充下看着像输入框。宽度仍限在
  /// [ChatBubbleMetrics.maxWidthUser]，长消息不至于横贯整列。
  Widget _userBubble(
    BuildContext context,
    AppSkin skin,
    TextItem item,
    bool showActions,
    List<ChatArtifact> artifacts,
  ) =>
      Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              maxWidth: ChatBubbleMetrics.maxWidthUser),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                padding: const EdgeInsets.symmetric(
                  horizontal: ChatBubbleMetrics.paddingInline,
                  vertical: ChatBubbleMetrics.paddingBlock,
                ),
                decoration: BoxDecoration(
                  color: skin.bubbleUserBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                // 用户消息不渲染 markdown，块列表用不上 —— 产物仍从原文提取。
                child: _body(skin, item, const [], artifacts),
              ),
              _actionsSlot(context, item,
                  isUser: true, showActions: showActions),
            ],
          ),
        ),
      );

  /// 助手回复：**无气泡框**，纯文字铺满转录列宽。
  ///
  /// ⚠️ 这里刻意用 `Padding` 而不是 `Container(color: Colors.transparent)` ——
  /// 后者仍会插一个 `DecoratedBox` 绘制层，每帧白画一遍。
  ///
  /// 也**不套 `ConstrainedBox`**：让它吃满外壳给的转录列宽，设置页的
  /// 「转录宽度」三档才对回复真正生效。
  Widget _assistantReply(
    AppSkin skin,
    TextItem item,
    List<MarkdownBlock> blocks,
    bool showActions,
    List<ChatArtifact> artifacts,
  ) =>
      Column(
        // 头像与正文都从列首起排，所以这里是 start 而不是 stretch。
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                vertical: ChatBubbleMetrics.assistantPaddingBlock),
            child: _body(skin, item, blocks, artifacts),
          ),
          // ⚠️ 回答还没结束就**整块不渲染** —— 连那 24px 的占位高度一起省掉。
          // 一段回答由多个 [TextBubble] 拼成，留着占位会让正文中间凭空多出
          // 一道缝（见 [replyComplete]）。
          if (widget.replyComplete)
            _actionsSlot(context, item,
                isUser: false, showActions: showActions),
        ],
      );

  /// 正文：文本 + 截断提示 + 代码块芯片。两种形态共用，但渲染逻辑按角色分流。
  ///
  /// 用户消息维持纯文本；助手回复走 markdown。代码块芯片**两者都保留** ——
  /// 语义变成"去右侧面板打开"，与原地渲染的代码块互补而非重复。
  Widget _body(
    AppSkin skin,
    TextItem item,
    List<MarkdownBlock> blocks,
    List<ChatArtifact> artifacts,
  ) {
    final isUser = item.role == ChatRole.user;

    // 每次重建前先释放上次的 recognizers。
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers = <TapGestureRecognizer>[];

    final content = isUser
        // ⚠️ 普通 [Text]，不是 `SelectableText` —— 选区由外层的
        // `SelectionArea` 统一管（见 `ChatTranscript`）。`SelectableText`
        // 每个实例自带 `EditableText` 和一套独立选区，Ctrl+A 只能选中自己，
        // 这正是"只能选一行"的成因。
        ? Text(
            item.displayText,
            style: TextStyle(fontSize: 14, height: 1.6, color: skin.text),
          )
        : MarkdownView(
            blocks: blocks,
            recognizers: _recognizers,
            artifacts: artifacts,
            onOpenArtifact: _openArtifact,
            onDownloadArtifact: _downloadArtifact,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        content,
        if (item.truncated)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xxs),
            child: Text(
              widget.truncatedHint,
              style: TextStyle(fontSize: 11, color: skin.textTertiary),
            ),
          ),
        // ⚠️ 长块的文件卡**不在这里**再列一遍 —— 它由 `MarkdownView` 渲染在
        //    代码块原来的位置（替代正文）。这里再排一列会让同一份产物出现两次。
      ],
    );
  }

  /// 打开产物到右侧面板。
  void _openArtifact(ChatArtifact artifact) =>
      ref.read(layoutControllerProvider.notifier).showArtifact(artifact);

  /// 保存产物到本地。
  ///
  /// ⚠️ 三态提示：取消**不提示**。用户主动关掉文件对话框却看到"保存失败"
  /// 会以为出了问题，实际上什么都没发生。
  Future<void> _downloadArtifact(ChatArtifact artifact) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ArtifactExporter.save(
      artifact,
      dialogTitle: l10n.chatArtifactDownload,
    );
    if (outcome == SaveOutcome.cancelled) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          outcome == SaveOutcome.saved
              ? l10n.chatArtifactSaved
              : l10n.chatArtifactSaveFailed,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 悬浮工具行。占位高度固定，避免显示/隐藏时内容跳动。
  Widget _actionsSlot(
    BuildContext context,
    TextItem item, {
    required bool isUser,
    required bool showActions,
  }) =>
      SizedBox(
        height: 24,
        child: showActions
            ? Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: BubbleActionsRow(
                  isUser: isUser,
                  createdAt: item.createdAt,
                  onCopy: () => copyToClipboard(context, item.displayText,
                      AppLocalizations.of(context).chatCopied),
                  onEdit: isUser ? () => _startEdit(item.displayText) : null,
                ),
              )
            : null,
      );

  /// 气泡内联编辑态：替换成输入框 + 取消/保存。**保存会丢弃这条之后的内容并
  /// 重新发送**，取消原样恢复。
  Widget _buildEditor(BuildContext context, AppSkin skin) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
            maxWidth: ChatBubbleMetrics.maxWidthUser),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: TextField(
                controller: _editCtl,
                autofocus: true,
                maxLines: null,
                style: TextStyle(fontSize: 14, height: 1.6, color: skin.text),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: skin.containerBgSecondary,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: skin.borderSecondary),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: skin.borderSecondary),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: scheme.primary, width: 2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: l10n.chatEditRegenerateHint,
                    child: Icon(Icons.info_outline,
                        size: 14, color: skin.textTertiary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: _cancelEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: skin.text,
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(l10n.commonCancel,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _editCtl!,
                    builder: (context, value, _) {
                      // 内容为空或与原文一致（没改动）时保存不可点。
                      final trimmed = value.text.trim();
                      final enabled = trimmed.isNotEmpty &&
                          trimmed != widget.item.text.trim();
                      return TextButton(
                        onPressed: enabled ? _saveEdit : null,
                        style: TextButton.styleFrom(
                          foregroundColor:
                              enabled ? scheme.primary : skin.textTertiary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(l10n.commonSave,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
