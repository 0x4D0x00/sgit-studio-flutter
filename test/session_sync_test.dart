import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/data/repositories/session_sync_repository.dart';
import 'package:sgit_studio_flutter/features/chat/application/session_sync_controller.dart';

/// 会话同步触发器的回归。
///
/// 同步本身在 Rust/Go 里；这一层只管**什么时候**触发，所以测的全是时机。

class _FakeRepo implements SessionSyncRepository {
  _FakeRepo({this.enabled = true});

  @override
  final bool enabled;

  int calls = 0;
  SessionSyncResult result = const SessionSyncResult(ok: true);
  Object? throws;

  @override
  Future<SessionSyncResult> sync() async {
    calls++;
    if (throws != null) throw throws!;
    return result;
  }

  /// 这组测的是**触发时机**，单条刷新不经过 SessionSyncController
  /// （它是 ChatController 点开会话时直接调仓储的），所以这里只要存在即可。
  @override
  Future<bool> refreshThread(String threadId) async => false;
}

void main() {
  test('一轮结束后去抖 30s 才推，连续几轮只推一次', () {
    fakeAsync((async) {
      final repo = _FakeRepo();
      final c = SessionSyncController(repo);

      c.onTurnCompleted();
      async.elapse(const Duration(seconds: 10));
      expect(repo.calls, 0, reason: '还在去抖窗口里');

      // 又一轮结束 —— 窗口重置，不该累积成两次。
      c.onTurnCompleted();
      async.elapse(const Duration(seconds: 25));
      expect(repo.calls, 0, reason: '第二轮重置了窗口');

      async.elapse(const Duration(seconds: 10));
      expect(repo.calls, 1, reason: '连续两轮最终只推一次');
    });
  });

  test('syncNow 立刻推，并取消待触发的去抖', () {
    fakeAsync((async) {
      final repo = _FakeRepo();
      final c = SessionSyncController(repo);

      c.onTurnCompleted();
      c.syncNow();
      async.flushMicrotasks();
      expect(repo.calls, 1);

      // 去抖那次已经被取消，不该再来一发。
      async.elapse(const Duration(seconds: 60));
      expect(repo.calls, 1, reason: 'syncNow 应取消待触发的去抖');
    });
  });

  // ⚠️ 两次并发推同一个文件会在 append 偏移上互相打架：服务端拒掉后一次，
  // 客户端再重试，白费一轮往返。
  test('并发调用合并成一次', () {
    fakeAsync((async) {
      final repo = _FakeRepo();
      final c = SessionSyncController(repo);

      c.syncNow();
      c.syncNow();
      c.syncNow();
      async.flushMicrotasks();
      expect(repo.calls, 1, reason: '在途时的重复调用应复用同一个 future');
    });
  });

  test('上一次结束后可以再推', () {
    fakeAsync((async) {
      final repo = _FakeRepo();
      final c = SessionSyncController(repo);

      c.syncNow();
      async.flushMicrotasks();
      c.syncNow();
      async.flushMicrotasks();
      expect(repo.calls, 2);
    });
  });

  // ⚠️ 服务端进程（或 Web）不该同步 —— 它自己就写在目标目录里。
  // 关着时**连 FFI 都不调**，省掉一次 isolate 往返。
  test('未启用时所有触发都是 no-op', () {
    fakeAsync((async) {
      final repo = _FakeRepo(enabled: false);
      final c = SessionSyncController(repo);

      c.onTurnCompleted();
      async.elapse(const Duration(minutes: 5));
      c.syncNow();
      async.flushMicrotasks();

      expect(repo.calls, 0, reason: '未启用时不该调到仓储');
      expect(c.enabled, isFalse);
    });
  });

  // 同步是后台行为，失败不该打扰用户，但也不能让它把异常抛进 UI。
  test('同步失败被吞掉，不向上抛', () {
    fakeAsync((async) {
      final repo = _FakeRepo()..throws = Exception('服务器不可达');
      final c = SessionSyncController(repo);

      // 不加 try/catch —— 抛出来的话这条测试会直接失败。
      c.syncNow();
      async.flushMicrotasks();
      expect(repo.calls, 1);
    });
  });

  test('dispose 后待触发的去抖不再执行', () {
    fakeAsync((async) {
      final repo = _FakeRepo();
      final c = SessionSyncController(repo);

      c.onTurnCompleted();
      c.dispose();
      async.elapse(const Duration(minutes: 5));
      expect(repo.calls, 0);
    });
  });

  group('结果解析', () {
    test('ok 为 true 时也可能带 reason（未启用是正常情形，不是错误）', () {
      final r = SessionSyncResult.fromJson(
          {'ok': true, 'reason': '本进程未启用会话同步'});
      expect(r.ok, isTrue);
      expect(r.reason, isNotNull);
    });

    test('计数字段缺失按 0 处理，不崩', () {
      final r = SessionSyncResult.fromJson({'ok': true});
      expect(r.uploaded, 0);
      expect(r.failed, 0);
    });
  });
}
