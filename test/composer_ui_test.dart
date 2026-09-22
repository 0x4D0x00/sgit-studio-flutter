import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_mock.dart';
import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/design/tokens/composer_metrics.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/chat_composer.dart';
import 'package:sgit_studio_flutter/features/studio/application/kernel_client_provider.dart';
import 'package:sgit_studio_flutter/features/studio/application/settings_repository_provider.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_control_bar.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_shell.dart';

import 'fakes/fake_settings_repository.dart';

/// 输入框的结构与交互回归。
///
/// ## 为什么要有「点开菜单」这一类断言
///
/// 输入框上的 `+` / 审批策略 / 沙箱档位全都是 `AppMenuAnchor` 的触发器，而锚点
/// **自己会在 child 外面套一层 `InkWell`**。触发器组件里如果也套一层，内层会先
/// 命中并吃掉点击 —— 菜单永远打不开，而且**看不出任何异常**：有涟漪、有 hover、
/// 有 tooltip，就是不弹。纯靠 `flutter analyze` 与结构断言抓不到，只有真点一下才知道。
///
/// 这个坑在本次改动里真实发生过一次，所以留下这些测试。
void main() {
  late FakeSettingsRepository settings;

  setUp(() {
    settings = FakeSettingsRepository(
      pages: const {'tools': FakeSettingsRepository.toolsSnapshot},
    );
  });

  Widget harness(ComposerVariant variant) => ProviderScope(
        overrides: [
          chatControllerProvider.overrideWith(
            () => ChatController(client: MockKernelClient()),
          ),
          // 模型列表走 kernelClientProvider → GatewayRepository，与 chatController
          // 不是同一条路，必须单独注入（同 layout_test.dart 的教训）。
          kernelClientProvider.overrideWithValue(MockKernelClient()),
          settingsRepositoryProvider.overrideWithValue(settings),
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
          home: Scaffold(body: Center(child: ChatComposer(variant: variant))),
        ),
      );

  group('两态结构（照搬 studio 的两套动作栏配置）', () {
    testWidgets('空态：没有控制条，模型名显示在右下', (tester) async {
      await tester.pumpWidget(harness(ComposerVariant.empty));
      await tester.pump();

      expect(find.byType(ComposerShell), findsOneWidget);
      expect(find.byType(ComposerControlBar), findsNothing,
          reason: 'studio 首页 showControlBar={false}');
      // 模型名是文字形态（不是会话态那个图标形态），且显示的是**实际会用的那个模型**。
      expect(find.text('GLM-4'), findsOneWidget);
    });

    testWidgets('会话态：有控制条，上面是沙箱档位 + 推理强度', (tester) async {
      await tester.pumpWidget(harness(ComposerVariant.conversation));
      await tester.pump();

      expect(find.byType(ComposerControlBar), findsOneWidget);
      // 默认档：引擎的 SandboxMode 默认只读、ReasoningEffort 默认 medium。
      expect(find.text('只读'), findsOneWidget);
      expect(find.text('中'), findsOneWidget);
    });

    testWidgets('空态编辑区比会话态高（studio: minHeight 60 vs 36）', (tester) async {
      await tester.pumpWidget(harness(ComposerVariant.empty));
      await tester.pump();
      final empty = tester.getSize(find.byType(TextField)).height;

      await tester.pumpWidget(harness(ComposerVariant.conversation));
      await tester.pump();
      final conversation = tester.getSize(find.byType(TextField)).height;

      expect(empty, ComposerMetrics.editorMinHeightEmpty);
      expect(conversation, ComposerMetrics.editorMinHeightConversation);
      expect(empty, greaterThan(conversation));
    });
  });

  group('菜单真的能点开', () {
    testWidgets('+ 菜单：附件 / 联网搜索 / 记忆 / 技能 / 知识库', (tester) async {
      await tester.pumpWidget(harness(ComposerVariant.empty));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('附件'), findsOneWidget);
      expect(find.text('联网搜索'), findsOneWidget);
      expect(find.text('记忆'), findsOneWidget);
      expect(find.text('技能'), findsOneWidget);
      expect(find.text('知识库'), findsOneWidget);
    });

    testWidgets('审批策略菜单：sgcode 原生四档，默认停在「由模型决定」', (tester) async {
      await tester.pumpWidget(harness(ComposerVariant.empty));
      await tester.pump();

      // 默认档是 on-request，图标是那只手。
      await tester.tap(find.byIcon(Icons.back_hand_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('由模型决定'), findsWidgets);
      expect(find.text('仅信任只读'), findsOneWidget);
      expect(find.text('从不询问'), findsOneWidget);
      expect(find.text('细粒度'), findsOneWidget);
    });

    testWidgets('沙箱档位菜单：三档', (tester) async {
      await tester.pumpWidget(harness(ComposerVariant.conversation));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.lock_outline).first);
      await tester.pumpAndSettle();

      expect(find.text('只读'), findsWidgets);
      expect(find.text('可写工作区'), findsOneWidget);
      expect(find.text('完全放开'), findsOneWidget);
    });
  });

  group('模型列表与中转站页读同一条路', () {
    // ⚠️ 这一组守的是一个**没有任何报错**的故障：中转站页早已改走
    // SettingsRepository（桌面 FFI 直读本地 silicoid.db），而输入框的模型选择器
    // 一度还留在 GatewayRepository。于是同一个账号、同一批模型：
    //   中转站页 → 模型都在；输入框 → 「暂无可用模型」。
    // 模型取不到会被 catch 咽掉回空列表，所以日志里什么都看不见。

    testWidgets('模型经 relayManage 取，不打 gateway', (tester) async {
      settings = FakeSettingsRepository(
        pages: const {'tools': FakeSettingsRepository.toolsSnapshot},
      );
      await tester.pumpWidget(harness(ComposerVariant.empty));
      await tester.pumpAndSettle();

      // 两个 scope 各取一次厂商 —— 平台（master）与个人直连（personal）。
      expect(settings.calls, contains('relayManage:model/providers:master'));
      expect(settings.calls, contains('relayManage:model/providers:personal'));
    });

    testWidgets('没选过模型时，标签显示列表第一个，而不是「默认模型」四个字', (tester) async {
      settings = FakeSettingsRepository(
        pages: const {'tools': FakeSettingsRepository.toolsSnapshot},
      );
      await tester.pumpWidget(harness(ComposerVariant.empty));
      await tester.pumpAndSettle();

      // 不选模型时引擎用的就是列表第一个，显示"默认"等于把用户实际在用的模型藏起来。
      expect(find.text('GLM-4'), findsOneWidget);
      expect(find.text('默认模型'), findsNothing);
      expect(find.text('暂无可用模型'), findsNothing);
    });

    testWidgets('菜单里的「默认模型」标出它实际解析成谁', (tester) async {
      settings = FakeSettingsRepository(
        pages: const {'tools': FakeSettingsRepository.toolsSnapshot},
      );
      await tester.pumpWidget(harness(ComposerVariant.empty));
      await tester.pumpAndSettle();

      await tester.tap(find.text('GLM-4'));
      await tester.pumpAndSettle();

      // 菜单里既有「默认模型」这一项，右侧又标着它解析到的模型名 ——
      // 否则触发器显示 GLM-4、菜单勾着"默认模型"，像两个不同的选择。
      expect(find.text('默认模型'), findsOneWidget);
      expect(find.text('GLM-4'), findsWidgets);
    });
  });

  group('改设置落到 sgcode 的真键上', () {
    testWidgets('切沙箱档位 → 写 sandbox_mode=workspace-write', (tester) async {
      await tester.pumpWidget(harness(ComposerVariant.conversation));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.lock_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('可写工作区'));
      await tester.pumpAndSettle();

      expect(
        settings.calls,
        contains('setToolConfig:sandbox_mode=workspace-write'),
      );
    });

    testWidgets('切审批策略 → 写 approval_policy=never', (tester) async {
      await tester.pumpWidget(harness(ComposerVariant.empty));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.back_hand_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('从不询问'));
      await tester.pumpAndSettle();

      expect(settings.calls, contains('setToolConfig:approval_policy=never'));
    });

    testWidgets('开联网搜索 → 写 web_search（不是某个自造键）', (tester) async {
      await tester.pumpWidget(harness(ComposerVariant.empty));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('联网搜索'));
      await tester.pumpAndSettle();

      // `cached` 是引擎 WebSearchMode 的默认档。原先这里断言 `enabled`，
      // 而那个档位根本不存在 —— 写进 config.toml 会让本地引擎起不来。
      expect(settings.calls, contains('setToolConfig:web_search=cached'));
    });

    testWidgets('关记忆 → 写 memories.use_memories=false', (tester) async {
      await tester.pumpWidget(harness(ComposerVariant.empty));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.tap(find.text('记忆'));
      await tester.pumpAndSettle();

      // ⚠️ 不是 memories.enabled —— 引擎的 MemoriesToml 里没那个键。
      expect(
        settings.calls,
        contains('setToolConfig:memories.use_memories=false'),
      );
    });
  });

  group('写失败要让用户看见', () {
    testWidgets('setToolConfig 抛异常 → 弹提示且档位回滚', (tester) async {
      settings = FakeSettingsRepository(
        pages: const {'tools': FakeSettingsRepository.toolsSnapshot},
        failToolWrites: true,
      );
      await tester.pumpWidget(harness(ComposerVariant.conversation));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.lock_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('可写工作区'));
      await tester.pumpAndSettle();

      // 静默失败的开关比没有开关更糟 —— 用户会以为设上了。
      expect(find.textContaining('设置未保存'), findsOneWidget);
      // 控制条回到原档位。
      expect(find.text('只读'), findsOneWidget);
    });
  });
}
