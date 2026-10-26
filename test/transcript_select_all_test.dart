import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sgit_studio_flutter/features/chat/application/chat_ports_impl.dart';
import 'package:sgit_studio_flutter/app/app_providers.dart';
import 'package:sgit_studio_flutter/core/storage/local_storage.dart';
import 'package:sgit_studio_flutter/data/repositories/session_sync_repository.dart';
import 'package:sgit_studio_flutter/data/repositories/thread_repository.dart';
import 'fakes/kernel_client_mock.dart';
import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';
import 'package:sgit_studio_flutter/features/chat/application/thread_list_controller.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/chat_transcript.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';

/// 会话里 Ctrl+A 的**范围**。
///
/// 列表是惰性的：滚出视口的条目连同它的 `Selectable` 一起被回收，所以直接
/// 交给 `SelectionArea` 的全选只覆盖当前构建范围 —— 用户看到的正是"只选了一半"。
///
/// 这里守两条路（见 `ChatTranscript._handleSelectAll`）：
///
/// * 短会话（<= 200 条）：临时撑大缓存区把条目全建出来，真全选；
/// * 长会话（> 200 条）：不建那几千条，Ctrl+A 备好整段文本、Ctrl+C 直接写它。
///
/// 断言一律走 **Ctrl+A → Ctrl+C → 剪贴板**：能测出"复制出来的东西对不对"，
/// 而不只是"内部状态长什么样"。
class _Repo implements ThreadRepository {
  _Repo(this.texts);
  final List<String> texts;

  @override
  Future<ThreadPage> list({String? cursor}) async =>
      const ThreadPage(threads: []);

  @override
  Future<ThreadReplay> open(String threadId) async => ThreadReplay(
        summary: ThreadSummary(
          id: threadId,
          title: 't',
          preview: '',
          createdAt: null,
          updatedAt: null,
        ),
        events: [
          for (final (i, t) in texts.indexed) ...[
            {'t': 'textStarted', 'itemId': i},
            {'t': 'textDelta', 'itemId': i, 'chunk': t},
            {'t': 'textCompleted', 'itemId': i},
          ],
        ],
      );

  @override
  Future<void> rename(String threadId, String name) async {}

  @override
  Future<void> delete(String threadId) async {}
}

class _Sync implements SessionSyncRepository {
  @override
  bool get enabled => false;
  @override
  Future<SessionSyncResult> sync() async => const SessionSyncResult(ok: true);
  @override
  Future<bool> refreshThread(String threadId) async => false;
}

void main() {
  late List<String> clipboard;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  setUp(() {
    clipboard = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboard.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Widget harness(List<String> texts) => ProviderScope(
        overrides: [
 chatPortsOverride,
          threadRepositoryProvider.overrideWithValue(_Repo(texts)),
          sessionSyncRepositoryProvider.overrideWithValue(_Sync()),
          chatControllerProvider
              .overrideWith(() => ChatController(client: MockKernelClient())),
        ],
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
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: const Scaffold(body: ChatTranscript()),
        ),
      );

  Future<void> advance(WidgetTester tester, {int frames = 30}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// 点正文拿焦点 → Ctrl+A → Ctrl+C。
  Future<void> selectAllAndCopy(WidgetTester tester) async {
    await tester.tap(find.byType(RichText).first, warnIfMissed: false);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    // 撑大缓存区的那一帧要真的画出来，条目才会注册进选区。
    await tester.pump();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
  }

  Future<void> openThread(WidgetTester tester, List<String> texts) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(texts));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ChatTranscript)));
    await container.read(chatControllerProvider.notifier).openThreadById('t1');
    await advance(tester);
  }

  testWidgets('短会话：Ctrl+A 选中视口之外的条目（回归「只选了一部分」）',
      (tester) async {
    // 每条都够高，最后一条留在视口里、前面几十条早就被回收了。
    final texts = [
      for (var i = 0; i < 30; i++)
        '第 $i 段。${'这是一段用来撑高度的话。' * 30}',
    ];
    await openThread(tester, texts);

    // 前提：确实有大量条目没建出来，否则这条测试测不到惰性。
    expect(
      find.byType(RichText).evaluate().length,
      lessThan(texts.length),
      reason: '会话必须长到一部分条目没被建出来，才谈得上"全选"',
    );

    await selectAllAndCopy(tester);

    expect(clipboard, isNotEmpty, reason: 'Ctrl+C 应该真的写了剪贴板');
    final copied = clipboard.last;
    for (final i in [0, 1, 15, 29]) {
      expect(copied, contains('第 $i 段。'),
          reason: '⚠️ 修之前只选当前构建范围，滚出视口的第 $i 段会缺');
    }
  });

  testWidgets('长会话：Ctrl+A → Ctrl+C 拿到整段会话，且不必把条目全建出来',
      (tester) async {
    const count = 260; // 超过 ChatTranscript._selectAllLimit
    final texts = [
      for (var i = 0; i < count; i++) '第 $i 段。${'这是一段用来撑高度的话。' * 10}',
    ];
    await openThread(tester, texts);

    final builtBefore = find.byType(RichText).evaluate().length;

    await selectAllAndCopy(tester);

    expect(clipboard, isNotEmpty);
    final copied = clipboard.last;
    expect(copied, contains('第 0 段。'), reason: '最旧的一条也必须在里面');
    expect(copied, contains('第 ${count - 1} 段。'), reason: '最新的一条也必须在里面');

    final builtAfter = find.byType(RichText).evaluate().length;
    expect(builtAfter, lessThan(count ~/ 2),
        reason: '长会话不该为了全选把几千条建出来（建齐要几百毫秒）');
    expect(builtAfter, lessThanOrEqualTo(builtBefore + 2),
        reason: '降级路径不物化，构建数量不该因为全选跳起来');
  });

  testWidgets('长会话：快照只对一次 Ctrl+A 有效 —— 之后 Ctrl+C 回到选区语义',
      (tester) async {
    const count = 240;
    final texts = [
      for (var i = 0; i < count; i++) '第 $i 段。${'这是一段用来撑高度的话。' * 10}',
    ];
    await openThread(tester, texts);

    // 先真的选中一段（模拟用户拖选），再按 Ctrl+A 又取消。
    await selectAllAndCopy(tester);
    expect(clipboard.last, contains('第 0 段。'));

    // 用户点一下正文重新放了光标（选区被清空）—— 快照应当随之失效。
    await tester.tap(find.byType(RichText).first, warnIfMissed: false);
    await tester.pump();

    clipboard.clear();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(
      clipboard.where((t) => t.contains('第 0 段。')),
      isEmpty,
      reason: '没有新的 Ctrl+A 就不该再吐整段会话',
    );
  });
}
