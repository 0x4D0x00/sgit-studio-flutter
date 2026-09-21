import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';

import 'package:sgit_studio_flutter/data/repositories/session_sync_repository.dart';
import 'package:sgit_studio_flutter/data/repositories/thread_repository.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_mock.dart';
import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/thread_list_controller.dart';
import 'package:sgit_studio_flutter/features/shell/application/history_sort_group_controller.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';

/// 历史会话列表的回归。
///
/// ## 这组测试为什么存在
///
/// 左栏「历史对话」原先列的是**场景标签**而不是会话，而且"删除历史条目"调的是
/// `resourceListProvider(scenes).remove(sceneId)` —— **删掉的是场景定义本身**。
/// 换成真 thread 之后，这里钉住几个换过程中最容易再犯的静默失效点。

class _FakeThreadRepository implements ThreadRepository {
  _FakeThreadRepository({this.page, this.throws});

  ThreadPage? page;
  Object? throws;

  final deleted = <String>[];
  final renamed = <(String, String)>[];

  @override
  Future<ThreadPage> list({String? cursor}) async {
    if (throws != null) throw throws!;
    return page ?? const ThreadPage(threads: []);
  }

  /// 挂住 `open`，用来断言"内容还没回来时的状态"。用例自己 complete。
  Completer<void>? openGate;

  /// 让 `open` 抛错（与 [throws] 分开：那个是 list/rename/delete 的）。
  Object? openThrows;

  /// `open` 被调了几次。"服务器有更新才重装"就是靠这个数断言的。
  int opens = 0;

  @override
  Future<ThreadReplay> open(String threadId) async {
    opens++;
    if (openGate != null) await openGate!.future;
    if (openThrows != null) throw openThrows!;
    return ThreadReplay(
      summary: ThreadSummary(
          id: threadId, title: 't', preview: '', createdAt: null, updatedAt: null),
      events: const [],
    );
  }

  @override
  Future<void> rename(String threadId, String name) async {
    if (throws != null) throw throws!;
    renamed.add((threadId, name));
  }

  @override
  Future<void> delete(String threadId) async {
    if (throws != null) throw throws!;
    deleted.add(threadId);
  }
}

/// 只实现"单条刷新"，其余是这组用不到的门面。
class _FakeSyncRepository implements SessionSyncRepository {
  /// `refreshThread` 要回报"有没有拉到新内容"。
  bool changed = false;
  final refreshed = <String>[];

  @override
  bool get enabled => true;

  @override
  Future<SessionSyncResult> sync() async => const SessionSyncResult(ok: true);

  @override
  Future<bool> refreshThread(String threadId) async {
    refreshed.add(threadId);
    return changed;
  }
}

ThreadSummary _t(String id, {String? title, DateTime? updated}) => ThreadSummary(
      id: id,
      title: title ?? id,
      preview: '',
      createdAt: updated,
      updatedAt: updated,
    );

