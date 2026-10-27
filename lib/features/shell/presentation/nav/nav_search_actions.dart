import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';
import 'package:sgit_studio_flutter/features/artifacts/application/artifacts_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_focus_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/thread_list_controller.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/thread_actions.dart';
import 'package:sgit_studio_flutter/features/customize/application/customize_page_controller.dart';
import 'package:sgit_studio_flutter/features/projects/application/projects_controller.dart';
import 'package:sgit_studio_flutter/features/projects/presentation/widgets/edit_project_dialog.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/nav/nav_common.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/nav/nav_thread_actions.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/router/route_names.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/services/layout/layout_controller.dart';
import 'package:sgit_studio_flutter/ui/components/dialogs/search_chats_dialog.dart';
import 'package:sgit_studio_flutter/ui/feedback/confirm.dart';

/// 打开搜索弹窗（左栏历史区的搜索图标、视图菜单、Ctrl+F 都走这里）。
///
/// [onSelect] 是左栏导航的分派函数 —— 搜索结果的 id 与导航项 id 同一套前缀
/// （见 [NavIds]），所以选中一项等价于点了左栏对应的行。
void showNavSearch(
  BuildContext context,
  WidgetRef ref,
  List<ThreadSummary> threads, {
  required void Function(String id) onSelect,
}) {
  final l10n = AppLocalizations.of(context);
  showSearchChatsDialog(
    context,
    // 三类数据一次摊平给弹窗：弹窗自己不碰 provider（`ui/` 层不依赖状态库），
    // 这里按 category 标好，标签页过滤就只剩一次 where。
    items: [
      for (final t in threads)
        SearchDialogItem(
          id: NavIds.thread(t.id),
          // 标题的回落（用户改的名字 > 首条消息摘要 > "新对话"）在 Rust 侧
          // `thread_ops::display_title` 算好了，这边不再自己来一套 ——
          // 两边各算各的必然漂。
          label: t.title,
          category: SearchDialogCategory.chat,
          updatedAt: t.updatedAt ?? t.createdAt,
        ),
      for (final a in ref.read(artifactsControllerProvider).items)
        SearchDialogItem(
          id: NavIds.artifact(a.id),
          label: a.title,
          category: SearchDialogCategory.artifact,
          updatedAt: a.updatedAt,
        ),
      for (final p in ref.read(projectsControllerProvider))
        SearchDialogItem(
          id: NavIds.project(p.id),
          label: p.name,
          category: SearchDialogCategory.project,
          updatedAt: p.updatedAt,
        ),
    ],
    onSelect: onSelect,
    onRowAction: (id, action) =>
        _onSearchRowAction(context, ref, l10n, id, action, onSelect),
    commands: _searchCommands(context, ref, l10n),
    onCompose: () {
      context.go(RouteNames.home);
      ref.read(composerFocusProvider.notifier).requestFocus();
    },
  );
}

/// 搜索弹窗「操作」筛选里的命令。只收有现成落点的：跳页、开设置、折叠导航
List<SearchDialogCommand> _searchCommands(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
) {
  SearchDialogCommand go(String label, IconData icon, String route) =>
      SearchDialogCommand(
        label: label,
        icon: icon,
        onRun: () => context.go(route),
      );
  SearchDialogCommand settings(String page, SettingsTab tab) =>
      SearchDialogCommand(
        label: '${l10n.navSettings} → $page',
        icon: Icons.settings_outlined,
        onRun: () => showSettingsDialog(context, initialTab: tab),
      );
  SearchDialogCommand customize(String page, CustomizeTab tab) =>
      SearchDialogCommand(
        label: '${l10n.navCustomize} → $page',
        icon: Icons.tune,
        onRun: () {
          ref.read(customizeTabControllerProvider.notifier).setTab(tab);
          context.go(RouteNames.customize);
        },
      );

  return [
    go(l10n.searchCmdAllChats, Icons.chat_bubble_outline, RouteNames.history),
    SearchDialogCommand(
      label: l10n.searchNewChat,
      icon: Icons.add_circle_outline,
      featured: true,
      onRun: () {
        ref.read(chatControllerProvider.notifier).newChat();
        context.go(RouteNames.home);
      },
    ),
    go(l10n.navProjects, Icons.inventory_2_outlined, RouteNames.projects),
    go(l10n.artifactsTitle, Icons.description_outlined, RouteNames.artifacts),
    SearchDialogCommand(
      label: l10n.searchCmdToggleSidebar,
      icon: Icons.view_sidebar_outlined,
      onRun: () => ref.read(layoutControllerProvider.notifier).toggleNav(),
    ),
    settings(l10n.settingsGeneral, SettingsTab.general),
    settings(l10n.settingsAccount, SettingsTab.account),
    settings(l10n.settingsPrivacy, SettingsTab.privacy),
    settings(l10n.settingsBilling, SettingsTab.billing),
    settings(l10n.settingsCapabilities, SettingsTab.capabilities),
    settings(l10n.settingsMemory, SettingsTab.memory),
    settings(l10n.settingsClaudeCode, SettingsTab.claudeCode),
    customize(l10n.studioSkill, CustomizeTab.skills),
    customize(l10n.customizeTabConnectors, CustomizeTab.connectors),
    customize(l10n.customizeTabPlugins, CustomizeTab.plugins),
  ];
}

