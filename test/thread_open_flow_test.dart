import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/data/repositories/thread_repository.dart';
import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';
import 'package:sgit_studio_flutter/services/chat/chat_ports.dart';
import 'package:sgit_studio_flutter/services/chat/thread_open_flow.dart';

ThreadReplay _replay(String id) => ThreadReplay(
  summary: ThreadSummary(
    id: id,
    title: 't',
    preview: '',
    createdAt: null,
    updatedAt: null,
  ),
  events: const [],
);

class _Repo implements ThreadRepository {
  _Repo(this.onOpen);
  final Future<ThreadReplay> Function(String id) onOpen;

  @override
  Future<ThreadReplay> open(String threadId) => onOpen(threadId);

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _Ports implements ChatPorts {
  _Ports(this.threadRepository, {this.mode = EngineMode.local, this.pull});

  @override
  final ThreadRepository threadRepository;
  final EngineMode mode;
  final bool Function(String id)? pull;
  final pulled = <String>[];

  @override
  EngineMode get engineMode => mode;

  @override
  Future<bool> refreshThread(String threadId) async {
    pulled.add(threadId);
    return pull?.call(threadId) ?? false;
  }

  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

void main() {
  late List<String> loaded;
  late List<Object> failed;
  late int generation;

  ThreadOpenFlow flow(ChatPorts ports) => ThreadOpenFlow(
    ports: ports,
    isStale: (gen) => gen != generation,
    onLoaded: (id, _) => loaded.add(id),
    onFailed: failed.add,
  );

  setUp(() {
    loaded = [];
    failed = [];
    generation = 1;
  });

  test('本地有 → 装配一次；后台问服务器没有更新则不重装', () async {
    final ports = _Ports(_Repo((id) async => _replay(id)));
    await flow(ports).run('a', 1);
    await Future<void>.delayed(Duration.zero);
    expect(loaded, ['a']);
    expect(failed, isEmpty);
    expect(ports.pulled, ['a']);
  });

  test('本地有且服务器有更新 → 再装配一次', () async {
    final ports = _Ports(_Repo((id) async => _replay(id)), pull: (_) => true);
    await flow(ports).run('a', 1);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(loaded, ['a', 'a']);
  });

  test('取数期间换了会话 → 静默丢弃，既不装配也不报错', () async {
    final ports = _Ports(
      _Repo((id) async {
        generation = 2;
        return _replay(id);
      }),
    );
    await flow(ports).run('a', 1);
    expect(loaded, isEmpty);
    expect(failed, isEmpty);
  });

  test('本地没有 → 云端模式不拉，直接报错', () async {
    final ports = _Ports(
      _Repo((_) async => throw Exception('missing')),
      mode: EngineMode.remote,
    );
    await flow(ports).run('a', 1);
    expect(ports.pulled, isEmpty);
    expect(loaded, isEmpty);
    expect(failed, hasLength(1));
  });

  test('本地没有 → 本地模式从服务器拉到后再打开', () async {
    var calls = 0;
    final ports = _Ports(
      _Repo((id) async {
        if (calls++ == 0) throw Exception('missing');
        return _replay(id);
      }),
      pull: (_) => true,
    );
    await flow(ports).run('a', 1);
    expect(loaded, ['a']);
    expect(failed, isEmpty);
  });

  test('拉回来仍打不开 → 报的是第二次的原因', () async {
    var calls = 0;
    final ports = _Ports(
      _Repo((_) async => throw Exception('err${calls++}')),
      pull: (_) => true,
    );
    await flow(ports).run('a', 1);
    expect(failed.single.toString(), contains('err1'));
  });
}
