import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/artifact/artifact.dart';

/// 时间范围过滤器。
enum ArtifactDateRange {
  today,
  week,
  month,
  year,
  all;

  /// 转为过滤起点。null = 不过滤（all）。
  DateTime? get startDate {
    final now = DateTime.now();
    return switch (this) {
      ArtifactDateRange.today => DateTime(now.year, now.month, now.day),
      ArtifactDateRange.week => _weekStart(now),
      ArtifactDateRange.month => DateTime(now.year, now.month, 1),
      ArtifactDateRange.year => DateTime(now.year, 1, 1),
      ArtifactDateRange.all => null,
    };
  }

  static DateTime _weekStart(DateTime date) {
    final weekday = date.weekday; // 1=Mon, 7=Sun
    return DateTime(date.year, date.month, date.day - (weekday - 1));
  }
}

/// 产物列表状态。
@immutable
class ArtifactsState {
  const ArtifactsState({
    this.items = const [],
    this.range = ArtifactDateRange.all,
    this.searchQuery = '',
    this.loading = false,
  });

  final List<Artifact> items;
  final ArtifactDateRange range;
  final String searchQuery;
  final bool loading;

  /// 应用过滤后的结果。
  List<Artifact> get filtered {
    var result = items;

    // 时间过滤
    final start = range.startDate;
    if (start != null) {
      result = result.where((a) => a.updatedAt.isAfter(start)).toList();
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
    ArtifactDateRange? range,
    String? searchQuery,
    bool? loading,
  }) =>
      ArtifactsState(
        items: items ?? this.items,
        range: range ?? this.range,
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
    return const ArtifactsState();
  }

  void setRange(ArtifactDateRange range) {
    state = state.copyWith(range: range);
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
