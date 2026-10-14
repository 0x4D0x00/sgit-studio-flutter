import 'package:flutter_test/flutter_test.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_inline.dart';

/// Markdown 解析器单测 —— **纯 Dart，不 pump widget**。
///
/// 守住的边界：流式输出期间天然是半截文本 ——未闭合围栏、未闭合强调、
/// 连续星号、伪表格、CRLF、极深嵌套。任何一条都不能抛异常或退化成超线性扫描。
void main() {
  group('MarkdownBlock', () {
    test('段落', () {
      final blocks = MarkdownParser.parse('第一段\n\n第二段');
      expect(blocks.length, 2);
      expect(blocks[0], isA<MdParagraph>());
      expect((blocks[0] as MdParagraph).text, '第一段');
      expect((blocks[1] as MdParagraph).text, '第二段');
    });

    test('ATX 标题', () {
      final blocks = MarkdownParser.parse('# H1\n## H2\n### H3');
      expect(blocks.length, 3);
      final h1 = blocks[0] as MdHeading;
      final h2 = blocks[1] as MdHeading;
      final h3 = blocks[2] as MdHeading;
      expect(h1.level, 1);
      expect(h1.text, 'H1');
      expect(h2.level, 2);
      expect(h3.level, 3);
    });

    test('setext 标题', () {
      final blocks = MarkdownParser.parse('标题\n===\n\n副标题\n---');
      expect(blocks.length, 2);
      expect((blocks[0] as MdHeading).level, 1);
      expect((blocks[0] as MdHeading).text, '标题');
      expect((blocks[1] as MdHeading).level, 2);
      expect((blocks[1] as MdHeading).text, '副标题');
    });

    test('无序列表', () {
      final blocks = MarkdownParser.parse('- 一\n- 二\n  - 二点一');
      expect(blocks.length, 1);
      final list = blocks[0] as MdList;
      expect(list.ordered, false);
      expect(list.items.length, 3);
      expect(list.items[0].text, '一');
      expect(list.items[1].text, '二');
      expect(list.items[2].text, '二点一');
      expect(list.items[2].depth, 1);
    });

    test('有序列表', () {
      final blocks = MarkdownParser.parse('1. 第一\n2. 第二\n3. 第三');
      final list = blocks[0] as MdList;
      expect(list.ordered, true);
      expect(list.items[0].number, 1);
      expect(list.items[1].number, 2);
    });

    test('引用块', () {
      final blocks = MarkdownParser.parse('> 引用段落\n> 续行');
      expect(blocks.length, 1);
      final quote = blocks[0] as MdQuote;
      expect(quote.children.length, 1);
      expect((quote.children[0] as MdParagraph).text, contains('引用段落'));
    });

    test('围栏代码块', () {
      final blocks = MarkdownParser.parse('```dart\nvar x = 1;\n```');
      expect(blocks.length, 1);
      final fence = blocks[0] as MdCodeFence;
      expect(fence.language, 'dart');
      expect(fence.code, 'var x = 1;');
    });

    test('分隔线', () {
      final blocks = MarkdownParser.parse('段落\n\n---\n\n另一段');
      expect(blocks.length, 3);
      expect(blocks[1], isA<MdRule>());
    });

    test('表格', () {
      final blocks = MarkdownParser.parse('| A | B |\n|---|---|\n| 1 | 2 |');
      expect(blocks.length, 1);
      final table = blocks[0] as MdTable;
      expect(table.header, ['A', 'B']);
      expect(table.rows[0], ['1', '2']);
    });
  });

  group('边界：流式期半截文本', () {
    test('未闭合围栏 → 余下全当代码，不崩', () {
      expect(() => MarkdownParser.parse('```dart\nvar x = 1;\n段落'), returnsNormally);
      final blocks = MarkdownParser.parse('```dart\nvar x = 1;\n段落');
      expect(blocks.length, 1);
      expect(blocks[0], isA<MdCodeFence>());
      expect((blocks[0] as MdCodeFence).code, contains('段落'));
    });

    test('连续 80 个星号 → 不退化成 O(n²)', () {
      final s = '*' * 80;
      expect(() => MarkdownParser.parse(s), returnsNormally);
    });

    test('伪表格(只有竖线) → 当段落', () {
      final blocks = MarkdownParser.parse('a | b | c');
      expect(blocks[0], isA<MdParagraph>());
    });

    test('CRLF → 统一成 LF', () {
      final blocks = MarkdownParser.parse('段落一\r\n\r\n段落二');
      expect(blocks.length, 2);
    });

    test('列表嵌套过深 → 封顶不崩', () {
      final deep = '  ' * 10 + '- 深层项';
      expect(() => MarkdownParser.parse(deep), returnsNormally);
    });
  });

  group('MarkdownInline', () {
    test('纯文本', () {
      final inlines = MarkdownInlineParser.parse('plain text');
      expect(inlines.length, 1);
      expect(inlines[0].kind, MdInlineKind.text);
      expect(inlines[0].text, 'plain text');
    });

    test('行内代码', () {
      final inlines = MarkdownInlineParser.parse('代码 `var x = 1;` 文本');
      expect(inlines.length, 3);
      expect(inlines[1].kind, MdInlineKind.code);
      expect(inlines[1].text, 'var x = 1;');
    });

    test('粗体', () {
      final inlines = MarkdownInlineParser.parse('普通 **粗体** 普通');
      expect(inlines.length, 3);
      expect(inlines[1].kind, MdInlineKind.bold);
      final children = inlines[1].children!;
      expect(children[0].text, '粗体');
    });

    test('斜体', () {
      final inlines = MarkdownInlineParser.parse('普通 *斜体* 普通');
      expect(inlines.length, 3);
      expect(inlines[1].kind, MdInlineKind.italic);
    });

    test('粗斜体', () {
      final inlines = MarkdownInlineParser.parse('***粗斜体***');
      expect(inlines.length, 1);
      expect(inlines[0].kind, MdInlineKind.boldItalic);
    });

    test('删除线', () {
      final inlines = MarkdownInlineParser.parse('~~删除~~');
      expect(inlines.length, 1);
      expect(inlines[0].kind, MdInlineKind.strikethrough);
    });

    test('链接', () {
      final inlines = MarkdownInlineParser.parse('[显示文字](https://example.com)');
      expect(inlines.length, 1);
      expect(inlines[0].kind, MdInlineKind.link);
      expect(inlines[0].text, '显示文字');
      expect(inlines[0].href, 'https://example.com');
    });

    test('转义', () {
      final inlines = MarkdownInlineParser.parse(r'\*不是斜体\*');
      expect(inlines.length, 1);
      expect(inlines[0].text, '*不是斜体*');
    });

    test('未闭合粗体 → 按字面量', () {
      final inlines = MarkdownInlineParser.parse('**未闭合');
      expect(inlines.length, 1);
      expect(inlines[0].kind, MdInlineKind.text);
      expect(inlines[0].text, contains('**'));
    });

    test('snake_case 不被当成斜体', () {
      final inlines = MarkdownInlineParser.parse('变量 user_name 是标识符');
      expect(inlines.every((n) => n.kind == MdInlineKind.text), true);
    });

    test('嵌套：粗体里有代码', () {
      final inlines = MarkdownInlineParser.parse('**粗体 `code` 粗体**');
      expect(inlines.length, 1);
      expect(inlines[0].kind, MdInlineKind.bold);
      final children = inlines[0].children!;
      expect(children.length, 3);
      expect(children[1].kind, MdInlineKind.code);
    });
  });

  group('增量解析偏移', () {
    test('offsetBias 正确传播', () {
      final blocks = MarkdownParser.parse('段落', offsetBias: 100);
      expect(blocks[0].sourceStart, 100);
      expect(blocks[0].sourceEnd, greaterThan(100));
    });

    test('规范化前缀判定的前提', () {
      final n = MarkdownParser.normalize('a\r\nb');
      expect(n, 'a\nb');
      expect(n.contains('\r'), false);
    });
  });
}
