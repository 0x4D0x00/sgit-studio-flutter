import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/features/chat/application/chat_ports_impl.dart';
import 'package:sgit_studio_flutter/app/app_providers.dart';
import 'package:sgit_studio_flutter/data/repositories/session_sync_repository.dart';
import 'package:sgit_studio_flutter/data/repositories/thread_repository.dart';
import 'fakes/kernel_client_mock.dart';
import 'package:sgit_studio_flutter/domain/models/artifact/artifact.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';
import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';
import 'package:sgit_studio_flutter/features/artifacts/application/artifacts_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/thread_list_controller.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';

/// 输出物与会话的同步。
///
/// 守三件事：会话里的长围栏会登记进输出物；重复登记不改 `updatedAt`、不重写；
/// 会话删了产物跟着走。点击跳转的定位逻辑在 widget 里，这里不覆盖。
ChatArtifact _chat(String content, {int start = 0, String lang = 'yaml'}) =>
    ChatArtifact(
      title: 'T',
      language: lang,
      content: content,
      kind: ArtifactKind.code,
      sourceStart: start,
    );

String _fence(String lang, int lines) =>
    '```$lang\n${List.generate(lines, (i) => 'k$i: v$i').join('\n')}\n```';

class _Repo implements ThreadRepository {
  _Repo(this.text);
  final String text;
  final deleted = <String>[];

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
            updatedAt: null),
        events: [
          {'t': 'userMessage', 'text': '帮我生成'},
          {'t': 'textStarted', 'itemId': 1},
          {'t': 'textDelta', 'itemId': 1, 'chunk': text},
          {'t': 'textCompleted', 'itemId': 1},
        ],
      );

  @override
  Future<void> rename(String threadId, String name) async {}

  @override
  Future<void> delete(String threadId) async => deleted.add(threadId);
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
  group('ArtifactsController', () {
    late ProviderContainer c;
    setUp(() {
      c = ProviderContainer();
      addTearDown(c.dispose);
    });
    ArtifactsController ctrl() => c.read(artifactsControllerProvider.notifier);
    List<Artifact> items() => c.read(artifactsControllerProvider).items;

    test('登记后出现；同一会话再登记一次，已有项保留原时间', () {
      final t0 = DateTime(2025, 1, 1);
      ctrl().replaceForThread('t1', [(artifact: _chat('a: 1'), at: t0)]);
      expect(items(), hasLength(1));
      expect(items().single.threadId, 't1');

      ctrl().replaceForThread('t1', [
        (artifact: _chat('a: 1'), at: DateTime(2030, 1, 1)),
        (artifact: _chat('b: 2', start: 9), at: DateTime(2030, 1, 1)),
      ]);
      expect(items(), hasLength(2));
      expect(items().firstWhere((a) => a.content == 'a: 1').updatedAt, t0,
          reason: '每次打开会话都变成"刚刚"是错的');
    });

    test('整体替换：重发丢掉的回复，它的产物一并消失；不影响别的会话', () {
      ctrl().replaceForThread('t1', [
        (artifact: _chat('a'), at: null),
        (artifact: _chat('b', start: 5), at: null),
      ]);
      ctrl().replaceForThread('t2', [(artifact: _chat('c'), at: null)]);

      ctrl().replaceForThread('t1', [(artifact: _chat('a'), at: null)]);

      expect(items().map((a) => a.content).toSet(), {'a', 'c'});
    });

    test('同内容不同偏移是两条（一条回答里两个相同的块）', () {
      ctrl().replaceForThread('t1', [
        (artifact: _chat('same'), at: null),
        (artifact: _chat('same', start: 40), at: null),
      ]);
      expect(items(), hasLength(2));
    });

    test('删会话 → 产物跟着走', () {
      ctrl().replaceForThread('t1', [(artifact: _chat('a'), at: null)]);
      ctrl().replaceForThread('t2', [(artifact: _chat('b'), at: null)]);
      ctrl().removeForThreads(['t1']);
      expect(items().map((a) => a.threadId), ['t2']);
    });

    test('JSON 往返不丢定位所需字段', () {
      ctrl().replaceForThread(
          't1', [(artifact: _chat('x: 1', start: 12, lang: 'yaml'), at: null)]);
      final a = items().single;
      final back = Artifact.fromJson(a.toJson());
      expect(back.id, a.id);
      expect(back.threadId, 't1');
      expect(back.sourceStart, 12);
      expect(back.content, 'x: 1');
      expect(back.toChatArtifact().sourceStart, 12);
    });
  });

  group('ChatController → 输出物', () {
    late ProviderContainer c;
    late _Repo repo;

    ProviderContainer make(String reply) {
      repo = _Repo(reply);
      final container = ProviderContainer(overrides: [
 chatPortsOverride,
        threadRepositoryProvider.overrideWithValue(repo),
        sessionSyncRepositoryProvider.overrideWithValue(_Sync()),
        chatControllerProvider
            .overrideWith(() => ChatController(client: MockKernelClient())),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('打开会话 → 回复里的长围栏登记到输出物，短的不登记', () async {
      c = make('说明\n\n${_fence('yaml', 40)}\n\n用法\n\n${_fence('bash', 3)}');

      await c.read(chatControllerProvider.notifier).openThreadById('t1');
      await Future<void>.delayed(Duration.zero); // 登记挪到了下一个事件循环

      final items = c.read(artifactsControllerProvider).items;
      expect(items, hasLength(1));
      expect(items.single.threadId, 't1');
      expect(items.single.language, 'yaml');
      expect(items.single.content, contains('k39: v39'));
    });

    test('点开时能还原成面板用的产物，偏移与聊天里的卡一致', () async {
      final reply = '说明\n\n${_fence('yaml', 40)}';
      c = make(reply);

      await c.read(chatControllerProvider.notifier).openThreadById('t1');
      await Future<void>.delayed(Duration.zero);

      final stored =
          c.read(artifactsControllerProvider).items.single.toChatArtifact();
      final inChat = ChatArtifact.fromBlocks(
          MarkdownParser.parse(reply), reply)
          .single;
      expect(stored.sourceStart, inChat.sourceStart);
      expect(stored.content, inChat.content);
    });

    test('载入期间换了会话 → 旧会话的内容不登记', () async {
      c = make(_fence('yaml', 40));
      final ctrl = c.read(chatControllerProvider.notifier);

      await ctrl.openThreadById('t1');
      ctrl.beginOpenThread('t2'); // 立刻切走，t1 的延后登记应作废
      await Future<void>.delayed(Duration.zero);

      expect(c.read(artifactsControllerProvider).items, isEmpty);
    });

    test('删会话 → 输出物里它的项一并清掉', () async {
      c = make(_fence('yaml', 40));
      await c.read(chatControllerProvider.notifier).openThreadById('t1');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(artifactsControllerProvider).items, hasLength(1));

      await c.read(threadListProvider.notifier).remove('t1');

      expect(c.read(artifactsControllerProvider).items, isEmpty);
    });
  });
}