void main() {
  group('时间解析', () {
    // ⚠️ sgcode 给的是 **Unix 秒的整数**。而列表原先用
    // `DateTime.parse(extra('updatedAt'))` —— 喂整数会抛异常、被 catch 成
    // epoch 0，于是所有会话都落进"更早"、排序全乱，**一行日志都没有**。
    test('Unix 秒整数要能解出正确时间', () {
      final t = ThreadSummary.fromJson({'id': 'a', 'updatedAt': 1758412800});
      expect(t.updatedAt, DateTime.fromMillisecondsSinceEpoch(1758412800 * 1000));
    });

    test('字符串形态的数字也要认（某些 JSON 编码器会这么给）', () {
      final t = ThreadSummary.fromJson({'id': 'a', 'updatedAt': '1758412800'});
      expect(t.updatedAt, isNotNull);
    });

    // ⚠️ 缺时间戳必须是 **null，不能是 epoch 0** —— 用 epoch 0 顶替会把
    // "数据缺失"伪装成"很老的会话"，排序时它们会假装自己最早。
    test('缺失/非法时间是 null，不是 epoch 0', () {
      for (final v in [null, '', 'not-a-number', 0, -1]) {
        final t = ThreadSummary.fromJson({'id': 'a', 'updatedAt': v});
        expect(t.updatedAt, isNull, reason: '$v 应解成 null');
      }
    });
  });

  group('排序与分组', () {
    test('按最近活动降序，缺时间的排最后', () {
      final now = DateTime.now();
      final items = [
        _t('old', updated: now.subtract(const Duration(days: 3))),
        _t('none'),
        _t('new', updated: now),
      ];
      final g = sortAndGroupHistory(
          items, ChatSortBy.lastActivity, ChatGroupBy.none, (k) => k);
      expect(g.single.items.map((e) => e.id).toList(), ['new', 'old', 'none']);
    });

    test('分组只有三档：今天 / 昨天 / 更早', () {
      final now = DateTime.now();
      final items = [
        _t('a', updated: now),
        _t('b', updated: now.subtract(const Duration(days: 1))),
        _t('c', updated: now.subtract(const Duration(days: 30))),
      ];
      final g = sortAndGroupHistory(
          items, ChatSortBy.lastActivity, ChatGroupBy.date, (k) => k);
      expect(g.map((e) => e.groupKey).toList(), ['today', 'yesterday', 'older']);
    });

    test('缺时间的单独成组，不混进"更早"装成老会话', () {
      final g = sortAndGroupHistory(
          [_t('x')], ChatSortBy.lastActivity, ChatGroupBy.date, (k) => k);
      expect(g.single.groupKey, 'unknown');
    });
  });

  group('列表控制器', () {
    late _FakeThreadRepository repo;
    late ProviderContainer container;

    setUp(() {
      repo = _FakeThreadRepository();
      container = ProviderContainer(
        overrides: [
          threadRepositoryProvider.overrideWithValue(repo),
          // ⚠️ **必须注入假内核**。列表控制器 `build()` 里 listen 了
          // `chatControllerProvider`（等连上再拉，见那边的注释），于是一读
          // 列表就会把真 ChatController 建起来 —— 它 dlopen `sgit_ffi.dll`，
          // 测试环境没那个库，八个用例一起挂。
          //
          // 用 MockKernelClient 而不是自己写一个空壳：别的 UI 测试
          // （chat_ui / composer_ui / layout）都走这条，一致。
          chatControllerProvider
              .overrideWith(() => ChatController(client: MockKernelClient())),
        ],
      );
      addTearDown(container.dispose);
    });

    // ⚠️ `model_list_controller` 栽过这个：一次刷新返回空列表被无条件写进
    // state，用户眼看着已显示的内容消失。本地引擎刚重连、云沙箱冷启动时
    // 列表都可能瞬时为空。
    test('空结果不盖掉已有内容', () async {
      repo.page = ThreadPage(threads: [_t('a'), _t('b')]);
      await container.read(threadListProvider.notifier).reload();
      expect(container.read(threadListProvider).items, hasLength(2));

      repo.page = const ThreadPage(threads: []);
      await container.read(threadListProvider.notifier).reload();
      expect(container.read(threadListProvider).items, hasLength(2),
          reason: '取到 0 条时应保留上次的结果');
    });

    test('本来就是空时，空结果正常写入（不是永远留着旧的）', () async {
      repo.page = const ThreadPage(threads: []);
      await container.read(threadListProvider.notifier).reload();
      expect(container.read(threadListProvider).items, isEmpty);
    });

    // 会话列表是页面主内容，取不到必须报 —— 与模型列表那种"悄悄用默认"不同。
    test('取列表失败要进 error 态', () async {
      repo.throws = Exception('引擎未就绪');
      await container.read(threadListProvider.notifier).reload();
      final s = container.read(threadListProvider);
      expect(s.error, contains('引擎未就绪'));
      expect(s.loading, isFalse);
    });

    test('删除调的是会话接口，传的是裸 threadId', () async {
      repo.page = ThreadPage(threads: [_t('t1'), _t('t2')]);
      await container.read(threadListProvider.notifier).reload();

      await container.read(threadListProvider.notifier).remove('t1');
      expect(repo.deleted, ['t1'], reason: '应删会话本身，且 id 不带前缀');
      expect(container.read(threadListProvider).items.map((e) => e.id), ['t2']);
    });

    test('删除失败要回滚，不能让条目假装已删', () async {
      repo.page = ThreadPage(threads: [_t('t1')]);
      await container.read(threadListProvider.notifier).reload();

      repo.throws = Exception('网络断了');
      await container.read(threadListProvider.notifier).remove('t1');
      final s = container.read(threadListProvider);
      expect(s.items.map((e) => e.id), ['t1'], reason: '失败要把条目放回来');
      expect(s.error, contains('网络断了'));
    });

    // ⚠️ **在途的 reload 不能盖掉刚做完的本地改动。**
    //
    // `build()` 里排的首屏 reload 是异步的，用户完全可能在它落地之前就改了名
    // —— 那次 reload 回来的是改名**之前**的服务器数据，一写进 state 就把乐观
    // 更新抹掉，界面上是"改了名，一闪又变回去"。写上面那条改名测试时先撞上的
    // 正是这个，它是生产也会中的竞态，不是测试写法问题。
    test('取数期间的本地改动不被在途 reload 覆盖', () async {
      repo.page = ThreadPage(threads: [_t('t1', title: '旧名')]);
      final n = container.read(threadListProvider.notifier);
      await n.reload();

      // 手动制造竞态：reload 取数还没回来时就改名。
      final slow = n.reload();
      await n.rename('t1', '新名');
      await slow;

      expect(container.read(threadListProvider).items.single.title, '新名',
          reason: '过时的 reload 结果必须被丢弃');
    });

    test('改名乐观更新，失败回滚', () async {
      repo.page = ThreadPage(threads: [_t('t1', title: '旧名')]);
      await container.read(threadListProvider.notifier).reload();

      await container.read(threadListProvider.notifier).rename('t1', '新名');
      expect(repo.renamed, [('t1', '新名')]);
      expect(container.read(threadListProvider).items.single.title, '新名');

      repo.throws = Exception('写失败');
      await container.read(threadListProvider.notifier).rename('t1', '更新的名');
      expect(container.read(threadListProvider).items.single.title, '新名',
          reason: '失败要回滚到上一个标题');
    });
  });

  /// 点开历史会话 = **先进页面，内容后到**。
  ///
  /// 用户反馈的原话是「点历史会话要过很久才能进 L2 页面」。原先
  /// `history_page._pick` 是 `await open()` 之后才 `context.go` —— 内容不回来
  /// 页面就不动，长会话下就是干等，而且没有任何反馈。
  ///
  /// 这组钉住改完之后的三件事，每一件失效都会让那个症状原样回来，且**界面上
  /// 看不出是回归**（只是"又变慢了"）。
  group('打开历史会话', () {
    late _FakeThreadRepository repo;
    late _FakeSyncRepository sync;
    late ProviderContainer container;

    setUp(() {
      repo = _FakeThreadRepository();
      sync = _FakeSyncRepository();
      container = ProviderContainer(
        overrides: [
          threadRepositoryProvider.overrideWithValue(repo),
          sessionSyncRepositoryProvider.overrideWithValue(sync),
          chatControllerProvider
              .overrideWith(() => ChatController(client: MockKernelClient())),
        ],
      );
      addTearDown(container.dispose);
    });

    // ⚠️ **provider 建立时连接已经在了** —— 从别的页回工作台就是这条路。
    //
    // 列表控制器靠 `ref.listen(capabilities != null, fireImmediately: true)`
    // 在"连上那一刻"拉数据。而 fireImmediately 的回调是在 `build()` **内部**
    // 同步触发的：那时 `state` 还没赋值，`reload()` 第一行读 state 就抛
    // `Bad state: Tried to read the state of an uninitialized provider`。
    //
    // 异常被 riverpod 的 listener guard 吞掉，界面上只是**列表空白** ——
    // 与"还没连上"完全无法区分。所以必须有测试。
    test('建立时连接已存在：首屏自己会拉，且不炸在未初始化的 state 上', () async {
      repo.page = ThreadPage(threads: [_t('a'), _t('b')]);
      // 先把连接建起来，让 capabilities 非空，再第一次读列表 provider。
      await container.read(chatControllerProvider.notifier).connect();

      expect(container.read(threadListProvider).items, isEmpty,
          reason: 'build 刚回来，拉取还没跑');

      await Future<void>.delayed(Duration.zero);
      expect(container.read(threadListProvider).items, hasLength(2),
          reason: '连接已在时首屏必须自己拉一次，不能等用户去切引擎');
    });

    // ⚠️ 这条是整个修复的支点。调用方的写法是
    //   `unawaited(openThreadById(id)); context.go(home);`
    // 它成立的前提是**清空 + 置位发生在首个 await 之前**（Dart 的 async 函数体
    // 在首个 await 前同步执行）。哪天有人在 beginOpenThread() 之前插一个
    // await（比如加个 `await someCheck()`），跳过去的那一瞬工作台就还是上一条
    // 会话的残留内容 —— 闪一下再清空，比慢更糟，而测不到。
    test('置"正在载入"是同步的，不等 open 返回', () {
      repo.openGate = Completer<void>();
      final ctrl = container.read(chatControllerProvider.notifier);

      unawaited(ctrl.openThreadById('t1')); // 故意不 await

      expect(container.read(chatControllerProvider).openingThread, isTrue,
          reason: '调用方紧接着就要 context.go，此刻必须已经是载入态');
    });

    test('载入完成后清掉载入态', () async {
      final ctrl = container.read(chatControllerProvider.notifier);
      await ctrl.openThreadById('t1');
      expect(container.read(chatControllerProvider).openingThread, isFalse);
      expect(container.read(chatControllerProvider).fault, isNull);
    });

    // ⚠️ 失败必须落进 state，不能只 debugPrint。发起点（历史页/左栏）在
    // `context.go` 之后已经卸载，弹不了 SnackBar —— 不落 state 就等于静默失败，
    // 用户只看到一个永远转圈的载入态。
    test('打开失败要报出来，且不卡在载入态', () async {
      repo.openThrows = Exception('会话不存在');
      final ctrl = container.read(chatControllerProvider.notifier);

      await ctrl.openThreadById('t1');

      final s = container.read(chatControllerProvider);
      expect(s.openingThread, isFalse, reason: '失败也要退出载入态，否则永远转圈');
      expect(s.fault, isA<ThreadOpenFailed>());
      expect((s.fault! as ThreadOpenFailed).message, contains('会话不存在'));
    });
  });

  /// 「先从本地加载，然后线上拉取，更新本地数据，页面刷新」的后半截。
  ///
  /// 这条会话可能是在另一台设备上聊的，本机那份 rollout 停在旧偏移。但先等
  /// 服务器再显示就退回了"点开要等很久"，所以顺序是本地秒回 → 后台问 →
  /// 真有新内容才重装。
  group('打开后从服务器刷新', () {
    late _FakeThreadRepository repo;
    late _FakeSyncRepository sync;
    late ProviderContainer container;

    setUp(() {
      repo = _FakeThreadRepository();
      sync = _FakeSyncRepository();
      container = ProviderContainer(
        overrides: [
          threadRepositoryProvider.overrideWithValue(repo),
          sessionSyncRepositoryProvider.overrideWithValue(sync),
          chatControllerProvider
              .overrideWith(() => ChatController(client: MockKernelClient())),
        ],
      );
      addTearDown(container.dispose);
    });

    // ⚠️ **无更新时绝不能重装**。重装会重建所有气泡、把滚动位置顶回顶部。
    // 绝大多数情况服务器没有新东西（就是本机自己聊的那条），无条件重装
    // 等于每次点开都白闪一下 —— 而这种"偶尔闪一下"极难被当成 bug 报上来。
    test('服务器没有更新 → 只打开一次，不重装', () async {
      sync.changed = false;
      await container.read(chatControllerProvider.notifier).openThreadById('t1');
      await Future<void>.delayed(Duration.zero);

      expect(sync.refreshed, ['t1'], reason: '该问服务器一次');
      expect(repo.opens, 1, reason: '没有更新就不该再 open 一次');
    });

    test('服务器有更新 → 重新装配一次', () async {
      sync.changed = true;
      await container.read(chatControllerProvider.notifier).openThreadById('t1');
      await Future<void>.delayed(Duration.zero);

      expect(repo.opens, 2, reason: '本地一次 + 拿到更新后重装一次');
    });

    // ⚠️ 刷新是后台跑的，用户完全可能在它回来之前就点了另一条会话或开了新对话。
    // 往一个**已经换掉**的会话里灌内容，比不刷新糟得多：屏幕上会突然冒出
    // 上一条会话的消息，而用户根本没点它。
    // ⚠️ 云端模式下会话**就在服务器上**，thread/resume 读到的就是最新那份。
    // 不判断的话这一步会把服务器文件下到本机（白做），再因为"本地确实变长了"
    // 报 changed=true 触发重装 —— 云端点开每一条都白闪一下。
    test('云端模式不做本地刷新', () async {
      sync.changed = true;
      container
          .read(composerSettingsProvider.notifier)
          .setEngineMode(EngineMode.remote);

      await container.read(chatControllerProvider.notifier).openThreadById('t1');
      await Future<void>.delayed(Duration.zero);

      expect(sync.refreshed, isEmpty, reason: '云端模式压根不该问本地同步');
      expect(repo.opens, 1);
    });

    test('刷新回来时用户已切走 → 不灌内容', () async {
      sync.changed = true;
      final ctrl = container.read(chatControllerProvider.notifier);

      // 让 refreshThread 慢一拍，中间把会话切走。
      await ctrl.openThreadById('t1');
      ctrl.newChat(); // 用户开了新对话
      await Future<void>.delayed(Duration.zero);

      expect(repo.opens, 1, reason: '已经切走，不该为旧会话再 open');
    });
  });
}
