import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_find.dart';
import 'package:sgit_studio_flutter/domain/models/find/find_matcher.dart';
import 'package:sgit_studio_flutter/features/find/application/find_controller.dart';
import 'package:sgit_studio_flutter/ui/components/find/find_highlight.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/layout/panels/models/nav_entry.dart';
import 'package:sgit_studio_flutter/layout/panels/nav_row.dart';

void main() {
  test('FindMatcher：不区分大小写、字面匹配、不重叠', () {
    expect(FindMatcher.count('Abc abc ABC', 'abc'), 3);
    expect(FindMatcher.count('a.b a+b', 'a.b'), 1);
    expect(FindMatcher.count('aaaa', 'aa'), 2);
    expect(FindMatcher.count('anything', ''), 0);
  });

  test('MarkdownFind 与高亮编号口径一致（含引用 / 表格 / 粗体）', () {
    const src = '翻译 **翻译** `翻译`\n\n> 引用里的翻译\n\n- 列表翻译\n\n'
        '| 翻译 | x |\n|---|---|\n| y | 翻译 |\n\n```\n翻译\n```';
    final blocks = MarkdownParser.parse(src);
    // 段落 3 + 引用 1 + 列表 1 + 表格 2；围栏不算。
    expect(MarkdownFind.countBlocks(blocks, '翻译'), 7);
  });

  test('FindHighlight：按序编号，当前匹配用深色', () {
    const colors = FindColors(match: Color(0x11000000), current: Color(0x99000000));
    final h = FindHighlight(query: 'a', start: 5, current: 6, colors: colors);
    final span = h.span('aXa', null);
    expect(h.next, 7);
    final hits = span.children!.whereType<TextSpan>().where((s) => s.text == 'a');
    expect(hits.map((s) => s.style!.backgroundColor), [colors.match, colors.current]);
  });

  test('FindController：上下翻页循环，匹配数变化时收拢 current', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(findControllerProvider.notifier);
    n.show();
    n.setNavCount(1);
    n.setTranscriptCount(2);
    n.setQuery('x');
    n.previous();
    expect(c.read(findControllerProvider).current, 2);
    n.next();
    expect(c.read(findControllerProvider).current, 0);
    n.setTranscriptCount(0);
    expect(c.read(findControllerProvider).current, 0);
  });

  testWidgets('左栏标题很长、匹配在会被省略号截掉的位置 → 仍显示出匹配', (tester) async {
    const label = '<quote> Chat模式的特点：单次对话里用户提出问题之后模型给出回答，这样的方式可以满足大部分需求';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(
          primary: AppColors.defaultPrimary,
          secondary: AppColors.defaultSecondary,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: FindScope(
              query: '可以',
              navCurrent: 0,
              transcriptCurrent: -1,
              child: NavRow(
                entry: const NavEntry(
                  id: 'a',
                  icon: Icons.chat_bubble_outline,
                  label: label,
                ),
                selected: false,
                menuOpen: false,
                onSelect: (_) {},
                onMenuOpenChanged: (_) {},
                isChatItem: true,
                findStart: 0,
              ),
            ),
          ),
        ),
      ),
    );
    final rich = tester.widget<RichText>(
      find.descendant(of: find.byType(NavRow), matching: find.byType(RichText)).last,
    );
    final text = rich.text.toPlainText();
    expect(text.startsWith('…'), isTrue, reason: '匹配离开头太远，要从它附近开始显示');
    expect(text, contains('可以'));
    expect(text.indexOf('可以'), lessThan(12), reason: '匹配必须落在省略号之前能看到的位置');
  });
}
