import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/chat/artifact_chip.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/markdown_image.dart';
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

      // ⚠️ 正文一律是普通 [Text]。`SelectableText` 自带一套选区，会把
      // Ctrl+A 锁在"当前这一段"里 —— 见 `ChatTranscript` 里的 SelectionArea。
      expect(
        find.descendant(
          of: find.byType(TextBubble),
          matching: find.byType(SelectableText),
        ),
        findsNothing,
        reason: '正文不能自带选区，否则无法整块全选',
      );
      expect(
        find.descendant(
          of: find.byType(TextBubble),
          matching: find.byType(RichText),
        ),
        findsOneWidget,
      );
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

    // ⚠️ 阈值把围栏分成两种呈现，这是本次改动的核心：
    //   短块 = 正文里普通代码块（读得完，不配文件卡）；
    //   长块 = 只画文件卡，正文移出聊天（进右侧面板）。
    testWidgets('短代码块 → 内联代码正文，不出现文件卡', (tester) async {
      await tester.pumpWidget(harness(TextItem(
        id: 20,
        role: ChatRole.assistant,
        initial: '```bash\nnuclei -u target -rl 5\n```',
      )));

      expect(find.byType(ArtifactChip), findsNothing,
          reason: '短块不该变成"文件"');
      // 正文内联可见。
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .any((s) => s.data?.contains('nuclei') ?? false),
        isTrue,
        reason: '短块的命令要能直接在聊天里读到',
      );
    });

    testWidgets('长代码块（>30 行）→ 只画文件卡，正文不在聊天里', (tester) async {
      final body = List.generate(45, (i) => 'var x$i = $i;').join('\n');
      await tester.pumpWidget(harness(TextItem(
        id: 21,
        role: ChatRole.assistant,
        initial: '待办清单示例\n\n```dart\n$body\n```',
      )));

      expect(find.byType(ArtifactChip), findsOneWidget,
          reason: '长块应该就地变成一张文件卡');
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .any((s) => s.data?.contains('var x40') ?? false),
        isFalse,
        reason: '长块正文必须移出聊天，只留在右侧面板',
      );
    });

    testWidgets('同一回答里长短混杂 → 短块内联、长块出卡，互不干扰', (tester) async {
      final long = List.generate(40, (i) => 'line $i').join('\n');
      await tester.pumpWidget(harness(TextItem(
        id: 22,
        role: ChatRole.assistant,
        initial: '用法\n\n```bash\nnuclei -u target\n```\n\n实现\n\n```dart\n$long\n```',
      )));

      expect(find.byType(ArtifactChip), findsOneWidget);
      // 短的 bash 命令仍可读。
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .any((s) => s.data?.contains('nuclei') ?? false),
        isTrue,
      );
    });

    testWidgets('长块流式生成中 → 不抛异常', (tester) async {
      // ⚠️ 把测试窗口调高。长块在**长到 30 行之前**仍是内联代码块，
      //    `TextBubble` 自己不滚动（真实场景由外层 ListView 滚），
      //    默认 800×600 会因内容超高报 RenderFlex overflow ——
      //    那是"窗口太小"，不是渲染崩了。
      tester.view.physicalSize = const Size(1200, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final item = TextItem(id: 23, role: ChatRole.assistant);
      await tester.pumpWidget(harness(item));

      final body = '```dart\n${List.generate(45, (i) => 'var x$i = $i;').join('\n')}\n```';
      for (var i = 1; i <= body.length; i += 7) {
        final from = i - 7 < 0 ? 0 : i - 7;
        item.append(body.substring(from, i));
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: '流式第 $i 个字符时崩了');
      }

      // 写完应有产物并渲染成文件卡。
      expect(find.byType(ArtifactChip), findsOneWidget);
    });

    testWidgets('加粗 → TextSpan 有 fontWeight.w700', (tester) async {
      await tester.pumpWidget(harness(
        TextItem(id: 3, role: ChatRole.assistant, initial: '普通 **粗体** 普通'),
      ));

      // 找到正文 RichText，提取它的 TextSpan 树，验证其中有 w700。
      final spans = _flattenSpans(_firstRichTextSpan(tester));
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

    testWidgets('最终回复截图 ![alt](本地路径) → MarkdownImage,文件缺失不崩', (tester) async {
      await tester.pumpWidget(harness(TextItem(
        id: 31,
        role: ChatRole.assistant,
        initial: '完成。\n\n![记事本截图](C:/__sgit_missing__/shot.jpg)',
      )));
      await tester.pump();

      expect(find.byType(MarkdownImage), findsOneWidget);
      expect(tester.takeException(), isNull);
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

    // ⚠️ 表格单元格必须走行内 markdown。真实 bug：模型在表格里写
    // `**办公助理**`，渲染出来是带星号的字面量 —— 因为单元格当初直接
    // `Text(cell)`，绕过了 MarkdownInlineParser。
    testWidgets('表格单元格 → 行内 markdown 生效，星号不露面', (tester) async {
      await tester.pumpWidget(harness(TextItem(
        id: 8,
        role: ChatRole.assistant,
        initial: '| 助理类型 | 说明 |\n| --- | --- |\n| **办公助理** | 办公 |',
      )));

      final cells = _cellTexts(tester);
      expect(cells, contains('办公助理'), reason: '星号必须被解析掉');
      expect(cells, isNot(contains('**办公助理**')));

      // 加粗要真的落在样式上，而不只是把定界符删掉。
      final richTexts = tester.widgetList<RichText>(find.descendant(
        of: find.byType(TextBubble),
        matching: find.byType(RichText),
      ));
      final hasBold = richTexts
          .any((t) => _flattenSpans(t.text).any(
              (sp) => sp.style?.fontWeight == FontWeight.w700));
      expect(hasBold, true);
    });

    // ⚠️ 真实报错：表格流式生成中途红色错误屏。原因是半截行（比如刚打到 `|`）
    // 的格数与表头对不上，Flutter 的 Table 直接 assert 崩。解析器补齐后，
    // 从第一个字符到整表写完，任何一帧都不能抛。
    testWidgets('表格逐字流式生成 → 全程不抛异常', (tester) async {
      const md = '| 助理类型 | 说明 |\n| --- | --- |\n| **办公助理** | 办公 |\n';
      final item = TextItem(id: 9, role: ChatRole.assistant);
      await tester.pumpWidget(harness(item));

      for (var i = 1; i <= md.length; i++) {
        item.append(md[i - 1]);
        await tester.pump();
        expect(tester.takeException(), isNull,
            reason: '流式第 $i 个字符（前缀 ${md.substring(0, i)}）时崩了');
      }
    });
  });

  group('用户消息维持纯文本', () {
    testWidgets('用户消息不走 markdown', (tester) async {
      await tester.pumpWidget(harness(
        TextItem(id: 7, role: ChatRole.user, initial: '**不加粗**'),
      ));

      final text = tester.widget<Text>(find.byType(Text).first);
      // 用户消息是纯文本，不解析成 TextSpan 树，直接是一个 data。
      expect(text.data, '**不加粗**');
      expect(text.textSpan, isNull);
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

/// 取出气泡里所有单元格的纯文本（含表头）。
///
/// 表格单元格是 [SelectableText]，段落也是 —— 这里按"是不是 `Table` 的后代"
/// 过滤，避免把段落文字也算进来。
List<String> _cellTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(
      of: find.byType(Table),
      matching: find.byType(Text),
    ))
    .map((t) => t.textSpan?.toPlainText() ?? t.data ?? '')
    .toList();

/// 取气泡里第一个正文 [RichText] 的 span。
///
/// 正文已经不再用 `SelectableText`（选区交给外层 `SelectionArea`），
/// 断言富文本样式时改看它底下那层 `RichText`。
InlineSpan _firstRichTextSpan(WidgetTester tester) => tester
    .widget<RichText>(find
        .descendant(
          of: find.byType(TextBubble),
          matching: find.byType(RichText),
        )
        .first)
    .text;

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
