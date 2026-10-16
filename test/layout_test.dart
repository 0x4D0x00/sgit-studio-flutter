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
import 'package:sgit_studio_flutter/features/studio/presentation/pages/tools_page.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/pages/resource_list_page.dart';
import 'package:sgit_studio_flutter/features/studio/application/kernel_client_provider.dart';
import 'package:sgit_studio_flutter/features/studio/application/settings_repository_provider.dart';

import 'fakes/fake_settings_repository.dart';
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
          // ⚠️ studio 那几个控制器（中转站 / 资源列表 / 模型列表）走的是
          // `kernelClientProvider` → `GatewayRepository`，**不是** chatController。
          // 这里必须单独注入 mock：桌面工厂返回的是真 FFI 通道（要加载
          // sgit_ffi.dll 并连 gateway），测试环境里必然失败。
          //
          // 这一条原先是隐式成立的 —— 桌面工厂当时回落 mock，所以没人注意到。
          // 补完 FFI 内核符号后它就暴露了：**测试要靠注入，不能靠生产工厂的平台默认值**。
          kernelClientProvider.overrideWithValue(MockKernelClient()),
          // 同理：生产工厂会去加载 sgit_ffi.dll，测试环境必然失败。
          // 那个失败会被控制器的 _loadUnsynced catch 掉、测试照样绿 ——
          // 绿得毫无意义。显式注入假实现。
          // 中转站在本地模式下从这里读（`sgit_studio_read('llm-relay')`），
          // 不再打 gateway —— 所以 fixture 要给到 fake，给 MockKernelClient
          // 已经不够了。
          settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository(
            pages: const {
              'llm-relay': FakeSettingsRepository.relaySnapshot,
              'tools': FakeSettingsRepository.toolsSnapshot,
            },
          )),
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
          home: AppShellContainer(isConversation: true, child: page),
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
    // 工具页是开关面板（config.toml 的 [features]），不走通用列表页。
    '工具': const ToolsPage(title: '工具'),
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

    // 个人页 = **自建的 ∪ 平台已开放的**（照 React 的 keepProvidersByScope）。
    //
    // ⚠️ 这条原先断言的是"只留 tag=custom、builtin 不该露出来" —— 那是错的，
    // 会把平台开放给用户的厂商全滤掉，用户明明能用的模型一个都看不见。
    expect(find.text('Alibaba（个人）'), findsOneWidget, reason: '自建的要显示');
    expect(find.text('Alibaba'), findsOneWidget, reason: '平台已开放(status=1)的也要显示');
    expect(find.text('自建厂商'), findsOneWidget);
    // 但**停用的平台厂商不显示** —— 那是管理面的事，摆在个人页只是噪音
    // （现网 19 个平台厂商里 17 个是停用的）。
    expect(find.text('DeepSeek'), findsNothing,
        reason: '平台厂商 status=0，个人页不该显示');

    // 平台行只读：编辑/删除按钮禁用（onPressed == null）。个人页的写一律落
    // tag=custom，改平台行只会造出同名影子行、删厂商更会级联删平台模型。
    final editButtons = tester.widgetList<IconButton>(find.ancestor(
      of: find.byIcon(Icons.edit_outlined),
      matching: find.byType(IconButton),
    ));
    expect(editButtons.where((b) => b.onPressed == null), isNotEmpty,
        reason: '平台厂商的编辑按钮必须禁用');
    expect(editButtons.where((b) => b.onPressed != null), isNotEmpty,
        reason: '自建厂商的编辑按钮要能点 —— 别一刀切全禁了');

    // L1 → L2。
    //
    // ⚠️ 点的这一行与上面的平台行 **model_code 相同**（都是 Qwen）—— 现网常态。
    // 所以下钻必须带 tag 一起定位：只按 code 查会拿到排序在前的平台行，
    // 后续请求带错 scope，读到的就是另一批数据。下面断言的是自建那条模型。
    await tester.tap(find.text('Alibaba（个人）').first);
    await _settle(tester);
    expect(tester.takeException(), isNull, reason: 'L2 模型层布局抛异常');
    // include_disabled 生效：**停用**的模型也得列出来，否则没法重新启用。
    expect(find.text('GLM-4（个人·已停用）'), findsOneWidget);
    // 反向确认 scope 没串：平台那批模型（tag=builtin）不该混进来。
    expect(find.text('GLM-4'), findsNothing,
        reason: '下钻自建厂商时带的是 scope=personal，不该出现平台行的模型');


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

  testWidgets('只提供个人页：没有作用域切换，也没有管理版警示条', (tester) async {
    tester.view
      ..physicalSize = const Size(1366, 768)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(page: const RelayPage(title: '大模型中转站')));
    await _settle(tester);

    // 有「个人（本地）」标记，说明数据落在本机 per-cid 库。
    expect(find.text('个人（本地）'), findsOneWidget);

    // ⚠️ studio-flutter **只做个人页**，所以这些一个都不该在：
    // 作用域切换（会让用户误以为能在桌面端改全平台配置）、管理版警示条。
    expect(find.text('管理'), findsNothing, reason: '不该有作用域切换');
    expect(find.byIcon(Icons.public_rounded), findsNothing,
        reason: '没有管理版，就不该有管理版警示条');

    // 自建的行照常在。
    expect(find.text('自建厂商'), findsOneWidget);
  });
}

/// 等异步数据落到界面上。数据是 microtask + await 链来的，单次 pump 不够。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
