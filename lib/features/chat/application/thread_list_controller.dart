import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/thread_repository.dart';
import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';

/// 会话仓储。**跟着引擎模式重建** —— 切了云端还挂着本地那份列表就错了。
///
/// ⚠️ 测试里必须 `overrideWithValue`：桌面工厂会 dlopen `sgit_ffi.dll`，
/// 测试环境没有那个库，一调就挂。
final threadRepositoryProvider = Provider<ThreadRepository>((ref) {
  // watch 而不是 read：engineMode 变了要重建仓储，否则列表停在上一个引擎的结果。
  ref.watch(composerSettingsProvider.select((s) => s.settings.engineMode));
  return createThreadRepository();
});

@immutable
class ThreadListState {
  const ThreadListState({
    this.items = const [],
    this.loading = true,
    this.error,
  });

  final List<ThreadSummary> items;
  final bool loading;

  /// 取列表失败的原因。会话列表**是页面主内容**，取不到必须说 ——
  /// 与模型列表那种"取不到就悄悄用默认"的附属数据不同。
  final String? error;

  ThreadListState copyWith({
    List<ThreadSummary>? items,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      ThreadListState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

/// 历史会话列表。
///
/// ## 数据源就是 sgcode 的 thread，不是场景
///
/// 这个 controller 存在的直接原因：左栏「历史对话」原先列的是
/// `resourceListProvider(StudioPageSpecs.scenes)` —— **场景标签**，不是会话。
/// 后果不止是显示错：那时"删除历史条目"调的是
/// `resourceListProvider(scenes).remove(sceneId)`，**删掉的是场景定义本身**。
class ThreadListController extends Notifier<ThreadListState> {
  bool _disposed = false;

  /// 本地写操作（改名/删除）的代次。
  ///
  /// ⚠️ **防止在途的 reload 把刚做完的本地改动盖回去。**
  ///
  /// `build()` 里排的首屏 reload 是异步的，用户完全可能在它落地之前就改了名 ——
  /// 那次 reload 回来的是**改名之前**的服务器数据，一写进 state 就把乐观更新
  /// 抹掉了，界面上表现为"改了名，一闪又变回去"。写测试时先撞上的正是这个。
  ///
  /// 做法：每次本地写 +1；reload 取数前记下代次，回来时若已经变了就只清
  /// loading、不覆盖 items（那份数据已经过时）。
  int _localEdits = 0;

  @override
  ThreadListState build() {
    ref.onDispose(() => _disposed = true);

    // 引擎模式变了要重新拉：两个引擎的会话是两份不相干的历史。
    ref.listen(
      composerSettingsProvider.select((s) => s.settings.engineMode),
      (prev, next) {
        if (prev != next) unawaited(reload());
      },
    );

    // ⚠️ **等内核连上再拉**，别在 build 里直接 `Future.microtask(reload)`。
    //
    // 会话列表要经内核（本地走进程内 app-server，云端走 gateway），而建连是
    // `workspace_page` 触发的、异步的 —— 两者没有先后关系，列表必然抢跑：
    //
    // ```text
    // build() → reload() → 「尚未建立内核连接」→ 列表空
    // 稍后     → 建连成功 → 但没人再拉一次 → 列表一直空
    // ```
    //
    // 实测表现正是「**每次重启后要手动切一下引擎才看到历史**」—— 因为切引擎
    // 触发了上面那个 listen，那才是唯一的第二次 reload。
    //
    // 现在改成监听 capabilities：它从 null 变成非 null 就是"连上了"，那一刻拉。
    // 同一次连接不会重复触发（只在 null→非null 的边沿动），所以不会变成风暴。
    ref.listen(
      chatControllerProvider.select((s) => s.capabilities != null),
      (was, now) {
        if (now == true && was != true) unawaited(reload());
      },
      // 已经连上时（provider 晚于连接创建，比如从别的页回到工作台）立刻拉一次，
      // 否则要等下一次断连重连才有边沿。
      fireImmediately: true,
    );
    return const ThreadListState();
  }

  Future<void> reload() async {
    if (_disposed) return;
    final editsAtStart = _localEdits;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await ref.read(threadRepositoryProvider).list();
      if (_disposed) return;

      // 取数期间有本地写 → 这份结果已过时，丢掉（见 _localEdits 的注释）。
      if (_localEdits != editsAtStart) {
        debugPrint('[threads] 取数期间有本地改动，丢弃这批过时结果');
        state = state.copyWith(loading: false);
        return;
      }

      // ⚠️ **空结果不盖掉已有内容**，除非我们本来就没有。
      //
      // `model_list_controller.dart` 栽过这个：一次失败的刷新返回空列表，被
      // 无条件写进 state，用户眼看着已经显示出来的东西消失。这里同理 ——
      // 本地引擎刚重连、云沙箱还在冷启动时，列表都可能瞬时为空。
      //
      // 判据是"这次取到的是不是空 + 我们手上有没有旧的"，不是"有没有报错"：
      // 取到空且不报错是完全可能的（引擎刚起来还没扫完）。
      if (page.threads.isEmpty && state.items.isNotEmpty) {
        debugPrint('[threads] 本次取到 0 条，保留上次的 ${state.items.length} 条');
        state = state.copyWith(loading: false);
        return;
      }
      state = ThreadListState(items: page.threads, loading: false);
    } catch (e) {
      if (_disposed) return;
      // ⚠️ 必须留日志。只塞进 state 的话，排查时得有人正好盯着界面才看得见。
      debugPrint('[threads] 取会话列表失败：${_msg(e)}');
      state = state.copyWith(loading: false, error: _msg(e));
    }
  }

  /// 改标题。乐观更新 —— 失败回滚并报错（用户主动写，不能静默）。
  Future<void> rename(String threadId, String name) async {
    _localEdits++;
    final prev = state.items;
    state = state.copyWith(
      items: [
        for (final t in prev)
          if (t.id == threadId)
            ThreadSummary(
              id: t.id,
              title: name.trim().isEmpty ? t.preview : name,
              preview: t.preview,
              createdAt: t.createdAt,
              updatedAt: t.updatedAt,
              cwd: t.cwd,
            )
          else
            t,
      ],
      clearError: true,
    );
    try {
      await ref.read(threadRepositoryProvider).rename(threadId, name);
    } catch (e) {
      if (_disposed) return;
      debugPrint('[threads] 改名失败：${_msg(e)}');
      state = state.copyWith(items: prev, error: _msg(e));
    }
  }

  /// 删一条。**删的是会话，不是场景**（见类注释）。
  Future<void> remove(String threadId) async {
    _localEdits++;
    final prev = state.items;
    state = state.copyWith(
      items: prev.where((t) => t.id != threadId).toList(growable: false),
      clearError: true,
    );
    try {
      await ref.read(threadRepositoryProvider).delete(threadId);
    } catch (e) {
      if (_disposed) return;
      debugPrint('[threads] 删除失败：${_msg(e)}');
      state = state.copyWith(items: prev, error: _msg(e));
    }
  }

  Future<void> removeMany(List<String> ids) async {
    for (final id in ids) {
      await remove(id);
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final threadListProvider =
    NotifierProvider<ThreadListController, ThreadListState>(
  ThreadListController.new,
);

String _msg(Object e) =>
    e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
