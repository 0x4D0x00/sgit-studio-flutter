import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/artifact/artifact.dart';

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
/// ⚠️ 内核端点待接：目前返回空列表，等 `/sgcode-artifact/list` 放开后
/// 对接真实数据（参考 `resource_list_controller.dart` 的 ResourceListController）。
class ArtifactsController extends Notifier<ArtifactsState> {
  @override
  ArtifactsState build() {
    // TODO: 接内核 /sgcode-artifact/list，初次进页面拉取。
    // 临时测试数据
    return ArtifactsState(
      items: [
        Artifact(
          id: '1',
          title: 'PotAGI',
          preview: '水循环的变化速度各不相同。报告对整个水循环过程进行了全面的评估，包括河流流量、地下水、蒸散发、陆地水储量、积雪和冰川，以及高影响事件。这些高影响事件通常指气象领域中的极端灾害。部分环节的变化加快了，比如降水、河流流量和土壤湿度，它们可能在数日或数周内随着天气情况而发生改变。相比之下，地下水、冰川和季节性积雪这类水体变化得比较缓慢，需要经过数个季节、数十年甚至更长的时间才能积累或消耗。',
          language: 'dart',
          updatedAt: DateTime(2025, 11, 4),
        ),
        Artifact(
          id: '2',
          title: 'UI',
          preview: '',
          language: 'javascript',
          updatedAt: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
      ],
    );
  }

  void setTypeFilter(String? language) {
    state = state.copyWith(typeFilter: () => language);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> reload() async {
    // TODO: 调用内核端点重新拉取列表。
  }
}

final artifactsControllerProvider =
    NotifierProvider<ArtifactsController, ArtifactsState>(
  ArtifactsController.new,
);
