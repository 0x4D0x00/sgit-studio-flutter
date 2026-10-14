import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/markdown_view_cache.dart';
import 'package:sgit_studio_flutter/ui/components/chat/text_bubble.dart';

/// Markdown 渲染测试 —— pump `TextBubble` 喂 markdown，断言产出的 widget 树。
///
/// 守住的约束：
/// - 纯段落 → 恰好一个 selectable 控件，零 Container
/// - 代码块出现时才有 Container
/// - 加粗 → `fontWeight.w700` 的 TextSpan
/// - 未闭合围栏不抛异常
void main() {
  /// 1×1 透明 PNG。
  final avatar = MemoryImage(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  ));

  Widget harness(TextItem item) => ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(
            primary: AppColors.defaultPrimary,
            secondary: AppColors.defaultSecondary,
          ),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TextBubble(
              item: item,
              truncatedHint: '内容可能不完整',
              assistantAvatar: avatar,
            ),
          ),
        ),
      );

  group('助手回复 markdown 渲染', () {
    testWidgets('纯段落 → 一个 selectable、零 Container', (tester) async {
      await tester.pumpWidget(harness(
        TextItem(id: 1, role: ChatRole.assistant, initial: '纯文本段落'),
      ));

      // 纯段落必须满足"零 Container"约束，否则 chat_bubble_style_test.dart 会红。
      expect(
        find.descendant(
          of: find.byType(TextBubble),
          matching: find.byType(Container),
        ),
        findsNothing,
      );

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('代码块 → 出现 Container', (tester) async {
      await tester.pumpWidget(harness(
        TextItem(id: 2, role: ChatRole.assistant, initial: '```dart\nvar x = 1;\n```'),
      ));

      // 代码块需要 Container(圆角+底+描边)，这时可以有。
      expect(
        find.descendant(
          of: find.byType(TextBubble),
          matching: find.byType(Container),
        ),
        findsWidgets,
      );
    });

    testWidgets('加粗 → TextSpan 有 fontWeight.w700', (tester) async {
      await tester.pumpWidget(harness(
        TextItem(id: 3, role: ChatRole.assistant, initial: '普通 **粗体** 普通'),
      ));

      // 找到 SelectableText，提取它的 TextSpan 树，验证其中有 w700。
      final selectable = tester.widget<SelectableText>(find.byType(SelectableText).first);
      final spans = _flattenSpans(selectable.textSpan!);
      final hasBold = spans.any((s) => s.style?.fontWeight == FontWeight.w700);
      expect(hasBold, true);
    });

    testWidgets('未闭合围栏 → 不抛异常', (tester) async {
      expect(
        () async => await tester.pumpWidget(harness(
          TextItem(id: 4, role: ChatRole.assistant, initial: '```dart\nvar x = 1;'),
        )),
        returnsNormally,
      );
    });

    testWidgets('列表渲染 → 不崩', (tester) async {
      await tester.pumpWidget(harness(
        TextItem(id: 5, role: ChatRole.assistant, initial: '- 项一\n- 项二\n- 项三'),
      ));

      expect(find.byType(TextBubble), findsOneWidget);
    });

    testWidgets('引用块 → 有 Container(竖条)', (tester) async {
      await tester.pumpWidget(harness(
        TextItem(id: 6, role: ChatRole.assistant, initial: '> 引用段落'),
      ));

      // 引用块的竖条也是 Container。
      expect(
        find.descendant(
          of: find.byType(TextBubble),
          matching: find.byType(Container),
        ),
        findsWidgets,
      );
    });
  });

  group('用户消息维持纯文本', () {
    testWidgets('用户消息不走 markdown', (tester) async {
      await tester.pumpWidget(harness(
        TextItem(id: 7, role: ChatRole.user, initial: '**不加粗**'),
      ));

      final selectable = tester.widget<SelectableText>(find.byType(SelectableText).first);
      // 用户消息是纯文本，不解析成 TextSpan 树，直接是一个 text。
      expect(selectable.data, '**不加粗**');
    });
  });

  // ---- 流式增量缓存 ----
  //
  // 这是整个设计性能论证的核心：追加一个 delta 时，**前面已封口的块必须
  // identity 不变**，否则每帧全量重建，长回答直接掉帧（KERNEL_FFI §8 的
  // `1000 delta → <60 帧` 预算）。这几条把它钉死。

  group('MarkdownViewCache 增量复用', () {
    test('追加 delta → 前面已封口的块 identity 不变', () {
      final cache = MarkdownViewCache();

      final first = cache.parse('第一段。\n\n第二段');
      expect(first.length, 2);

      // 模拟流式：往末尾追加字符。
      final second = cache.parse('第一段。\n\n第二段继续');
      expect(second.length, 2, reason: '追加不该凭空多出块');
      expect(identical(second[0], first[0]), true,
          reason: '第一段已封口，必须复用同一个对象，否则每帧重建整棵子树');
      expect(identical(second[1], first[1]), false,
          reason: '最后一块长大了，必须重新解析');
    });

    test('新增一个块 → 第一块仍复用，锚点块(原最后一块)重解析', () {
      final cache = MarkdownViewCache();
      final first = cache.parse('段落一\n\n段落二');
      final second = cache.parse('段落一\n\n段落二\n\n段落三');

      expect(second.length, 3);
      expect(identical(second[0], first[0]), true,
          reason: '第一块离锚点最远，必须复用');
      // ⚠️ 第二块**会**重解析 —— 它是上次的最后一块，也就是本次续解析的锚点。
      // 这是我们买来的代价：不知道它是否已封口，只能连它一起重算。
      // 换来的是每帧 O(最后一块) 而不是 O(全文)。
      expect(identical(second[1], first[1]), false);
    });

    test('非前缀文本(编辑/重发) → 全量重解析', () {
      final cache = MarkdownViewCache();
      final first = cache.parse('原始内容');
      final second = cache.parse('完全不同的内容');

      expect(second.length, 1);
      expect(identical(second[0], first[0]), false);
    });

    test('含 CR 的文本 → 走全量，不按偏移切片', () {
      final cache = MarkdownViewCache();
      cache.parse('第一段\n\n第二段');
      // `\r` 会破坏偏移基准，必须走全量分支。
      expect(() => cache.parse('第一段\r\n\r\n第二段改'), returnsNormally);
    });

    test('逐字追加整段 → 不抛异常', () {
      const full = '**粗体** 与 `代码`\n\n- 列表项\n\n```dart\nvar x = 1;\n```';
      final cache = MarkdownViewCache();
      for (var i = 1; i <= full.length; i++) {
        expect(() => cache.parse(full.substring(0, i)), returnsNormally,
            reason: '流式第 $i 个字符时崩了');
      }
      expect(cache.parse(full).length, greaterThanOrEqualTo(3));
    });
  });
}

/// 把 TextSpan 树压平成列表。
List<TextSpan> _flattenSpans(InlineSpan span) {
  final out = <TextSpan>[];
  if (span is TextSpan) {
    out.add(span);
    final children = span.children;
    if (children != null) {
      for (final c in children) {
        out.addAll(_flattenSpans(c));
      }
    }
  }
  return out;
}
