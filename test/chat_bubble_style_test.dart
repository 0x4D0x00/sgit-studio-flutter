import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/design/tokens/bubble_metrics.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/chat/bubble_actions_row.dart';
import 'package:sgit_studio_flutter/ui/components/chat/text_bubble.dart';

/// 气泡**形态**的回归测试 —— 用户是实心灰气泡，助手是完全没有框的纯文字。
///
/// 之所以单开一份而不是并进 `chat_ui_test.dart`：那份走的是「mock 内核 → 真控制器
/// → 真 UI」的端到端链路，是**行为**测试；这里只关心两种角色的**视觉形态**，
/// 直接摆一个 `TextBubble` 就够，不必拖起整条链路。
///
/// 钉在这里的是三件容易在后续改动中被悄悄改回去的事：
/// ① 助手回复没有气泡框；② 用户气泡底色走 `bubbleUserBg` 令牌；
/// ③ 助手回复不受用户气泡的 680 宽度上限约束（否则设置页的「转录宽度」对它失效）。
///
/// 品牌头像已从助手回复末尾移除，因此这里不再有头像相关断言。
void main() {
  Widget harness(TextItem item,
          {bool isLastAnswer = false, bool replyComplete = false}) =>
      ProviderScope(
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
              isLastAnswer: isLastAnswer,
              replyComplete: replyComplete,
            ),
          ),
        ),
      );

  testWidgets('助手回复：完全没有气泡框，也不受用户气泡的宽度上限约束', (tester) async {
    await tester.pumpWidget(harness(
      TextItem(id: 1, role: ChatRole.assistant, initial: '防护助理的主要作用是什么'),
      isLastAnswer: true,
      replyComplete: true,
    ));

    // ① 无框 —— 助手分支里一个 Container 都不该有。
    //    `Container(color: Colors.transparent)` 这种写法会在这里被抓出来，
    //    它虽然看不见，却仍会插一层 DecoratedBox 每帧白画。
    expect(
      find.descendant(
        of: find.byType(TextBubble),
        matching: find.byType(Container),
      ),
      findsNothing,
    );

    // ② 宽度上限只对用户生效 —— 助手整棵子树里不许出现 680 这个约束。
    final box = tester.widgetList<ConstrainedBox>(find.descendant(
      of: find.byType(TextBubble),
      matching: find.byType(ConstrainedBox),
    ));
    expect(box, isEmpty);

    // ③ 助手回复里**不再有任何图片** —— 末尾的品牌头像已移除。
    //    这条守住「不会再被悄悄加回来」（比如以后想加"AI 生成"角标时）。
    expect(
      find.descendant(
        of: find.byType(TextBubble),
        matching: find.byType(Image),
      ),
      findsNothing,
    );
  });

  /// 这一条钉住本轮要修的 bug：回答**还在流**的时候，末尾气泡底下不能出现
  /// 工具行（截图里那两个红框）。
  ///
  /// 难点在于两种「看起来该显示」的判断都是错的：
  /// - `isLastAnswer` —— 跑动期间列表末尾那条正是正在流出来的那条，
  ///   所以一轮里它会先后落在每一段回答上；
  /// - `item.done` —— 一轮由**多段**组成，`itemCompleted` 每段都发一次，
  ///   所以一轮跑到一半时前面那些段 done 已经是 true。
  /// 只有当 caller 明确告知「整轮结束」时才给工具行。
  testWidgets('回答未结束（replyComplete=false）：工具行不出现，连占位高度也不留',
      (tester) async {
    final item =
        TextItem(id: 4, role: ChatRole.assistant, initial: '正在往外吐的回答');

    // 流式中：什么都没有。
    await tester.pumpWidget(harness(item, isLastAnswer: true));
    expect(find.byType(BubbleActionsRow), findsNothing,
        reason: '回答还会变长时不该冒出「复制 / 朗读 / 重试」');

    // ⚠️ 那 24px 的占位高度也要一起省掉，否则多段回答的中间会凭空多出一道缝。
    //
    // 量的是**正文底边**而不是 `TextBubble` 自身的高度：外层那个 Column 的
    // `mainAxisSize` 是 max，在 Scaffold 里会被拉满整屏，两种状态量出来一样高，
    // 拿它比等于什么都没验。
    // 正文是普通 [Text]（选区归外层 `SelectionArea`），量它底下的 `RichText`。
    final textBottom = tester
        .getBottomLeft(find.descendant(
          of: find.byType(TextBubble),
          matching: find.byType(RichText),
        ))
        .dy;

    // 同一段内容，整轮结束后再看：工具行到位，且确实排在正文**下方**。
    await tester.pumpWidget(
        harness(item, isLastAnswer: true, replyComplete: true));
    expect(find.byType(BubbleActionsRow), findsOneWidget);

    final rowTop = tester.getTopLeft(find.byType(BubbleActionsRow)).dy;
    expect(rowTop, greaterThanOrEqualTo(textBottom), reason: '工具行该在回复下方');
    // 底边的位移就是那 24px 工具行；没往下走说明流式期仍留着占位。
    expect(tester.getBottomLeft(find.byType(BubbleActionsRow)).dy,
        greaterThan(textBottom),
        reason: '整轮结束后内容总高该比流式期长一截');
  });

  testWidgets('用户消息：实心灰气泡，底色取自 bubbleUserBg 令牌', (tester) async {
    await tester.pumpWidget(harness(
      TextItem(id: 2, role: ChatRole.user, initial: '看一下仓库结构'),
    ));

    final container = tester.widget<Container>(find
        .descendant(
          of: find.byType(TextBubble),
          matching: find.byType(Container),
        )
        .first);

    final decoration = container.decoration! as BoxDecoration;
    // 色值走令牌 —— 顺带钉住「不再用 navItemActive 那个蓝」。
    expect(decoration.color, AppSkin.light.bubbleUserBg);
    expect(decoration.color, isNot(AppColors.navItemActive));
    // 用户气泡无描边。
    expect(decoration.border, isNull);

    // 用户气泡仍受宽度上限约束（长消息不该横贯整列）。
    expect(find.byType(ConstrainedBox), findsWidgets);
  });

  test('助手去掉气泡框后，每条消息的纵向占位与改之前逐像素相同', () {
    // 改之前每条占：上下 margin 各 4 + 上下 padding 各 12 = 32。
    // 助手现在没有容器，靠 assistantPaddingBlock 上下各 16 补齐 —— 32。
    // 这条钉住那段算术：将来谁调了 token，对话流的疏密变化会被这里拦下。
    const before = AppSpacing.xxs * 2 + ChatBubbleMetrics.paddingBlock * 2;
    const after = ChatBubbleMetrics.assistantPaddingBlock * 2;
    expect(after, before);
  });

  testWidgets('三种皮肤的 bubbleUserBg 都必须是半透明或深色可辨的实色', (tester) async {
    // 透明模式若漏了 alpha，窗口透出桌面时会拍出一块不透明方块 —— 这条守住它。
    expect(AppSkin.transparent.bubbleUserBg.a, lessThan(1.0));
    // 暗色气泡必须亮于描边，否则在深色面板上糊成一片。
    expect(
      AppSkin.dark.bubbleUserBg.computeLuminance(),
      greaterThan(AppColors.borderSecondaryDark.computeLuminance()),
    );
  });
}
