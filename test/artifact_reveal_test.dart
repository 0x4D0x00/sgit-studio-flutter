import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sgit_studio_flutter/core/storage/local_storage.dart';
import 'package:sgit_studio_flutter/data/repositories/session_sync_repository.dart';
import 'package:sgit_studio_flutter/data/repositories/thread_repository.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_mock.dart';
import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/domain/models/artifact/artifact.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';
import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';
import 'package:sgit_studio_flutter/features/artifacts/application/artifacts_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/thread_list_controller.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/chat_transcript.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/artifact_chip.dart';

/// 从输出物页点进会话后，文件卡要被**滚进视野**。
///
/// 列表是惰性的：目标离视口远时根本没建出来，没有 context 可 `ensureVisible`。
/// 这组测试守「逐步逼近」那条路 —— 会话够长（目标在几十屏之外）、内容晚于请求到达。
const _artifactTitle = '待办清单示例';

String _yaml(int lines) =>
    '$_artifactTitle，包含数据模型：\n\n```yaml\n${List.generate(lines, (i) => 'key$i: value$i').join('\n')}\n```';

class _Repo implements ThreadRepository {
  /// 第 0 条回复带文件卡（最旧、离底部最远），其后 [filler] 条是普通长段落。
  _Repo({this.filler = 60});
  final int filler;

  @override
  Future<ThreadPage> list({String? cursor}) async =>
      const ThreadPage(threads: []);

  @override
  Future<ThreadReplay> open(String threadId) async {
    final texts = [
      _yaml(40),
      for (var i = 0; i < filler; i++)
        '第 $i 条回复。${'这是一段用来撑高度的话。' * 40}',
    ];
    return ThreadReplay(
      summary: ThreadSummary(
          id: threadId,
          title: 't',
          preview: '',
          createdAt: null,
          updatedAt: null),
      events: [
        for (final (i, t) in texts.indexed) ...[
          {'t': 'textStarted', 'itemId': i},
          {'t': 'textDelta', 'itemId': i, 'chunk': t},
          {'t': 'textCompleted', 'itemId': i},
        ],
      ],
    );
  }

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

  Widget harness({int filler = 60}) => ProviderScope(
        overrides: [
          threadRepositoryProvider.overrideWithValue(_Repo(filler: filler)),
          sessionSyncRepositoryProvider.overrideWithValue(_Sync()),
          chatControllerProvider
              .overrideWith(() => ChatController(client: MockKernelClient())),
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

  /// 文件卡当前是否落在屏幕可见区域内。
  bool chipVisible(WidgetTester tester) {
    final f = find.byType(ArtifactChip);
    if (f.evaluate().isEmpty) return false;
    final r = tester.getRect(f.first);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    return r.top >= 0 && r.bottom <= screen.height;
  }

  testWidgets('目标在几十屏之外、会话内容晚于请求到达 → 仍能滚到文件卡', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness());
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ChatTranscript)));

    // 与输出物页点击时的顺序一致：先开会话（同步置载入态），再发定位请求。
    final chat = container.read(chatControllerProvider.notifier);
    final opening = chat.openThreadById('t1');
    container.read(artifactFocusProvider.notifier).request(Artifact(
          id: 'x',
          title: _artifactTitle,
          preview: '',
          language: 'yaml',
          updatedAt: DateTime(2025),
          threadId: 't1',
          content: List.generate(40, (i) => 'key$i: value$i').join('\n'),
          kind: ArtifactKind.code,
          // 偏移取聊天里实际那张卡的，和生产里存下来的一致。
          sourceStart: ChatArtifact.fromBlocks(
            MarkdownParser.parse(_yaml(40)),
            _yaml(40),
          ).single.sourceStart,
        ));
    await opening;
    await advance(tester);

    // 会话停在最新一条时，文件卡（最旧一条回复）在几十屏之外，根本没建出来。
    expect(chipVisible(tester), isTrue,
        reason: '逐步逼近完成后，文件卡应在可见区域内');
    expect(container.read(artifactFocusProvider), isNull,
        reason: '定位完成要清掉请求，否则之后每次内容变化都会再被拉回去');
  });

  testWidgets('找不到（会话里已经没有这张卡）→ 放弃定位并清请求，不死循环', (tester) async {
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(filler: 5));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ChatTranscript)));

    final opening =
        container.read(chatControllerProvider.notifier).openThreadById('t1');
    container.read(artifactFocusProvider.notifier).request(Artifact(
          id: 'gone',
          title: 'x',
          preview: '',
          language: 'yaml',
          updatedAt: DateTime(2025),
          threadId: 't1',
          content: '会话里没有的内容',
        ));
    await opening;
    await advance(tester);

    expect(container.read(artifactFocusProvider), isNull);
  });
}
