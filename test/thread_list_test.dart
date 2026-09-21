import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/thread_repository.dart';
import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';
import 'package:sgit_studio_flutter/features/chat/application/thread_list_controller.dart';
import 'package:sgit_studio_flutter/features/shell/application/history_sort_group_controller.dart';

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

  @override
  Future<ThreadReplay> open(String threadId) async => ThreadReplay(
        summary: ThreadSummary(
            id: threadId, title: 't', preview: '', createdAt: null, updatedAt: null),
        events: const [],
      );

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
        overrides: [threadRepositoryProvider.overrideWithValue(repo)],
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
}
