import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/design/tokens/bubble_metrics.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_inline.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/code_block_card.dart';
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
  });

  final List<MarkdownBlock> blocks;

  /// 由父级(`_TextBubbleState`)持有，用于在 dispose 时批量释放链接的
  /// [TapGestureRecognizer]。每次调用 build 前父级会先把旧列表逐个 `dispose()`。
  final List<TapGestureRecognizer> recognizers;

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
      MdCodeFence() => CodeBlockCard(code: block.code, language: block.language),
      MdRule() => _rule(context),
      MdTable() => _table(context, block),
    };
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

    return SelectableText.rich(
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

    return SelectableText.rich(
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
            child: SelectableText.rich(
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

  Widget _table(BuildContext context, MdTable t) {
    final skin = AppSkin.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: skin.borderSecondary),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          TableRow(
            children: t.header
                .map((h) => Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Text(
                        h,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: skin.text,
                        ),
                      ),
                    ))
                .toList(),
          ),
          for (final row in t.rows)
            TableRow(
              children: row
                  .map((c) => Padding(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        child: Text(
                          c,
                          style: TextStyle(fontSize: 14, color: skin.text),
                        ),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}
