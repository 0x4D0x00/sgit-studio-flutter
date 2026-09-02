import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sgit_studio_flutter/core/storage/local_storage.dart';

import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_mock.dart';
import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/app_shell_container.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/pages/relay_page.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/pages/resource_list_page.dart';
import 'package:sgit_studio_flutter/features/studio/studio_page_specs.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:sgit_studio_flutter/features/workspace/presentation/pages/workspace_page.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';

/// 布局回归测试 —— 抓 `RenderBox was not laid out` 这类**只在真实渲染时才炸**的问题。
///
/// 逻辑测试全绿但页面白屏，就是因为没人在真实约束下 layout 过。这里在几个典型
/// 视口尺寸下把整个外壳 + 工作台渲染一遍，任何 layout 异常都会让测试失败。
void main() {
  // 设置页读主题/语言偏好，需要先起 LocalStorage（生产在 bootstrap 里 await 过）。
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  Widget app({Widget page = const WorkspacePage()}) => ProviderScope(
        overrides: [
          chatControllerProvider.overrideWith(
            () => ChatController(client: MockKernelClient()),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(
            primary: AppColors.defaultPrimary,
            secondary: AppColors.defaultSecondary,
          ),
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AppShellContainer(child: page),
        ),
      );

  /// 桌面宽屏 / 笔记本 / 窄屏（走 Drawer 分支）三档都要过。
  const sizes = <String, Size>{
    '宽屏 1920×1080': Size(1920, 1080),
    '笔记本 1366×768': Size(1366, 768),
    '窄屏 480×900': Size(480, 900),
  };

  sizes.forEach((label, size) {
    testWidgets('工作台在 $label 下能正常 layout', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app());
      await tester.pump();

      // pumpWidget 会把 layout 异常记进 takeException；有就是布局炸了。
      expect(tester.takeException(), isNull, reason: '$label 下布局抛异常');
    });
  });

  testWidgets('故障条 + 建连进度条同时出现时也能 layout', (tester) async {
    tester.view
      ..physicalSize = const Size(1366, 768)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await tester.pump();

    // 触发"未连接就发送" → 故障条 + 自动重连的进度条同屏。
    final container =
        ProviderScope.containerOf(tester.element(find.byType(WorkspacePage)));
    container.read(chatControllerProvider.notifier).send('测试');
    await tester.pump();

    expect(tester.takeException(), isNull, reason: '故障条出现时布局抛异常');
  });

  // ---- 各页在有数据时的布局（mock 已返回真实形状的数据）----
  //
  // ⚠️ 空态过了不等于有数据也过 —— `RenderBox was not laid out` 这类问题
  // 恰恰都发生在数据到达、控件长出内容之后。所以必须带数据测。
  final pages = <String, Widget>{
    '设置': const SettingsPage(),
    '场景': ResourceListPage(spec: StudioPageSpecs.scenes, title: '场景'),
    '子 Agent':
        ResourceListPage(spec: StudioPageSpecs.subagent, title: '子 Agent'),
    '技能': ResourceListPage(spec: StudioPageSpecs.skill, title: '技能'),
    'MCP': ResourceListPage(spec: StudioPageSpecs.mcp, title: 'MCP'),
    '知识库':
        ResourceListPage(spec: StudioPageSpecs.knowledge, title: '知识库'),
    '大模型中转站': const RelayPage(title: '大模型中转站'),
  };

  pages.forEach((label, page) {
    testWidgets('$label 页在有数据时能正常 layout', (tester) async {
      tester.view
        ..physicalSize = const Size(1366, 768)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(page: page));
      // 数据是异步来的，多 pump 几次等它落到界面上。
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.takeException(), isNull, reason: '$label 页布局抛异常');
    });
  });

  testWidgets('模型选择器展开时能正常 layout', (tester) async {
    tester.view
      ..physicalSize = const Size(1366, 768)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // 下拉里有超长模型名，正好验证截断。
    final selector = find.byIcon(Icons.expand_more_rounded);
    if (selector.evaluate().isNotEmpty) {
      await tester.tap(selector.first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '模型下拉展开时布局抛异常');
    }
  });

  testWidgets('中转站 L1→L2→L3(密钥弹窗) 全走一遍', (tester) async {
    tester.view
      ..physicalSize = const Size(1366, 768)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(page: const RelayPage(title: '大模型中转站')));
    await _settle(tester);

    // 默认个人版 → 只该看到 tag=custom 的行。builtin 那行不该露出来
    // （同 code 两行是现网常态，不过滤就会串）。
    expect(find.text('Alibaba（个人）'), findsOneWidget);
    expect(find.text('Alibaba'), findsNothing);

    // L1 → L2
    await tester.tap(find.text('Alibaba（个人）').first);
    await _settle(tester);
    expect(tester.takeException(), isNull, reason: 'L2 模型层布局抛异常');
    // include_disabled 生效：**停用**的模型也得列出来，否则没法重新启用。
    expect(find.text('GLM-4（个人·已停用）'), findsOneWidget);

    // L2 → L3：密钥池弹窗（品牌级，不是下钻）。
    await tester.tap(find.byIcon(Icons.key_rounded).first);
    await _settle(tester);
    expect(tester.takeException(), isNull, reason: 'L3 密钥池弹窗布局抛异常');
    // ⚠️ 密钥必须是**脱敏**的：完整明文绝不能出现在界面上。
    expect(find.textContaining('123456'), findsWidgets);
    expect(find.text('******123456'), findsNothing);
  });

  // ---- CRUD 表单的布局（字段最多的两个，最容易溢出）----
  for (final (label, icon) in [
    ('厂商', Icons.add_rounded),
  ]) {
    testWidgets('中转站「新增$label」表单在窄屏也能 layout', (tester) async {
      // 刻意用窄屏：460 宽的表单在小视口最容易撑破。
      tester.view
        ..physicalSize = const Size(520, 640)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(page: const RelayPage(title: '大模型中转站')));
      await _settle(tester);

      await tester.tap(find.byIcon(icon).first);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: '$label 表单布局抛异常');
      // 9 个字段都在。
      expect(find.byType(TextField), findsAtLeast(7));
    });
  }

  // ---- 窄屏：工具栏按钮多的页面最容易在这里炸 ----
  //
  // ⚠️ 之前只测 1366 宽，而中转站 L2 的工具栏塞了 back/标题/标记/作用域切换/
  // 同步/密钥池/新增/刷新 八样东西 —— 窄一点就必然溢出。
  for (final w in [520.0, 800.0, 1100.0]) {
    testWidgets('中转站 L2 工具栏在 ${w.toInt()}px 宽下不溢出', (tester) async {
      tester.view
        ..physicalSize = Size(w, 700)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app(page: const RelayPage(title: '大模型中转站')));
      await _settle(tester);
      await tester.tap(find.text('Alibaba（个人）').first);
      await _settle(tester);

      expect(tester.takeException(), isNull,
          reason: '${w.toInt()}px 宽下 L2 工具栏布局抛异常');
    });

    testWidgets('工作台在 ${w.toInt()}px 宽下：建连状态条 + 提示条同屏', (tester) async {
      tester.view
        ..physicalSize = Size(w, 700)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(app());
      await _settle(tester);

      // 触发一次被拒的发送 → 提示条出现，与建连状态条同屏。
      final c = ProviderScope.containerOf(
          tester.element(find.byType(WorkspacePage)));
      c.read(chatControllerProvider.notifier).send('测试');
      await _settle(tester);

      expect(tester.takeException(), isNull,
          reason: '${w.toInt()}px 宽下状态条/提示条布局抛异常');
    });
  }

  testWidgets('切到管理版会出警示条并重拉数据', (tester) async {
    tester.view
      ..physicalSize = const Size(1366, 768)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(page: const RelayPage(title: '大模型中转站')));
    await _settle(tester);

    // 默认个人版：有「个人（本地）」标记，无警示条。
    expect(find.text('个人（本地）'), findsOneWidget);
    expect(find.byIcon(Icons.public_rounded), findsNothing);
    expect(find.text('自建厂商'), findsOneWidget);

    await tester.tap(find.text('管理'));
    await _settle(tester);
    expect(tester.takeException(), isNull, reason: '管理版布局抛异常');
    // 管理版改的是全平台配置，必须有显式警示。
    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    // 切了作用域，显示的行也要跟着换成 builtin 那批。
    expect(find.text('Alibaba'), findsOneWidget);
    expect(find.text('自建厂商'), findsNothing);
  });
}

/// 等异步数据落到界面上。数据是 microtask + await 链来的，单次 pump 不够。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
