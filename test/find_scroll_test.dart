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
import 'package:sgit_studio_flutter/features/find/application/find_controller.dart';
import 'package:sgit_studio_flutter/features/find/presentation/find_host.dart';
import 'package:sgit_studio_flutter/ui/components/find/find_highlight.dart';
import 'package:flutter/rendering.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';

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
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
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
          home: const Scaffold(
            body: FindHost(child: ChatTranscript()),
          ),
        ),
      );

  Future<void> advance(WidgetTester tester, {int frames = 60}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// 当前匹配（深色底）那一段文字在屏幕上的纵向范围；找不到返回 null。
  (double, double)? currentMatchY(WidgetTester tester) {
    final colors = FindColors.of(tester.element(find.byType(ChatTranscript)));
    (double, double)? out;
    void visit(RenderObject o) {
      if (out != null) return;
      if (o is RenderParagraph) {
        var offset = 0;
        o.text.visitChildren((span) {
          if (span is TextSpan && span.text != null) {
            if (span.style?.backgroundColor == colors.current) {
              final boxes = o.getBoxesForSelection(TextSelection(
                  baseOffset: offset, extentOffset: offset + span.text!.length));
              final r = boxes.first.toRect();
              out = (
                o.localToGlobal(r.topLeft).dy,
                o.localToGlobal(r.bottomLeft).dy
              );
              return false;
            }
            offset += span.text!.length;
          }
          return true;
        });
        return;
      }
      o.visitChildren(visit);
    }

    visit(tester.binding.rootElement!.renderObject!);
    return out;
  }

  Future<void> run(WidgetTester tester, List<String> texts, String query,
      {int steps = 0, bool scrollUpFirst = false}) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(texts));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ChatTranscript)));
    await container.read(chatControllerProvider.notifier).openThreadById('t1');
    await advance(tester);

    if (scrollUpFirst) {
      // 模拟用户往上滚过：follow 已松开，且不在底部。
      await tester.drag(find.byType(ChatTranscript), const Offset(0, 600));
      await advance(tester);
    }

    final n = container.read(findControllerProvider.notifier);
    n.show();
    await advance(tester, frames: 3);
    for (final ch in query.split('')) {
      n.setQuery(query.substring(0, query.indexOf(ch) + 1));
      await advance(tester, frames: 2);
    }
    n.setQuery(query);
    await advance(tester);
    for (var i = 0; i < steps; i++) {
      n.next();
      await advance(tester);
    }
  }

  void expectVisible(WidgetTester tester) {
    final y = currentMatchY(tester);
    expect(y, isNotNull, reason: '当前匹配必须被建出来');
    expect(y!.$1, greaterThanOrEqualTo(0));
    expect(y.$2, lessThanOrEqualTo(800));
  }

  final filler = '这是一段用来撑高度的话。' * 30;
  String md(String hit) => [
        '防火墙策略下发的主要优点包括：',
        for (var i = 0; i < 8; i++) ...[
          '**小标题$i**',
          '- 列表项甲$i，用来撑高度的一句比较长的话，用来撑高度的一句比较长的话',
          '- 列表项乙$i，用来撑高度的一句比较长的话',
        ],
        hit,
      ].join('\n\n');

  testWidgets('唯一匹配在最旧的一条（很远）→ 滚过去', (tester) async {
    final texts = ['开头有ZZ标记。$filler', for (var i = 0; i < 30; i++) filler];
    await run(tester, texts, 'ZZ');
    expect(container(tester).read(findControllerProvider).total, 1);
    expectVisible(tester);
  });

  testWidgets('唯一匹配在一条很高的消息的中段（已建出来但在视口外）', (tester) async {
    final texts = [
      for (var i = 0; i < 6; i++) filler,
      '${filler * 3}中段ZZ标记。${filler * 3}',
      filler,
    ];
    await run(tester, texts, 'ZZ');
    expectVisible(tester);
  });

  testWidgets('用户先往上滚过，再查 → 仍能滚到', (tester) async {
    final texts = [
      for (var i = 0; i < 3; i++) filler,
      '中段ZZ标记。$filler',
      for (var i = 0; i < 10; i++) filler,
    ];
    await run(tester, texts, 'ZZ', scrollUpFirst: true);
    expectVisible(tester);
  });

  testWidgets('markdown 回复：唯一匹配在末尾列表里，用户已往上滚', (tester) async {
    await run(tester, [md('- 末尾列表里有ZZ标记')], 'ZZ', scrollUpFirst: true);
    expectVisible(tester);
  });

  testWidgets('markdown 回复：未滚动直接查', (tester) async {
    await run(tester, [md('- 末尾列表里有ZZ标记')], 'ZZ');
    expectVisible(tester);
  });

  testWidgets('边打字边查：前一个字的滚动动画还在跑时输入下一个字', (tester) async {
    // 'Z' 到处都是（最新一条开头），'ZQ' 只出现在最旧的一条 —— 两者相距很远。
    final texts = [
      'ZQ只此一处。$filler',
      for (var i = 0; i < 10; i++) filler,
      for (var i = 0; i < 6; i++) 'Z开头的话。$filler',
    ];
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(texts));
    final c = container(tester);
    await c.read(chatControllerProvider.notifier).openThreadById('t1');
    await advance(tester);
    await tester.drag(find.byType(ChatTranscript), const Offset(0, 300));
    await advance(tester);

    final n = c.read(findControllerProvider.notifier);
    n.show();
    await advance(tester, frames: 3);
    n.setQuery('Z');
    await advance(tester, frames: 2); // 动画才走了几十毫秒
    n.setQuery('ZQ');
    await advance(tester);
    expect(c.read(findControllerProvider).total, 1);
    expectVisible(tester);
  });

  testWidgets('左栏的匹配数帧末才更新：定位不能读到上一个词的旧值', (tester) async {
    final texts = [
      'ZQ只此一处。$filler',
      for (var i = 0; i < 10; i++) filler,
    ];
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(texts));
    final c = container(tester);
    await c.read(chatControllerProvider.notifier).openThreadById('t1');
    await advance(tester);

    final n = c.read(findControllerProvider.notifier);
    n.show();
    n.setNavCount(3); // 上一个词（'Z'）在左栏的匹配数，此刻还是旧值
    await advance(tester, frames: 3);
    n.setQuery('ZQ');
    // 真实应用里 NavPanel 在 build 之后的帧末才把新词的匹配数（0）报上来。
    WidgetsBinding.instance.addPostFrameCallback((_) => n.setNavCount(0));
    await advance(tester);
    expect(c.read(findControllerProvider).total, 1);
    expectVisible(tester);
  });

  testWidgets('多个匹配逐个往下翻都在视口内', (tester) async {
    final texts = [
      for (var i = 0; i < 12; i++) '第$i段ZZ在这里。$filler',
    ];
    for (final steps in [0, 1, 5, 11]) {
      await run(tester, texts, 'ZZ', steps: steps);
      expectVisible(tester);
    }
  });
}

ProviderContainer container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ChatTranscript)));
