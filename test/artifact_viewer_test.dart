import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/chat/artifact/artifact_viewer.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/markdown_view.dart';

/// 产物检视器测试 —— 按类型走不同渲染分支。
///
/// 守住的约束：**什么形态用什么渲染器**。文档走 Markdown、图表尽量画成图、
/// 认不出就退回原文并明说，绝不能悄悄把 YAML 的 `# 注释` 渲染成标题。
void main() {
  Widget harness(ChatArtifact artifact) => MaterialApp(
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
          body: ArtifactViewer(artifact: artifact),
        ),
      );

  group('code 分支：等宽原文', () {
    testWidgets('渲染为可选中文本，内容完整', (tester) async {
      await tester.pumpWidget(harness(const ChatArtifact(
        title: 'config',
        language: 'yaml',
        content: 'replicas: 2',
        kind: ArtifactKind.code,
      )));

      // 正文是普通 [Text]，选区由面板的 `SelectionArea` 统一提供。
      final text = tester.widget<Text>(find.byType(Text).first);
      expect(text.data, contains('replicas: 2'));
    });

    testWidgets('YAML 的 # 注释不变成标题（不能走 Markdown 渲染）', (tester) async {
      await tester.pumpWidget(harness(const ChatArtifact(
        title: 'config',
        language: 'yaml',
        content: '# 部署配置\nreplicas: 2',
        kind: ArtifactKind.code,
      )));

      expect(find.byType(MarkdownView), findsNothing,
          reason: '结构化数据一律等宽，不解析 markdown');
    });
  });

  group('document 分支：Markdown 渲染', () {
    testWidgets('走 MarkdownView —— 与聊天里同一套渲染', (tester) async {
      await tester.pumpWidget(harness(const ChatArtifact(
        title: '需求文档',
        language: 'md',
        content: '# 标题\n\n正文段落',
        kind: ArtifactKind.document,
      )));

      expect(find.byType(MarkdownView), findsOneWidget);
    });

    testWidgets('markdown 语法真的被解析（星号不露面）', (tester) async {
      await tester.pumpWidget(harness(const ChatArtifact(
        title: 'doc',
        language: 'md',
        content: '**加粗**',
        kind: ArtifactKind.document,
      )));

      final text = tester.widget<Text>(find.byType(Text).first);
      expect(text.textSpan?.toPlainText(), '加粗');
    });
  });

  group('chart 分支：尽量画成图', () {
    testWidgets('可解析的流程图 → 画出来，不是原文', (tester) async {
      await tester.pumpWidget(harness(const ChatArtifact(
        title: '流程',
        language: 'mermaid',
        content: 'graph TD\nA[开始] --> B[结束]',
        kind: ArtifactKind.chart,
      )));

      expect(find.byType(CustomPaint), findsWidgets);
      // 画成图时不该再出现"无法渲染"的提示。
      expect(find.textContaining('无法以图形方式渲染'), findsNothing);
    });

    testWidgets('认不出的图表描述 → 退回原文，并明说这是原文', (tester) async {
      await tester.pumpWidget(harness(const ChatArtifact(
        title: '流程',
        language: 'mermaid',
        content: 'sequenceDiagram\n  A->>B: 你好',
        kind: ArtifactKind.chart,
      )));

      expect(find.textContaining('无法以图形方式渲染'), findsOneWidget,
          reason: '必须告诉用户这是原文，否则会以为渲染坏了');
      // 第一处 Text 是那条提示，原文在它下面。
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .any((t) => t.data?.contains('sequenceDiagram') ?? false),
        isTrue,
      );
    });

    testWidgets('mermaid 内容为空 → 不抛异常', (tester) async {
      await tester.pumpWidget(harness(const ChatArtifact(
        title: '空图',
        language: 'mermaid',
        content: '',
        kind: ArtifactKind.chart,
      )));

      expect(tester.takeException(), isNull);
    });
  });

  group('tool 分支：结构化展示', () {
    testWidgets('JSON 对象 → 按键值展开', (tester) async {
      await tester.pumpWidget(harness(const ChatArtifact(
        title: 'shell',
        language: 'shell',
        content: '{"exit_code": 0, "stdout": "ok"}',
        kind: ArtifactKind.tool,
      )));

      final widget = tester.widget<Text>(find.byType(Text).first);
      final text = widget.textSpan?.toPlainText() ?? widget.data ?? '';
      expect(text, contains('exit_code'));
      expect(text, contains('stdout'));
    });

    testWidgets('纯文本工具输出 → 原样等宽显示，不抛异常', (tester) async {
      await tester.pumpWidget(harness(const ChatArtifact(
        title: 'shell',
        language: 'shell',
        content: 'total 12\ndrwxr-xr-x 2 user user 4096 .',
        kind: ArtifactKind.tool,
      )));

      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.byType(Text).first);
      expect(text.data, contains('drwxr-xr-x'));
    });

    testWidgets('纯数字文本不被当 JSON 美化（会变失真）', (tester) async {
      await tester.pumpWidget(harness(const ChatArtifact(
        title: 'shell',
        language: 'shell',
        content: '42',
        kind: ArtifactKind.tool,
      )));

      final text = tester.widget<Text>(find.byType(Text).first);
      expect(text.data, '42');
    });
  });

  group('切换产物', () {
    testWidgets('从 code 换到 document 不抛异常', (tester) async {
      await tester.pumpWidget(harness(const ChatArtifact(
        title: 'a',
        language: 'dart',
        content: 'var x = 1;',
        kind: ArtifactKind.code,
      )));

      await tester.pumpWidget(harness(const ChatArtifact(
        title: 'b',
        language: 'md',
        content: '# 标题',
        kind: ArtifactKind.document,
      )));

      expect(tester.takeException(), isNull);
      expect(find.byType(MarkdownView), findsOneWidget);
    });
  });
}