/// 搜索弹窗行尾「⁝」的动作。改名 / 删除 / 编辑细节的对话框直接叠在搜索弹窗之上，
/// 结果回给弹窗就地刷新；置顶 / 复制链接没有对应内核接口，只弹「未接入」。
Future<SearchRowResult?> _onSearchRowAction(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
  String id,
  SearchDialogRowAction action,
  void Function(String id) onSelect,
) async {
  final threadId = NavIds.strip(id, NavIds.threadPrefix);
  final projectId = NavIds.strip(id, NavIds.projectPrefix);
  switch (action) {
    case SearchDialogRowAction.open:
      onSelect(id);
      return null;
    case SearchDialogRowAction.pin:
      showNavNotWired(context, l10n, 'pin');
      return null;
    case SearchDialogRowAction.copyLink:
      showNavNotWired(context, l10n, 'copyLink');
      return null;
    case SearchDialogRowAction.editDetails:
      if (projectId == null) return null;
      final project = ref
          .read(projectsControllerProvider)
          .where((p) => p.id == projectId)
          .firstOrNull;
      if (project == null) return null;
      final edit = await showEditProjectDialog(
        context,
        name: project.name,
        description: project.description,
      );
      if (edit == null || edit.name.isEmpty) return null;
      ref
          .read(projectsControllerProvider.notifier)
          .updateProject(projectId, edit.name, edit.description);
      return SearchRowResult.renamed(edit.name);
    case SearchDialogRowAction.rename:
      if (threadId == null) return null;
      final thread = ref
          .read(threadListProvider)
          .items
          .where((t) => t.id == threadId)
          .firstOrNull;
      final name = await renameThreadWithDialog(
        context,
        ref,
        threadId,
        thread?.title ?? '',
      );
      // 空串会回落成首条消息摘要，弹窗里拿不到那个值，就先保持原样。
      if (name == null || name.isEmpty) return null;
      return SearchRowResult.renamed(name);
    case SearchDialogRowAction.delete:
      if (projectId != null) {
        final project = ref
            .read(projectsControllerProvider)
            .where((p) => p.id == projectId)
            .firstOrNull;
        final ok = await confirmDanger(
          context,
          title: l10n.studioRemoveConfirm(project?.name ?? ''),
          confirmText: l10n.commonDelete,
        );
        if (!ok) return null;
        ref.read(projectsControllerProvider.notifier).deleteProject(projectId);
        return const SearchRowResult.removed();
      }
      if (threadId == null) {
        showNavNotWired(context, l10n, 'delete');
        return null;
      }
      final thread = ref
          .read(threadListProvider)
          .items
          .where((t) => t.id == threadId)
          .firstOrNull;
      final deleted = await deleteThreadResettingIfCurrent(
        context,
        ref,
        threadId,
        thread?.title ?? '',
      );
      return deleted ? const SearchRowResult.removed() : null;
  }
}
