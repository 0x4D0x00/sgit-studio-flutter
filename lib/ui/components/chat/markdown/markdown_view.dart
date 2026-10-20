import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/design/tokens/bubble_metrics.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_inline.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/chat/artifact_chip.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/code_block_card.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/horizontal_scroll_area.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/markdown_spans.dart';

/// Markdown 块级渲染器 —— 块 AST → Widget。
///
/// ## 为什么每块要包 KeyedSubtree
///
/// [MarkdownViewCache] 增量解析时前 N-1 块与上次 **identity 相同** ——
/// 若不给 key，Flutter 会认为"列表长度变了，整个 Column 的子树全部失效"，
/// 然后把每一块都 build 一遍。包了 key 之后，unchanged blocks[i] → key 不变 →
/// Element 复用 → 跳过 build 与 layout。
///
/// 只有最后一块每次 delta 都是新 object，所以只有它会重建。
class MarkdownView extends StatelessWidget {
  const MarkdownView({
    super.key,
    required this.blocks,
    required this.recognizers,
    this.artifacts = const [],
    this.onOpenArtifact,
    this.onDownloadArtifact,
  });

  final List<MarkdownBlock> blocks;

  /// 由父级(`_TextBubbleState`)持有，用于在 dispose 时批量释放链接的
  /// [TapGestureRecognizer]。每次调用 build 前父级会先把旧列表逐个 `dispose()`。
  final List<TapGestureRecognizer> recognizers;

  /// 本条消息里提取出的产物（**只包含超过行数阈值的长块**，见
  /// `ChatArtifact.fromBlocks` 的 `inlineLineLimit`）。
  ///
  /// 与围栏按 [ChatArtifact.sourceStart] 精确配对 —— 语言和内容都可能重复，
  /// 只有偏移是唯一的。
  final List<ChatArtifact> artifacts;

  /// 点击文件卡 → 右侧面板打开。
  final void Function(ChatArtifact artifact)? onOpenArtifact;

  /// 点击 Download。
  final void Function(ChatArtifact artifact)? onDownloadArtifact;

