import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/panels/artifact_output_panel.dart';
import 'package:sgit_studio_flutter/ui/components/chat/artifact_chip.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/code_block_card.dart';

/// - 代码块卡片保持原样：语言标签 + 复制 + 正文，**没有**标题/下载。
/// - 回答末尾的产物文件卡片：图标 + 标题 + 类型 + 下载。
/// - 右侧面板顶栏：纯图标按钮，文字只在悬停时出现。
void main() {
  const artifact = ChatArtifact(
    title: 'Weak credentials login',
    language: 'yaml',
    content: 'username: admin',
    kind: ArtifactKind.code,
  );

  Widget wrap(Widget child) => MaterialApp(
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
        home: Scaffold(body: child),
      );

  group('代码块卡片（原样）', () {
    testWidgets('只有语言标签 + 复制 + 正文', (tester) async {
      await tester.pumpWidget(wrap(
        const CodeBlockCard(code: 'var x = 1;', language: 'dart'),
      ));

      expect(find.text('dart'), findsOneWidget);
      expect(find.byIcon(Icons.content_copy), findsOneWidget);
      expect(find.text('下载'), findsNothing);
      expect(find.byIcon(Icons.code), findsNothing);
      // 正文是普通 [Text]（选区归外层 `SelectionArea`）。语言标签也是 Text，
      // 所以按内容找那一块。
      expect(find.text('var x = 1;'), findsOneWidget);
    });
  });

  group('产物文件卡片', () {
    testWidgets('显示图标、标题、类型与下载', (tester) async {
      await tester.pumpWidget(wrap(ArtifactChip(
        artifact: artifact,
        downloadLabel: '下载',
        onTap: () {},
        onDownload: () {},
      )));

      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(find.text('Weak credentials login'), findsOneWidget);
      expect(find.text('YAML'), findsOneWidget);
      expect(find.text('下载'), findsOneWidget);
    });

    testWidgets('点卡片 → onTap；点下载 → 只触发 onDownload', (tester) async {
      var tapped = 0, downloaded = 0;
      await tester.pumpWidget(wrap(ArtifactChip(
        artifact: artifact,
        downloadLabel: '下载',
        onTap: () => tapped++,
        onDownload: () => downloaded++,
      )));

      await tester.tap(find.text('Weak credentials login'));
      expect(tapped, 1);

      await tester.tap(find.text('下载'));
      expect(downloaded, 1);
      expect(tapped, 1, reason: '点下载不该同时打开面板');
    });

    testWidgets('长标题单行省略，不溢出', (tester) async {
      await tester.pumpWidget(wrap(SizedBox(
        width: 360,
        child: ArtifactChip(
          artifact: ChatArtifact(
            title: '一个可以直接跑的待办清单示例，包含数据模型、状态管理、列表增删改、' * 3,
            language: 'dart',
            content: 'x',
            kind: ArtifactKind.code,
          ),
          downloadLabel: '下载',
          onTap: () {},
          onDownload: () {},
        ),
      )));

      expect(tester.takeException(), isNull);
    });
  });

  group('右侧面板顶栏', () {
    testWidgets('按钮是纯图标，文字不直接显示，悬停才出 tooltip', (tester) async {
      await tester.pumpWidget(wrap(ArtifactOutputPanel(
        artifact: artifact,
        copyLabel: '复制',
        downloadLabel: '下载',
        closeLabel: '关闭',
        onClose: () {},
        onCopy: () {},
        onDownload: () {},
        child: const SizedBox(),
      )));

      expect(find.text('复制'), findsNothing);
      expect(find.text('下载'), findsNothing);
      expect(find.text('关闭'), findsNothing);

      final gesture =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.byIcon(Icons.close)));
      await tester.pump(const Duration(milliseconds: 800));

      expect(find.text('关闭'), findsOneWidget);
    });
  });
}
