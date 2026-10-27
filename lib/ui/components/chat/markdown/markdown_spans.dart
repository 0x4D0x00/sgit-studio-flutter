import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_typography.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_inline.dart';
import 'package:sgit_studio_flutter/ui/components/chat/bubble_actions_row.dart';
import 'package:sgit_studio_flutter/ui/components/find/find_highlight.dart';

/// 行内 Markdown 节点 → Flutter [TextSpan]。
///
/// ## TapGestureRecognizer 必须释放
///
/// 每个链接都 `new TapGestureRecognizer()`，而这个 class 持有 **GestureArenaManager
/// 的一个 entry**，不释放就一直占着。流式输出每条 delta 都重建，含链接的消息
/// 会每秒泄漏几个，几千条 delta 后就是几千个 —— 不显式 `dispose()` 就等内存爆。
///
/// 谁来释放：`_TextBubbleState` 持有一个 `List<TapGestureRecognizer>`，每次调用前
/// 先把旧列表逐个 `dispose()`，调用后把新 recognizers 存起来，`dispose()` 时再清一次。
class MarkdownSpans {
  MarkdownSpans._();

  /// 把行内节点列表转成 Flutter spans。
  ///
  /// [recognizers] 会收集所有创建的 [TapGestureRecognizer]，调用者负责在
  /// 不再使用时逐个 `dispose()`。
  static List<InlineSpan> build(
    List<MarkdownInline> nodes,
    BuildContext context,
    List<TapGestureRecognizer> recognizers, {
    TextStyle? baseStyle,
    FindHighlight? find,
  }) {
    final skin = AppSkin.of(context);
    final scheme = Theme.of(context).colorScheme;
    final base = baseStyle ?? TextStyle(fontSize: 14, height: 1.6, color: skin.text);

    return nodes.map((n) => _nodeToSpan(n, base, skin, scheme, context, recognizers, find)).toList();
  }

  /// 叶子文本。查找开着时按匹配切段高亮，否则就是一个普通 [TextSpan]。
  static TextSpan _leaf(
    String text,
    TextStyle style,
    FindHighlight? find, {
    GestureRecognizer? recognizer,
  }) =>
      find == null
          ? TextSpan(text: text, style: style, recognizer: recognizer)
          : find.span(text, style, recognizer: recognizer);

  static InlineSpan _nodeToSpan(
    MarkdownInline node,
    TextStyle base,
    AppSkin skin,
    ColorScheme scheme,
    BuildContext context,
    List<TapGestureRecognizer> recognizers,
    FindHighlight? find,
  ) {
    switch (node.kind) {
      case MdInlineKind.text:
        return _leaf(node.text, base, find);

      case MdInlineKind.code:
        return _leaf(
          node.text,
          base.copyWith(
            fontFamily: AppTypography.monospace,
            fontSize: base.fontSize! * 0.9,
            backgroundColor: skin.containerBgSecondary,
          ),
          find,
        );

      case MdInlineKind.link:
        final rec = TapGestureRecognizer()
          ..onTap = () {
            final href = node.href!;
            copyToClipboard(
              context,
              href,
              '已复制链接',
            );
          };
        recognizers.add(rec);
        return _leaf(
          node.text,
          base.copyWith(
            color: scheme.primary,
            decoration: TextDecoration.underline,
          ),
          find,
          recognizer: rec,
        );

      case MdInlineKind.bold:
        final children = node.children!;
        return TextSpan(
          children: children.map((c) => _nodeToSpan(c, base.copyWith(fontWeight: FontWeight.w700), skin, scheme, context, recognizers, find)).toList(),
        );

      case MdInlineKind.italic:
        final children = node.children!;
        return TextSpan(
          children: children.map((c) => _nodeToSpan(c, base.copyWith(fontStyle: FontStyle.italic), skin, scheme, context, recognizers, find)).toList(),
        );

      case MdInlineKind.boldItalic:
        final children = node.children!;
        return TextSpan(
          children: children.map((c) => _nodeToSpan(c, base.copyWith(fontWeight: FontWeight.w700, fontStyle: FontStyle.italic), skin, scheme, context, recognizers, find)).toList(),
        );

      case MdInlineKind.strikethrough:
        final children = node.children!;
        return TextSpan(
          children: children.map((c) => _nodeToSpan(c, base.copyWith(decoration: TextDecoration.lineThrough), skin, scheme, context, recognizers, find)).toList(),
        );
    }
  }
}
