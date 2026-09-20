import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_mock.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/chat_composer.dart';
import 'package:sgit_studio_flutter/features/studio/application/settings_repository_provider.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/chat_transcript.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/approval_card.dart';
import 'package:sgit_studio_flutter/ui/components/chat/text_bubble.dart';
import 'package:sgit_studio_flutter/ui/components/chat/tool_card.dart';

import 'fakes/fake_settings_repository.dart';

/// 对话链路的端到端测试：**mock 产真字节 → 真编解码 → 真控制器 → 真 UI**。
///
/// 之所以不用「假数据列表」当 mock：那样等 P1a 的真 FFI 接上来时，帧格式、按帧
/// drain、背压丢帧这些真正容易错的地方一个都没被验证过。这里走的是完整链路，
/// 换成真通道时只换 `KernelClient` 的实现类，本测试的断言应当全部继续成立。
void main() {
  /// 逐帧推进。
  ///
  /// ⚠️ 不能用 `pump(Duration(...))` 一步跳 300ms：那样是**先画帧、再走 timer**，
  /// 而控制器的 drain 挂在 `addPostFrameCallback` 上 —— timer 里注册的回调要等
  /// 下一帧才跑，一步大跳就永远差一帧。这里一帧 16ms 地推，和真机行为一致。
  Future<void> advance(WidgetTester tester, {int frames = 20}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Widget harness() => ProviderScope(
        overrides: [
          // 输入框会读引擎设置（审批策略 / 沙箱档位 / 推理强度）。真实现是
          // `dart:ffi` 打本地 `sgit_ffi` —— 测试机上没有那个动态库。
          // 控制器本来就会吞掉读失败并退回默认档，但**让测试依赖"某处会抛异常"
          // 不算隔离**：那样一旦异常类型变了，失败现场会出现在八竿子打不着的地方。
          settingsRepositoryProvider.overrideWithValue(
            FakeSettingsRepository(
              pages: const {'tools': FakeSettingsRepository.toolsSnapshot},
            ),
          ),
          chatControllerProvider.overrideWith(
            // tick 调快、每 tick 多产几帧，压出批合并行为。
            () => ChatController(
              client: MockKernelClient(
                tick: const Duration(milliseconds: 8),
                emitPerTick: 6,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(
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
          // ⚠️ 不给 supportedLocales，MaterialApp 默认只支持 en_US，locale:'zh'
          // 会被解析回英文，中文断言全找不到（第一版就栽在这）。
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Column(
              children: [
                Expanded(child: ChatTranscript()),
                // 会话态：有控制条、编辑区可拖拽 —— 与本测试模拟的"已经在聊"一致。
                ChatComposer(variant: ComposerVariant.conversation),
              ],
            ),
          ),
        ),
      );

  testWidgets('发一条消息 → 用户气泡 + 流式回答 + 工具卡 + 审批卡全部渲染', (tester) async {
    await tester.pumpWidget(harness());

    final ctrl = tester
        .element(find.byType(ChatComposer))
        .findAncestorWidgetOfExactType<ProviderScope>();
    expect(ctrl, isNotNull);

    // 建连（能力协商）。
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatComposer)));
    await container.read(chatControllerProvider.notifier).connect();
    await tester.pump();

    // 输入并发送。
    await tester.enterText(find.byType(TextField), '看一下仓库结构');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();

    // 用户气泡立刻出现。
    expect(find.byType(TextBubble), findsOneWidget);
    expect(find.text('看一下仓库结构'), findsOneWidget);

    // 让 mock 的 timer 跑起来，帧陆续到达。
    await advance(tester);

    // 助理气泡出来了（用户 1 条 + 助理至少 1 条）。
    expect(find.byType(TextBubble), findsAtLeastNWidgets(2));

    // 工具卡出来了。
    await advance(tester);
    expect(find.byType(ToolCard), findsAtLeastNWidgets(1));

    // 审批卡出来了，并且**卡住不再往下跑** —— 内核在等我们回话。
    expect(find.byType(ApprovalCard), findsOneWidget);
    expect(find.text('允许一次'), findsOneWidget);
    expect(find.text('总是允许'), findsOneWidget);
    expect(find.text('拒绝'), findsOneWidget);

    // 回应审批后，按钮换成结果文案，且不再可点。
    await tester.tap(find.text('允许一次'));
    await tester.pump();
    expect(find.text('已允许'), findsOneWidget);
    expect(find.text('允许一次'), findsNothing);

    // 继续跑到 turn 结束，用量条出现（数字来自内核，我们不重算）。
    await advance(tester, frames: 60);
    expect(find.textContaining('输入 1234'), findsOneWidget);
  });

  testWidgets('跑动期间：提示语变插话、按钮变停止/插话', (tester) async {
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatComposer)));
    await container.read(chatControllerProvider.notifier).connect();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '开始');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await advance(tester, frames: 4);

    // 跑动 + 输入框空 → 停止键。
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    // 跑动 + 有内容 → 插话键（steer，不是打断）。
    await tester.enterText(find.byType(TextField), '顺便看下依赖方向');
    await tester.pump();
    expect(find.byIcon(Icons.reply_rounded), findsOneWidget);
    expect(find.byIcon(Icons.stop_rounded), findsNothing);

    // 插话后输入框清空，turn 仍在跑（没被打断）。
    await tester.tap(find.byIcon(Icons.reply_rounded));
    await tester.pump();
    expect(container.read(chatControllerProvider).busy, isTrue);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

    // 收尾：把 timer 跑完，避免测试结束时留挂起的 Timer。
    await advance(tester, frames: 200);
  });
}
