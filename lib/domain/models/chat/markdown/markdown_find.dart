/// 在块 AST 里数页内查找的匹配数 —— **纯 Dart**。
///
/// ⚠️ 遍历顺序与口径必须和渲染端（`MarkdownView` / `MarkdownSpans`）逐段一致：
/// 渲染时按同样的顺序给每个匹配编号，「当前第几个」才对得上。口径是
/// **叶子文本节点**（text / code / link 的显示文本）各数各的，所以跨粗体边界的
/// 匹配（`ab**c**` 里搜 `bc`）不算 —— 这是有意的取舍，换来计数与高亮不会漂。
///
/// 围栏代码块、文件卡、分隔线不参与（代码卡里的文字不是正文，也没有逐段高亮）。
library;

import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_inline.dart';
import 'package:sgit_studio_flutter/domain/models/find/find_matcher.dart';

abstract final class MarkdownFind {
  static int countBlocks(List<MarkdownBlock> blocks, String query) {
    var n = 0;
    for (final b in blocks) {
      n += switch (b) {
        MdParagraph() => countInline(b.text, query),
        MdHeading() => countInline(b.text, query),
        MdList() => b.items.fold(0, (s, i) => s + countInline(i.text, query)),
        MdQuote() => countBlocks(b.children, query),
        MdTable() =>
          b.header.fold(0, (s, c) => s + countInline(c, query)) +
              b.rows.fold(
                0,
                (s, r) => s + r.fold(0, (s2, c) => s2 + countInline(c, query)),
              ),
        MdCodeFence() || MdRule() => 0,
      };
    }
    return n;
  }

  static int countInline(String source, String query) =>
      _countNodes(MarkdownInlineParser.parse(source), query);

  static int _countNodes(List<MarkdownInline> nodes, String query) {
    var n = 0;
    for (final node in nodes) {
      switch (node.kind) {
        case MdInlineKind.text:
        case MdInlineKind.code:
        case MdInlineKind.link:
          n += FindMatcher.count(node.text, query);
        case MdInlineKind.bold:
        case MdInlineKind.italic:
        case MdInlineKind.boldItalic:
        case MdInlineKind.strikethrough:
          n += _countNodes(node.children!, query);
      }
    }
    return n;
  }
}
