import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';
import 'package:sgit_studio_flutter/features/shell/application/history_sort_group_controller.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/nav/nav_common.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/panels/models/nav_entry.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 左栏历史对话最多显示这么多条，超出的用「查看全部」行代替（跳去全量列表页）。
const int kNavHistoryLimit = 20;

/// 构建历史对话区域（可能包含多个分组）。
///
/// 纯构建函数：数据与回调都由调用方（`NavPanelContainer`）传入，这里不碰 provider
/// 之外的任何东西。
List<NavSection> buildNavHistorySections({
  required AppLocalizations l10n,
  required List<ThreadSummary> threads,
  required HistorySortGroupState state,
  required HistorySortGroupController controller,
  required VoidCallback onViewAll,
  required VoidCallback onSearch,
  required void Function(String id) onNotWired,
  required List<AppMenuEntry> Function(ThreadSummary) chatItemMenu,
}) {
  // 按照当前排序和分组设置处理数据
  final grouped = sortAndGroupHistory(
    threads,
    state.sortBy,
    state.groupBy,
    (key) => _groupTitle(key, l10n),
  );

  List<AppMenuEntry> sortGroupMenu() => _sortGroupMenu(
    l10n: l10n,
    state: state,
    controller: controller,
    onGroupByAssistant: () => onNotWired('group-by-assistant'),
  );

  NavEntry threadEntry(ThreadSummary t) => NavEntry(
    // ⚠️ 前缀必须是 `NavIds.threadPrefix`：这条 id 会原样回到 `_onSelect`，
    // 走错前缀就会把 threadId 喂给 `newChatWithScene`。分组 / 不分组是历史区的
    // 两条渲染路径，现在共用这一处，不会只改一边。
    id: NavIds.thread(t.id),
    icon: Icons.chat_bubble_outline,
    // 标题回落已由 Rust 侧 `thread_ops::display_title` 算好，不再自己来一套。
    label: t.title,
    trailingMenu: chatItemMenu(t),
  );

  NavEntry viewAllEntry() => NavEntry(
    id: NavIds.historyMore,
    icon: Icons.more_horiz,
    label: l10n.navViewAll,
    isSpecialAction: true,
  );

  // 如果不分组，返回单个 section
  if (state.groupBy == ChatGroupBy.none) {
    final items = grouped.first.items;
    return [
      NavSection(
        title: l10n.navHistory,
        collapsible: true,
        viewAllTooltip: l10n.navViewAll,
        onViewAll: onViewAll,
        action: NavSectionAction.menu,
        searchTooltip: l10n.navSearch,
        onSearch: onSearch,
        actionTooltip: l10n.chatSortBy,
        menu: sortGroupMenu(),
        entries: [
          for (final t in items.take(kNavHistoryLimit)) threadEntry(t),
          if (threads.length > kNavHistoryLimit) viewAllEntry(),
        ],
      ),
    ];
  }

  // 分组模式：第一个 section 是主标题，后续的是各个日期分组
  final sections = <NavSection>[
    // 主标题 section（不可折叠，带菜单和查看全部按钮）
    NavSection(
      title: l10n.navHistory,
      collapsible: false,
      viewAllTooltip: l10n.navViewAll,
      onViewAll: onViewAll,
      searchTooltip: l10n.navSearch,
      onSearch: onSearch,
      actionTooltip: l10n.chatSortBy,
      action: NavSectionAction.menu,
      menu: sortGroupMenu(),
      entries: const [], // 主标题 section 不显示任何条目
    ),
  ];

  // 为每个日期分组创建可折叠的 section
  for (var i = 0; i < grouped.length; i++) {
    final group = grouped[i];
    final isCollapsed = state.collapsedGroups.contains(group.groupKey);
    final isFirstGroup = i == 0;
    final hasMore = group.items.length > kNavHistoryLimit;

    sections.add(
      NavSection(
        title: group.groupTitle,
        collapsible: true, // 每个日期分组都可折叠
        isCollapsed: isCollapsed,
        // 只有第一个分组需要"查看全部"和菜单按钮
        viewAllTooltip: isFirstGroup ? l10n.navViewAll : null,
        onViewAll: isFirstGroup ? onViewAll : null,
        action: isFirstGroup ? NavSectionAction.menu : NavSectionAction.none,
        actionTooltip: isFirstGroup ? l10n.chatSortBy : null,
        searchTooltip: isFirstGroup ? l10n.navSearch : null,
        onSearch: isFirstGroup ? onSearch : null,
        menu: isFirstGroup ? sortGroupMenu() : [],
        onToggleCollapse: () => controller.toggleGroupCollapse(group.groupKey),
        entries: isCollapsed
            ? []
            : [
                for (final t in group.items.take(kNavHistoryLimit))
                  threadEntry(t),
                // 超过上限时显示"查看全部"
                if (hasMore) viewAllEntry(),
              ],
      ),
    );
  }

  return sections;
}

/// 「分组方式 / 排序方式」两个子菜单。
List<AppMenuEntry> _sortGroupMenu({
  required AppLocalizations l10n,
  required HistorySortGroupState state,
  required HistorySortGroupController controller,
  required VoidCallback onGroupByAssistant,
}) {
  final sortLabel = switch (state.sortBy) {
    ChatSortBy.lastActivity => l10n.chatSortLastActivity,
    ChatSortBy.name => l10n.chatSortName,
  };
  final groupLabel = switch (state.groupBy) {
    ChatGroupBy.none => l10n.chatGroupNone,
    ChatGroupBy.date => l10n.chatGroupDate,
    ChatGroupBy.assistant => l10n.chatGroupAssistant,
  };

  return [
    AppMenuSubmenu(
      label: l10n.chatGroupBy,
      trailingValue: groupLabel,
      entries: [
        AppMenuAction(
          label: l10n.chatGroupNone,
          checked: state.groupBy == ChatGroupBy.none,
          onTap: () => controller.setGroupBy(ChatGroupBy.none),
        ),
        AppMenuAction(
          label: l10n.chatGroupDate,
          checked: state.groupBy == ChatGroupBy.date,
          onTap: () => controller.setGroupBy(ChatGroupBy.date),
        ),
        AppMenuAction(
          label: l10n.chatGroupAssistant,
          checked: state.groupBy == ChatGroupBy.assistant,
          onTap: onGroupByAssistant,
        ),
      ],
    ),
    AppMenuSubmenu(
      label: l10n.chatSortBy,
      trailingValue: sortLabel,
      entries: [
        AppMenuAction(
          label: l10n.chatSortName,
          checked: state.sortBy == ChatSortBy.name,
          onTap: () => controller.setSortBy(ChatSortBy.name),
        ),
        AppMenuAction(
          label: l10n.chatSortLastActivity,
          checked: state.sortBy == ChatSortBy.lastActivity,
          onTap: () => controller.setSortBy(ChatSortBy.lastActivity),
        ),
      ],
    ),
  ];
}

/// 分组标题。三档：今天 / 昨天 / 更早，外加一个"时间未知"兜底。
String _groupTitle(String key, AppLocalizations l10n) {
  switch (key) {
    case 'today':
      return l10n.chatGroupToday;
    case 'yesterday':
      return l10n.chatGroupYesterday;
    case 'older':
      return l10n.chatGroupOlder;
    case 'unknown':
      return l10n.chatGroupUnknown;
  }
  if (key.startsWith('assistant_')) {
    // 按助理分组要先有 thread → agent 归属映射（服务端 `topic_owner` 有，
    // 客户端还取不到）。菜单里那项也标着未接。
    return key.substring('assistant_'.length);
  }
  return key;
}
