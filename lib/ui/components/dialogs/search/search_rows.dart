import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/dialogs/search/search_models.dart';

/// 命令面板标签页。前四个是真实分类，后三个暂无数据源（保留空态，等内核接上）。
enum SearchTab { all, artifacts, chats, projects, sessions, tasks, scheduled }

extension SearchTabX on SearchTab {
  /// 该标签要收哪些分类。空集合 = 这个标签当前没有数据源。
  Set<SearchDialogCategory> get categories => switch (this) {
    SearchTab.all => SearchDialogCategory.values.toSet(),
    SearchTab.artifacts => const {SearchDialogCategory.artifact},
    SearchTab.chats => const {SearchDialogCategory.chat},
    SearchTab.projects => const {SearchDialogCategory.project},
    SearchTab.sessions || SearchTab.tasks || SearchTab.scheduled => const {},
  };

  bool get hasDataSource => categories.isNotEmpty;

  /// 无搜索词时最多展示多少条（最近的）。null = 不限。
  int? get recentLimit => switch (this) {
    SearchTab.all => 8,
    SearchTab.chats => 25,
    _ => null,
  };

  String label(AppLocalizations l10n) => switch (this) {
    SearchTab.all => l10n.searchTabAll,
    SearchTab.artifacts => l10n.searchTabArtifacts,
    SearchTab.chats => l10n.searchTabChats,
    SearchTab.projects => l10n.searchTabProjects,
    SearchTab.sessions => l10n.searchTabSessions,
    SearchTab.tasks => l10n.searchTabTasks,
    SearchTab.scheduled => l10n.searchTabScheduled,
  };
}

/// 列表里的一行。用 sealed 是为了让渲染侧的 switch 漏分支时编译报错。
sealed class SearchRow {
  const SearchRow();
}

/// 分组标题（Recents / Actions）。
class SearchSectionRow extends SearchRow {
  const SearchSectionRow(this.label);
  final String label;
}

/// 一条可打开的条目。
class SearchItemRow extends SearchRow {
  const SearchItemRow(this.item);
  final SearchDialogItem item;
}

/// 一条命令（目前只有「新建对话」）。
class SearchActionRow extends SearchRow {
  const SearchActionRow({
    required this.label,
    required this.icon,
    required this.onRun,
  });
  final String label;
  final IconData icon;
  final VoidCallback onRun;

  SearchActionRow.of(SearchDialogCommand c)
    : this(label: c.label, icon: c.icon, onRun: c.onRun);
}

/// 输入 `/` 后列出的筛选项，或选完筛选键后列出的候选值。选中即回调 [onPick]。
class SearchSuggestionRow extends SearchRow {
  const SearchSuggestionRow({
    required this.text,
    required this.onPick,
    this.pill,
    this.icon,
  });
  final String text;

  /// 文字后面的小药丸（「按 [所有者] 筛选」里的所有者）。
  final String? pill;
  final IconData? icon;
  final VoidCallback onPick;
}

/// 筛选键。`owner` / `date` / `type` 要再选一个值；`archived` / `actions` 直接生效。
enum SearchFilterKind { owner, date, type, archived, actions }

extension SearchFilterKindX on SearchFilterKind {
  bool get hasValues =>
      this == SearchFilterKind.owner ||
      this == SearchFilterKind.date ||
      this == SearchFilterKind.type;

  String label(AppLocalizations l10n) => switch (this) {
    SearchFilterKind.owner => l10n.searchFilterOwner,
    SearchFilterKind.date => l10n.searchFilterDate,
    SearchFilterKind.type => l10n.searchFilterType,
    SearchFilterKind.archived => l10n.searchFilterArchived,
    SearchFilterKind.actions => l10n.searchFilterActions,
  };

  IconData get icon => switch (this) {
    SearchFilterKind.owner => Icons.person_outline,
    SearchFilterKind.date => Icons.schedule,
    SearchFilterKind.type => Icons.category_outlined,
    SearchFilterKind.archived => Icons.archive_outlined,
    SearchFilterKind.actions => Icons.keyboard_command_key,
  };

  /// 该筛选键的候选值（文案）。
  List<String> valueLabels(AppLocalizations l10n) => switch (this) {
    SearchFilterKind.owner => [l10n.searchOwnerMe, l10n.searchOwnerShared],
    SearchFilterKind.date => [
      l10n.searchTimeToday,
      l10n.searchTimePastWeek,
      l10n.searchTimePastMonth,
    ],
    // 「全部」不是类型。下标对应 `SearchTab.values[i + 1]`。
    SearchFilterKind.type => [
      for (final t in SearchTab.values.skip(1)) t.label(l10n),
    ],
    _ => const [],
  };
}

/// 已生效的筛选（搜索框左侧的小标签）。[value] 是候选值的下标。
@immutable
class SearchAppliedFilter {
  const SearchAppliedFilter(this.kind, [this.value]);
  final SearchFilterKind kind;
  final int? value;

  /// 小标签上的文字：`键` 或 `键: 值`。
  String label(AppLocalizations l10n) {
    final v = value;
    return v == null
        ? kind.label(l10n)
        : '${kind.label(l10n)}: ${kind.valueLabels(l10n)[v]}';
  }
}

/// 已生效的筛选是否放行该条目。
///
/// 目前没有「所有者」「归档」的数据源：条目全是自己的、没有归档项，
/// 所以「我」放行全部，「与我共享」和「已归档」一条都不放行。
bool searchMatchesFilters(
  List<SearchAppliedFilter> filters,
  SearchDialogItem e,
) {
  for (final f in filters) {
    switch (f.kind) {
      case SearchFilterKind.owner:
        if (f.value != 0) return false;
      case SearchFilterKind.archived:
        return false;
      case SearchFilterKind.date:
        final at = e.updatedAt;
        if (at == null) return false;
        // 与 [searchTimeLabel] 同一分档：只留下行尾显示该标签的条目，互不重叠。
        final days = DateTime.now().difference(at).inDays;
        final inBucket = switch (f.value!) {
          0 => days < 1,
          1 => days >= 1 && days < 7,
          _ => days >= 7 && days < 30,
        };
        if (!inBucket) return false;
      case SearchFilterKind.type || SearchFilterKind.actions:
        break;
    }
  }
  return true;
}

IconData searchCategoryIcon(SearchDialogCategory c) => switch (c) {
  SearchDialogCategory.artifact => Icons.description_outlined,
  SearchDialogCategory.chat => Icons.chat_bubble_outline,
  SearchDialogCategory.project => Icons.inventory_2_outlined,
};

/// 相对时间。分档与截图一致：今天 / 过去一周 / 过去一月 / 过去一年 / 更早。
String searchTimeLabel(AppLocalizations l10n, DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inDays < 1) return l10n.searchTimeToday;
  if (diff.inDays < 7) return l10n.searchTimePastWeek;
  if (diff.inDays < 30) return l10n.searchTimePastMonth;
  if (diff.inDays < 365) return l10n.searchTimePastYear;
  return l10n.searchTimeOlder;
}
