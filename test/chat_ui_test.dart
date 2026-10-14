import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sgit_studio_flutter/core/storage/local_storage.dart';
import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_mock.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/chat_composer.dart';
import 'package:sgit_studio_flutter/features/studio/application/settings_repository_provider.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/chat_transcript.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/approval_card.dart';
import 'package:sgit_studio_flutter/ui/components/chat/text_bubble.dart';
import 'package:sgit_studio_flutter/ui/components/chat/thinking_row.dart';
import 'package:sgit_studio_flutter/ui/components/chat/tool_card.dart';

import 'fakes/fake_settings_repository.dart';

/// 对话链路的端到端测试：**mock 产真字节 → 真编解码 → 真控制器 → 真 UI**。
///
/// 之所以不用「假数据列表」当 mock：那样等 P1a 的真 FFI 接上来时，帧格式、按帧
/// drain、背压丢帧这些真正容易错的地方一个都没被验证过。这里走的是完整链路，
/// 换成真通道时只换 `KernelClient` 的实现类，本测试的断言应当全部继续成立。
void main() {
  // 输入框的宽度上限取自「转录宽度」这个横切偏好，它读 LocalStorage
  // （生产在 bootstrap 里 await 过）。同 layout_test.dart。
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

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

  testWidgets('思考状态行：发出后出现，第一段回答落地后消失', (tester) async {
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatComposer)));
    await container.read(chatControllerProvider.notifier).connect();
    await tester.pump();

    // 还没发东西，不该有思考行。
    expect(find.byType(ThinkingRow), findsNothing);

    await tester.enterText(find.byType(TextField), '看一下仓库结构');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();

    // ⚠️ 这一刻就是本功能的全部理由：用户气泡已经在了，助手那边**一个字都没有**
    // （mock 的 turnStarted 都还没到）。没有这一行，屏幕和"卡死了"没有区别。
    expect(find.byType(ThinkingRow), findsOneWidget);
    expect(find.text('看一下仓库结构'), findsOneWidget);

    // 走到第一段回答落地 → 行让位，正文接上。
    await advance(tester, frames: 10);
    expect(find.byType(ThinkingRow), findsNothing,
        reason: '有正文可看了，状态行必须消失，否则它会永远转下去');
    expect(find.byType(TextBubble), findsAtLeastNWidgets(2));

    // 收尾：把 mock 的 timer 跑完，别留挂起的 Timer。
    await advance(tester, frames: 200);
  });

  /// 打开历史会话时，**一屏放得下的内容要从版式顶部往下排**。
  ///
  /// 反向列表（`reverse: true`）的坐标系里，offset 0 恒等于**视觉底部**，
  /// 所以内容不足一屏时它天生是贴底画、把空白全留在上面 —— 这正是曾经的
  /// bug：三条气泡孤零零吊在屏幕下方。修法是 `shrinkWrap` + 顶对齐，
  /// 本测试就是钉住它。**这条断言不是"布局长得好看"，而是那条坐标约定的
  /// 直接后果**，改动 `reverse` 或去掉 `shrinkWrap` 都会让它变红。
  testWidgets('短会话：内容不足一屏时从顶部往下排，不留空白在上方', (tester) async {
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatComposer)));
    await container.read(chatControllerProvider.notifier).connect();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '帮我总结一下');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();

    // 只让用户气泡落地，此刻内容**远不足一屏**。
    final bubble = find.byType(TextBubble);
    expect(bubble, findsOneWidget);

    final viewportTop = tester.getRect(find.byType(ChatTranscript)).top;
    final bubbleTop = tester.getTopLeft(bubble).dy;

    // 气泡顶端应当紧贴转录区上沿（只隔着 `framePadding` 的内边距），
    // 而不是被推到屏幕下半区。给 8px 余量吸收内边距与抗锯齿的取整。
    expect(
      bubbleTop - viewportTop,
      lessThan(WorkspaceMetrics.framePadding * 4),
      reason: '短会话必须从上往下排；贴底画会让这个偏移变成几百像素',
    );

    await advance(tester, frames: 200);
  });

  /// 长会话不被上一条改动波及：内容超过一屏后仍要**钉在最新一条**。
  ///
  /// 与上一条是同一条规则的两面 —— `shrinkWrap` 只在"内容不足一屏"时
  /// 才把高度缩到内容高度；一旦超出，高度回落到视口高，`reverse` 照旧
  /// 让最新一条落在底部。少了这条，一个"永远顶对齐"的实现也能让上面
  /// 那条测试通过。
  testWidgets('长会话：内容超过一屏后仍停在最新一条（底部）', (tester) async {
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatComposer)));
    await container.read(chatControllerProvider.notifier).connect();
    await tester.pump();

    // 把 mock 整个脚本跑完：文本 + 工具卡 + 审批 + 用量，稳稳超过一屏。
    await tester.enterText(find.byType(TextField), '看一下仓库结构');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await advance(tester, frames: 30);
    await tester.tap(find.text('允许一次'));
    await advance(tester, frames: 120);

    final scrollable = tester.widget<ListView>(find.byType(ListView));
    expect(scrollable.reverse, isTrue,
        reason: '反向列表是本文件整套「自动下滑」设计的前提，不能改成正向');
    expect(scrollable.shrinkWrap, isTrue,
        reason: '短会话的顶对齐依赖它');

    // 滚到底：位置应当停在最小滚动量（反向列表里那正是"最新一条"）。
    final controller = tester
        .widget<Scrollable>(find.byType(Scrollable).first)
        .controller!;
    expect(controller.offset, closeTo(controller.position.minScrollExtent, 0.5));
    expect(controller.position.maxScrollExtent, greaterThan(0),
        reason: '内容必须真的超过一屏，否则这条测试什么都没验证');

    await advance(tester, frames: 200);
  });
}
