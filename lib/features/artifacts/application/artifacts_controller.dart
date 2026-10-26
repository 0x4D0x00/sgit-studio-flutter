import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/core/storage/local_storage.dart';
import 'package:sgit_studio_flutter/domain/models/artifact/artifact.dart';
import 'package:sgit_studio_flutter/services/chat/chat_ports.dart';

/// 产物列表状态。
@immutable
class ArtifactsState {
  const ArtifactsState({
    this.items = const [],
    this.typeFilter,
    this.searchQuery = '',
    this.loading = false,
  });

  final List<Artifact> items;

  /// 类型过滤器。null = 全部类型，'other' = 其他。
  final String? typeFilter;

  final String searchQuery;
  final bool loading;

  /// 应用过滤后的结果。
  List<Artifact> get filtered {
    var result = items;

    // 类型过滤：只有 'other' 需要过滤（null 表示全部，显示所有）
    if (typeFilter == 'other') {
      result = result.where((a) => a.language == 'other').toList();
    }

    // 搜索过滤（标题）
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      result = result.where((a) => a.title.toLowerCase().contains(q)).toList();
    }

    return result;
  }

  ArtifactsState copyWith({
    List<Artifact>? items,
    String? Function()? typeFilter,
    String? searchQuery,
    bool? loading,
  }) =>
      ArtifactsState(
        items: items ?? this.items,
        typeFilter: typeFilter != null ? typeFilter() : this.typeFilter,
        searchQuery: searchQuery ?? this.searchQuery,
        loading: loading ?? this.loading,
      );
}

/// 产物列表控制器。
///
/// 数据来源是会话：`ChatController` 在会话载入 / 一轮结束后调 [replaceForThread]，
/// 把那条会话里的文件卡整体登记进来。列表落盘（[LocalStorage]），重启后仍在。
class ArtifactsController extends Notifier<ArtifactsState> {
  @override
  ArtifactsState build() => ArtifactsState(items: _load());

  List<Artifact> _load() {
    final raw = LocalStorage.maybeInstance?.artifacts;
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final e in list) Artifact.fromJson(e as Map<String, dynamic>),
      ];
    } catch (e) {
      // 落盘格式坏了不该让整页打不开 —— 丢掉，下次会话载入会重新登记。
      debugPrint('[artifacts] 读取本地列表失败，已忽略：$e');
      return const [];
    }
  }

  void _save(List<Artifact> items) {
    final storage = LocalStorage.maybeInstance;
    if (storage == null) return;
    unawaited(storage.setArtifacts(
      jsonEncode([for (final a in items) a.toJson()]),
    ));
  }

  /// 用 [found] **整体替换**某条会话的产物。
  ///
  /// 整体替换而不是追加：编辑重发会丢掉后面的回复，那些回复里的文件卡也
  /// 该一并消失。已存在的项（id 相同）保留原 `updatedAt`，新出现的用 [found]
  /// 给的时间。
  void replaceForThread(String threadId, List<FoundArtifact> found) {
    final old = {
      for (final a in state.items)
        if (a.threadId == threadId) a.id: a,
    };
    final now = DateTime.now();
    final fresh = <Artifact>[];
    final seen = <String>{};
    for (final f in found) {
      final a = Artifact.fromChat(threadId, f.artifact, f.at ?? now);
      if (!seen.add(a.id)) continue;
      fresh.add(old[a.id] ?? a);
    }

    // 没变化就不动 —— 每轮结束都会调，别无谓地重写磁盘、重建页面。
    final unchanged =
        old.length == fresh.length && fresh.every((a) => old.containsKey(a.id));
    if (unchanged) return;

    // 按更新时间倒序：最近的在最前。
    final items = [
      ...state.items.where((a) => a.threadId != threadId),
      ...fresh,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = state.copyWith(items: items);
    _save(items);
  }

  /// 会话被删了，它的产物跟着走 —— 留着只会得到一个点不开的条目。
  void removeForThreads(Iterable<String> threadIds) {
    final ids = threadIds.toSet();
    if (!state.items.any((a) => ids.contains(a.threadId))) return;
    final items = state.items.where((a) => !ids.contains(a.threadId)).toList();
    state = state.copyWith(items: items);
    _save(items);
  }

  void setTypeFilter(String? language) {
    state = state.copyWith(typeFilter: () => language);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final artifactsControllerProvider =
    NotifierProvider<ArtifactsController, ArtifactsState>(
  ArtifactsController.new,
);

/// 「从输出物页跳回会话」的定位请求。
///
/// 点卡片时置位；`ChatTranscript` 在会话内容到齐后把对应的文件卡滚进视野，
/// 然后清掉。放在 provider 里是因为发起方（输出物页）与执行方（对话流）
/// 不在同一棵子树，且跳转时对话页还没挂载。
class ArtifactFocusController extends Notifier<Artifact?> {
  @override
  Artifact? build() => null;

  void request(Artifact a) => state = a;
  void clear() => state = null;
}

final artifactFocusProvider =
    NotifierProvider<ArtifactFocusController, Artifact?>(
  ArtifactFocusController.new,
);
