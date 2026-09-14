import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/gateway_repository.dart';
import 'package:sgit_studio_flutter/domain/models/studio/resource_item.dart';
import 'package:sgit_studio_flutter/features/studio/application/kernel_client_provider.dart';
import 'package:sgit_studio_flutter/features/studio/studio_page_specs.dart';

/// 一个 studio 页面的数据状态。**三态齐全**（加载中 / 出错 / 数据），
/// 而且 [stale] 让界面能标出"这是缓存，正在刷新"。
@immutable
class ResourceListState {
  const ResourceListState({
    this.items = const [],
    this.loading = true,
    this.stale = false,
    this.error,
  });

  final List<ResourceItem> items;
  final bool loading;

  /// 当前显示的是本地缓存，后端还在路上。
  final bool stale;

  final String? error;

  ResourceListState copyWith({
    List<ResourceItem>? items,
    bool? loading,
    bool? stale,
    String? error,
    bool clearError = false,
  }) =>
      ResourceListState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        stale: stale ?? this.stale,
        error: clearError ? null : (error ?? this.error),
      );
}

/// 通用资源页控制器。**7 个页面共用这一个**，各页只是一份 [ResourcePageSpec]。
class ResourceListController
    extends FamilyNotifier<ResourceListState, ResourcePageSpec> {
  late final GatewayRepository _repo =
      GatewayRepository(ref.read(kernelClientProvider));

  @override
  ResourceListState build(ResourcePageSpec arg) {
    // 首次进页面就拉。刷新按钮走 reload()。
    Future.microtask(reload);
    return const ResourceListState();
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      // 这些列表端点是 GET，没有 cache/sync 两态（数据本来就在本地 .sgitai 目录，
      // 读的就是"本地"）。真正需要 SWR 的是中转站那种要打后端的，见 RelayController。
      final data = await _repo.fetch(arg.listPath);
      state = ResourceListState(
        items: _parse(data),
        loading: false,
        stale: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: _msg(e));
    }
  }

  Future<void> remove(String id) async {
    final path = arg.removePath;
    if (path == null) return;
    try {
      await _repo.post(path, {'id': id});
      await reload();
    } catch (e) {
      state = state.copyWith(error: _msg(e));
    }
  }

  /// 批量删除（历史对话「全选删除」用）。逐个调用现有的单删端点 ——
  /// 后端没有批量接口，串行发是唯一安全的做法；结束后统一 reload 一次，
  /// 不必每删一条就刷一次列表。
  Future<void> removeMany(Iterable<String> ids) async {
    final path = arg.removePath;
    if (path == null) return;
    try {
      for (final id in ids) {
        await _repo.post(path, {'id': id});
      }
      await reload();
    } catch (e) {
      state = state.copyWith(error: _msg(e));
    }
  }

  Future<void> refreshOne(String id) async {
    final path = arg.refreshPath;
    if (path == null) return;
    try {
      await _repo.post(path, {'id': id});
      await reload();
    } catch (e) {
      state = state.copyWith(error: _msg(e));
    }
  }

  List<ResourceItem> _parse(Map<String, Object?> data) {
    final raw = data[arg.listField];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) {
      final r = m.cast<String, Object?>();
      return ResourceItem(
        id: r[arg.idField]?.toString() ?? '',
        name: r[arg.nameField]?.toString() ?? '',
        description: r[arg.descField]?.toString() ?? '',
        enabled: switch (arg.enabledField) {
          final String f => r[f] == true || r[f] == 1,
          null => null,
        },
        extras: {for (final f in arg.extraFields) f: r[f]},
      );
    }).toList(growable: false);
  }
}

final resourceListProvider = NotifierProvider.family<ResourceListController,
    ResourceListState, ResourcePageSpec>(ResourceListController.new);

String _msg(Object e) =>
    e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
