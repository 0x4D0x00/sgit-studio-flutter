import 'dart:convert';

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
import 'package:sgit_studio_flutter/ui/components/chat/text_bubble.dart';

/// 气泡**形态**的回归测试 —— 用户是实心灰气泡，助手是完全没有框的纯文字。
///
/// 之所以单开一份而不是并进 `chat_ui_test.dart`：那份走的是「mock 内核 → 真控制器
/// → 真 UI」的端到端链路，是**行为**测试；这里只关心两种角色的**视觉形态**，
/// 直接摆一个 `TextBubble` 就够，不必拖起整条链路。
///
/// 钉在这里的是四件容易在后续改动中被悄悄改回去的事：
/// ① 助手回复没有气泡框；② 用户气泡底色走 `bubbleUserBg` 令牌；
/// ③ 助手回复不受用户气泡的 680 宽度上限约束（否则设置页的「转录宽度」对它失效）；
/// ④ 品牌头像只在**最后一条**回答的末尾出现一次，且**在其下方**，不是每条回复的左上方。
void main() {
  /// 1×1 透明 PNG。头像只关心「有没有按尺寸摆出来」，不关心画的是什么。
  final avatar = MemoryImage(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
    'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  ));

  Widget harness(TextItem item, {bool isLastAnswer = false}) => ProviderScope(
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
              isLastAnswer: isLastAnswer,
            ),
          ),
        ),
      );

  testWidgets('助手回复：完全没有气泡框，也不受用户气泡的宽度上限约束', (tester) async {
    await tester.pumpWidget(harness(
      TextItem(id: 1, role: ChatRole.assistant, initial: '防护助理的主要作用是什么'),
      isLastAnswer: true,
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

    // ③ 头像按令牌尺寸摆出来了。
    expect(
      find.descendant(
        of: find.byType(TextBubble),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
  });

  testWidgets('品牌头像只挂在最后一组回答的末尾，且落在正文下方', (tester) async {
    final item =
        TextItem(id: 3, role: ChatRole.assistant, initial: '这条回复到这儿就结束了');

    // ① 结尾那条：有头像，且**在正文下方**（不是像以前那样挂在左边）。
    await tester.pumpWidget(harness(item, isLastAnswer: true));
    final textBottom = tester.getBottomLeft(find.byType(SelectableText)).dy;
    final avatarRect = tester.getRect(find.byType(Image));
    expect(avatarRect.top, greaterThanOrEqualTo(textBottom));
    // 与正文同一列首，不居中、不右靠。
    expect(avatarRect.left,
        moreOrLessEquals(tester.getTopLeft(find.byType(SelectableText)).dx,
            epsilon: 1));
    expect(avatarRect.width, ChatBubbleMetrics.avatarSize);

    // ② 非结尾那条：一个头像都不该有 —— 这条守住「别再每条回复都挂一枚」。
    await tester.pumpWidget(harness(item));
    expect(find.byType(Image), findsNothing);
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
