import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_typography.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_inline.dart';
import 'package:sgit_studio_flutter/ui/components/chat/bubble_actions_row.dart';

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
  }) {
    final skin = AppSkin.of(context);
    final scheme = Theme.of(context).colorScheme;
    final base = baseStyle ?? TextStyle(fontSize: 14, height: 1.6, color: skin.text);

    return nodes.map((n) => _nodeToSpan(n, base, skin, scheme, context, recognizers)).toList();
  }

  static InlineSpan _nodeToSpan(
    MarkdownInline node,
    TextStyle base,
    AppSkin skin,
    ColorScheme scheme,
    BuildContext context,
    List<TapGestureRecognizer> recognizers,
  ) {
    switch (node.kind) {
      case MdInlineKind.text:
        return TextSpan(text: node.text, style: base);

      case MdInlineKind.code:
        return TextSpan(
          text: node.text,
          style: base.copyWith(
            fontFamily: AppTypography.monospace,
            fontSize: base.fontSize! * 0.9,
            backgroundColor: skin.containerBgSecondary,
          ),
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
        return TextSpan(
          text: node.text,
          style: base.copyWith(
            color: scheme.primary,
            decoration: TextDecoration.underline,
          ),
          recognizer: rec,
        );

      case MdInlineKind.bold:
        final children = node.children!;
        return TextSpan(
          children: children.map((c) => _nodeToSpan(c, base.copyWith(fontWeight: FontWeight.w700), skin, scheme, context, recognizers)).toList(),
        );

      case MdInlineKind.italic:
        final children = node.children!;
        return TextSpan(
          children: children.map((c) => _nodeToSpan(c, base.copyWith(fontStyle: FontStyle.italic), skin, scheme, context, recognizers)).toList(),
        );

      case MdInlineKind.boldItalic:
        final children = node.children!;
        return TextSpan(
          children: children.map((c) => _nodeToSpan(c, base.copyWith(fontWeight: FontWeight.w700, fontStyle: FontStyle.italic), skin, scheme, context, recognizers)).toList(),
        );

      case MdInlineKind.strikethrough:
        final children = node.children!;
        return TextSpan(
          children: children.map((c) => _nodeToSpan(c, base.copyWith(decoration: TextDecoration.lineThrough), skin, scheme, context, recognizers)).toList(),
        );
    }
  }
}
