import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/design/tokens/bubble_metrics.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/code_block_card.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/horizontal_scroll_area.dart';

/// 守住的约束（对应"代码块/表格要能看出可以右滑"这个需求）：
/// - 超出列宽时，正文下方**确实**有一道滑块；
/// - 装得下时**不**垫那道底部空带（否则每个短代码块底下都白多一道缝）；
/// - 未溢出 / 已溢出两种情况下，整棵树都不抛异常。
void main() {
  Widget wrap(Widget child, {double width = 360}) => MaterialApp(
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
          body: Center(child: SizedBox(width: width, child: child)),
        ),
      );

  /// 取 [HorizontalScrollArea] 里那个横向滚动视图的 padding.bottom。
  double bottomGutter(WidgetTester tester) => tester
      .widget<SingleChildScrollView>(find.descendant(
        of: find.byType(HorizontalScrollArea),
        matching: find.byType(SingleChildScrollView),
      ))
      .padding!
      .resolve(TextDirection.ltr)
      .bottom;

  /// 走到"指标通知已派发、空带已按需垫好"的稳定态。
  ///
  /// ⚠️ ⚠️ 那则通知是**帧结束后由 microtask 发出**的（SDK 在
  /// `ScrollPosition.applyContentDimensions` 里 `scheduleMicrotask`），
  /// 所以 `pump()` 一帧还看不到结果 —— `pumpAndSettle` 也不够，它等的是动画不是
  /// 微任务。必须 `pump()` 把帧走完、再 `pump()` 收那则通知引发的 setState。
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  group('HorizontalScrollArea', () {
    testWidgets('内容超出 → 正文下方垫出空带，且滑块存在', (tester) async {
      await tester.pumpWidget(wrap(
        // 超长单行：宽 360 的容器里必然溢出。
        const HorizontalScrollArea(
          child: SizedBox(width: 2000, child: Text('x')),
        ),
      ));
      await settle(tester);

      expect(bottomGutter(tester), ChatBubbleMetrics.hScrollGutter,
          reason: '溢出了就该给滑条腾地方');
      expect(find.byType(RawScrollbar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('内容装得下 → 不垫空带（短代码块底下不该多出一道缝）', (tester) async {
      await tester.pumpWidget(wrap(
        const HorizontalScrollArea(
          child: SizedBox(width: 100, child: Text('短')),
        ),
      ));
      await settle(tester);

      expect(bottomGutter(tester), 0,
          reason: '没溢出就不许垫 —— 否则每个短块底下常年一道白');
      expect(tester.takeException(), isNull);
    });

    testWidgets('从溢出切到不溢出 → 空带收回去', (tester) async {
      await tester.pumpWidget(wrap(
        const HorizontalScrollArea(
          child: SizedBox(width: 2000, child: Text('x')),
        ),
      ));
      await settle(tester);
      expect(bottomGutter(tester), ChatBubbleMetrics.hScrollGutter);

      // 换成短内容 —— 走的是"同一棵树换 child"的路径，不是重新挂载。
      await tester.pumpWidget(wrap(
        const HorizontalScrollArea(
          child: SizedBox(width: 100, child: Text('短')),
        ),
      ));
      await settle(tester);

      expect(bottomGutter(tester), 0, reason: '内容改短后空带必须收回去');
      expect(tester.takeException(), isNull);
    });
  });

  group('接入点', () {
    testWidgets('代码块：长行 → 底部有空带 + 滑块', (tester) async {
      await tester.pumpWidget(wrap(
        const CodeBlockCard(
          code: 'curl https://example.com/api/v1/very/long/path?a=1&b=2&c=3',
          language: 'bash',
        ),
      ));
      await settle(tester);

      expect(
        find.descendant(
          of: find.byType(CodeBlockCard),
          matching: find.byType(HorizontalScrollArea),
        ),
        findsOneWidget,
        reason: '代码块必须走这个组件，否则长行被裁掉时没有任何提示',
      );
      expect(tester.takeException(), isNull);
    });
  });
}