  /// 按偏移找这条围栏对应的产物。找不到（短块）返回 null。
  ChatArtifact? artifactFor(MdCodeFence fence) {
    for (final a in artifacts) {
      if (a.sourceStart == fence.sourceStart) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, block) in blocks.indexed) ...[
          if (i > 0) const SizedBox(height: ChatBubbleMetrics.blockGap),
          KeyedSubtree(
            key: ValueKey('${block.sourceStart}:${block.runtimeType}'),
            child: _buildBlock(context, block),
          ),
        ],
      ],
    );
  }

  Widget _buildBlock(BuildContext context, MarkdownBlock block) {
    return switch (block) {
      MdParagraph() => _paragraph(context, block),
      MdHeading() => _heading(context, block),
      MdList() => _list(context, block),
      MdQuote() => _quote(context, block),
      MdCodeFence() => _codeBlock(context, block),
      MdRule() => _rule(context),
      MdTable() => _table(context, block),
    };
  }

  /// 围栏 → 短块内联代码卡；长块（有产物）→ **只画文件卡，不画正文**。
  /// ⚠️ 配对按偏移。对不上（短块、空围栏、或流式期产物还没提取到）时
  /// 一律走普通代码卡 —— 短块本来就该内联，这是安全的默认。
  Widget _codeBlock(BuildContext context, MdCodeFence block) {
    final artifact = artifactFor(block);
    if (artifact == null) {
      return CodeBlockCard(code: block.code, language: block.language);
    }

    return ArtifactChip(
      artifact: artifact,
      downloadLabel: AppLocalizations.of(context).chatArtifactDownload,
      onTap: onOpenArtifact == null ? () {} : () => onOpenArtifact!(artifact),
      onDownload: onDownloadArtifact == null
          ? () {}
          : () => onDownloadArtifact!(artifact),
    );
  }

  Widget _paragraph(BuildContext context, MdParagraph p) {
    final skin = AppSkin.of(context);
    final inlines = MarkdownInlineParser.parse(p.text);
    final spans = MarkdownSpans.build(
      inlines,
      context,
      recognizers,
      baseStyle: TextStyle(fontSize: 14, height: 1.6, color: skin.text),
    );

    return Text.rich(
      TextSpan(children: spans),
    );
  }

  Widget _heading(BuildContext context, MdHeading h) {
    final skin = AppSkin.of(context);
    final inlines = MarkdownInlineParser.parse(h.text);
    final size = ChatBubbleMetrics.headingSizes[h.level - 1];
    final spans = MarkdownSpans.build(
      inlines,
      context,
      recognizers,
      baseStyle: TextStyle(
        fontSize: size,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: skin.text,
      ),
    );

    return Text.rich(
      TextSpan(children: spans),
    );
  }

  Widget _list(BuildContext context, MdList list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, item) in list.items.indexed) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xxs),
          _listItem(context, list.ordered, item),
        ],
      ],
    );
  }

  Widget _listItem(BuildContext context, bool ordered, MdListItem item) {
    final skin = AppSkin.of(context);
    final inlines = MarkdownInlineParser.parse(item.text);
    final spans = MarkdownSpans.build(
      inlines,
      context,
      recognizers,
      baseStyle: TextStyle(fontSize: 14, height: 1.6, color: skin.text),
    );

    final marker = ordered ? '${item.number}.' : '•';
    final indent = item.depth * ChatBubbleMetrics.listIndentPerLevel;

    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              marker,
              style: TextStyle(fontSize: 14, color: skin.textSecondary),
            ),
          ),
          const SizedBox(width: ChatBubbleMetrics.listMarkerGap),
          Expanded(
            child: Text.rich(
              TextSpan(children: spans),
            ),
          ),
        ],
      ),
    );
  }

  /// 引用块：左侧一道竖条 + 内容。
  ///
  /// ⚠️ 竖条用 [BoxDecoration] 的 `border.left` 画，**不是**一个
  /// `height: double.infinity` 的子 `Container` —— 后者在 `Row` 里会撑成无限高
  /// 直接抛布局异常。左边框随内容自动等高，还省掉一层 `IntrinsicHeight`。
  Widget _quote(BuildContext context, MdQuote q) {
    final skin = AppSkin.of(context);
    return Container(
      padding: const EdgeInsets.only(
        left: ChatBubbleMetrics.quoteBarGap,
        top: AppSpacing.xxs,
        bottom: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: skin.borderSecondary,
            width: ChatBubbleMetrics.quoteBarWidth,
          ),
        ),
      ),
      child: MarkdownView(blocks: q.children, recognizers: recognizers),
    );
  }

  Widget _rule(BuildContext context) {
    final skin = AppSkin.of(context);
    return Divider(color: skin.borderSecondary, thickness: 1);
  }

  /// GFM 表格。
  ///
  /// ⚠️ 单元格**必须走行内 markdown**（`MarkdownInlineParser`），不能直接
  /// `Text(cell)` —— 模型在表格里写 `**办公助理**` 是家常便饭（表格常用来做
  /// 分类罗列，条目名天然带强调），用 `Text` 会把星号原样画出来。
  ///
  /// 单元格与段落一样用普通 [Text]（**不是 `SelectableText`**）：选区由
  /// `ChatTranscript` 那一个 `SelectionArea` 统一管，表格格子也是它的一块
  /// `Selectable`，所以拖选能跨段落进表格，Ctrl+A 也不会只选中当前那一格。
  /// `IntrinsicColumnWidth` 下 [Text] 的 `minIntrinsicWidth` 仍是整行文本宽度，
  /// 表格照常收缩换行。
  ///
  /// 链接的点击不受影响：[MarkdownSpans] 产出的 `TextSpan.recognizer` 由
  /// `RenderParagraph` 自己派发，与有没有 `SelectableText` 无关。
  ///
  /// ⚠️ 列多时表格会超出列宽被裁掉 —— 右侧那几列既看不见也没提示。走
  /// [HorizontalScrollArea] 在表格下方补一道滑块（装得下时它自己不出）。
  Widget _table(BuildContext context, MdTable t) {
    final skin = AppSkin.of(context);
    return HorizontalScrollArea(
      child: Table(
        border: TableBorder.all(color: skin.borderSecondary),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          TableRow(
            children: [
              for (final h in t.header)
                _tableCell(context, h,
                    const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          // ⚠️ 行高由解析器保证是矩形（每行格数 == 表头格数，见
          // `MarkdownParser._fitToWidth`），这里不再做防御 —— 补在解析器
          // 一处比在每个渲染分支补更可靠，也才有单测能钉住。
          for (final row in t.rows)
            TableRow(
              children: [
                for (final c in row)
                  _tableCell(context, c, const TextStyle(fontSize: 14)),
              ],
            ),
        ],
      ),
    );
  }

  /// 一个表格单元格：行内 markdown + [AppSpacing.xs] 内边距。
  Widget _tableCell(BuildContext context, String text, TextStyle style) {
    final skin = AppSkin.of(context);
    final spans = MarkdownSpans.build(
      MarkdownInlineParser.parse(text),
      context,
      recognizers,
      baseStyle: style.copyWith(color: skin.text),
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Text.rich(TextSpan(children: spans)),
    );
  }
}
