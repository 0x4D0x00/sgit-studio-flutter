import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sgit_studio_flutter/features/artifacts/application/artifacts_controller.dart';
import 'package:sgit_studio_flutter/features/auth/application/auth_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/thread_list_controller.dart';
import 'package:sgit_studio_flutter/features/find/application/find_controller.dart';
import 'package:sgit_studio_flutter/features/projects/application/projects_controller.dart';
import 'package:sgit_studio_flutter/features/projects/presentation/widgets/create_project_dialog.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/panels/models/nav_entry.dart';
import 'package:sgit_studio_flutter/layout/panels/nav_panel.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/language_dialog.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:sgit_studio_flutter/features/settings/application/user_profile_controller.dart';
import 'package:sgit_studio_flutter/router/route_names.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/services/brand/brand_config.dart';
import 'package:sgit_studio_flutter/services/layout/layout_controller.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/nav/nav_common.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/nav/nav_history_sections.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/nav/nav_search_actions.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/nav/nav_thread_actions.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';
import 'package:sgit_studio_flutter/features/shell/application/history_sort_group_controller.dart';

/// 左栏容器 —— 把 provider / 路由 / 品牌 / l10n 喂给纯组件 `NavPanel`。
///
/// 这一层是**唯一**知道「导航项从哪来、点了去哪」的地方。`NavPanel` 只认 [NavEntry]，
/// 所以换状态库、换路由库都只动本文件。
class NavPanelContainer extends ConsumerWidget {
  const NavPanelContainer({super.key, this.activeNavId});

  /// 当前激活的导航项 id（产物页 / 智能体子页 / null=工作台）。
  final String? activeNavId;

  // 路由层（`app_router`）需要这几个 id 来点亮当前页；其余 id 与前缀见 [NavIds]。
  static const String idArtifacts = NavIds.artifacts;
  static const String idProjects = NavIds.projects;
  static const String idCustomize = NavIds.customize;
  static const String idHistory = NavIds.history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // 历史对话 = sgcode 的 **thread**，不是场景。
    //
    // 这里原先取的是 `resourceListProvider(StudioPageSpecs.scenes)` —— 场景是
    // 「用哪套提示词开对话」的模板，跟"我昨天跟它聊过什么"是两码事。两者条数
    // 和内容都对不上，左栏看着像历史，点进去却是空白新对话。
    //
    // ⚠️ 本文件当前**没有**独立的「助理」section（全仓搜 `navAssistants` 只有
    // l10n 里的文案，没有任何渲染处），所以 scenes 在这里已无消费方，连同
    // resource_list_controller / studio_page_specs / resource_item 三个 import
    // 一并移除 —— 留着只会变成 analyzer 的 unused 警告。将来补「助理」section
    // 时在此重新 watch 一份 scenes，**不要**改用下面这份 threads。
    final threads = ref.watch(threadListProvider).items;

    // 从用户配置状态中读取用户名（用于左侧工具列的头像菜单）
    // final userProfile = ref.watch(userProfileControllerProvider);

    // 排序和分组状态
    final sortGroupState = ref.watch(historySortGroupControllerProvider);

    // 当前接在哪条历史会话上（新对话/还没存过时为 null）。用来点亮左栏对应的
    // 历史条目 —— 打开历史会话走的是 `context.go(home)`，路由本身分不出
    // 是哪一条，`activeNavId` 在这条路径上恒为 null，必须另外比对 thread id。
    final currentThreadId = ref.watch(
      chatControllerProvider.select((s) => s.currentThreadId),
    );
    final effectiveActiveId =
        activeNavId ??
        (currentThreadId == null
            ? NavIds.newChat
            : NavIds.thread(currentThreadId));

    return NavPanel(
      brandName: BrandConfig.instance.name,
      activeId: effectiveActiveId,
      // 导航行：新对话、输出物、Projects、Customize。
      //
      // ⚠️ 「智能体」那一行已移除：它的子页全部进了设置弹窗
      // （`StudioPlacement.settingsDialog` / `.none`），左栏这一行已经没有
      // 任何可列的子项，留着就是一个点开什么也没有的悬停菜单。
      header: [
        NavEntry(id: NavIds.newChat, icon: Icons.add, label: l10n.navNewChat),
        NavEntry(
          id: idArtifacts,
          icon: Icons.widgets_outlined,
          label: l10n.shellOutputTitle,
        ),
        NavEntry(
          id: idProjects,
          icon: Icons.folder_outlined,
          label: l10n.navProjects,
          onTrailingAdd: () => _onCreateProject(context, ref, l10n),
          trailingAddTooltip: l10n.projectsCreate,
        ),
        NavEntry(id: idCustomize, icon: Icons.tune, label: l10n.navCustomize),
      ],
      sections: [
        // 置顶区：有置顶对话时才出现，位于历史对话上方；没有则整组不渲染
        // （NavSection.isEmpty 为真时 NavPanel 会跳过）。
        // TODO: 接置顶对话列表（内核还没放开 thread/pin），目前恒为空。
        NavSection(title: l10n.navChatPin, entries: const []),
        // 历史对话：标题带收起箭头，右侧是菜单/排序项。
        ...buildNavHistorySections(
          l10n: l10n,
          threads: threads,
          state: sortGroupState,
          controller: ref.read(historySortGroupControllerProvider.notifier),
          onViewAll: () => _onViewAllHistory(context),
          onSearch: () => showNavSearch(
            context,
            ref,
            threads,
            onSelect: (id) => _onSelect(context, ref, l10n, id),
          ),
          onNotWired: (id) => showNavNotWired(context, l10n, id),
          chatItemMenu: (t) => buildChatItemMenu(context, ref, l10n, t),
        ),
      ],
      onSelect: (id) => _onSelect(context, ref, l10n, id),
      onFindCount: ref.read(findControllerProvider.notifier).setNavCount,
    );
  }

  void _onSelect(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String id,
  ) {
    // 用 switch 而非 if-else 链：将来接上剩下的项时，漏改一个分支会在这里显形。
    switch (id) {
      case NavIds.newChat:
        // 清空当前会话 + 让下次发消息新建 thread，然后回到工作台。
        ref.read(chatControllerProvider.notifier).newChat();
        context.go(RouteNames.home);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.navNewChatDone),
            duration: const Duration(seconds: 1),
          ),
        );
      case NavIds.artifacts:
        context.go(RouteNames.artifacts);
      case NavIds.projects:
        context.go(RouteNames.projects);
      case NavIds.customize:
        context.go(RouteNames.customize);
      case NavIds.historyMore:
        // 「查看全部」占位行 —— 跳转至历史列表页
        _onViewAllHistory(context);
      case NavIds.agent:
        // 走不到这里 —— 这一行挂的是悬停菜单，`NavPanel` 不给带菜单的行接
        // onSelect。留着分支是为了万一将来把菜单摘掉时，这里不会静默变成
        // default 分支跳到 `/studio/nav.agent`。
        showNavNotWired(context, l10n, id);
      case final String a when a.startsWith(NavIds.assistantPrefix):
        // 切助理 = 用该场景开一轮新对话。场景 id 即 thread 的归属，
        // 由内核决定怎么用（我们只负责把选择传下去）。
        ref
            .read(chatControllerProvider.notifier)
            .newChatWithScene(a.substring(NavIds.assistantPrefix.length));
        context.go(RouteNames.home);
      case final String t when t.startsWith(NavIds.threadPrefix):
        // ⚠️ 这个分支必须排在 `NavIds.assistantPrefix` **之后**只是巧合上无所谓
        //（两个前缀互不为前缀），但顺序一旦被改成某个前缀是另一个的前缀，
        // switch 的先到先得会静默吃掉后一个 —— 加新前缀时先确认互不包含。
        _onOpenThread(context, ref, t.substring(NavIds.threadPrefix.length));
      case final String a when a.startsWith(NavIds.artifactPrefix):
        // 与输出物页的 `_open` 同一条路：先切会话（切会话会关右面板），
        // 再开面板，最后回工作台。内容已在列表里，不必等会话载完。
        _onOpenArtifact(
          context,
          ref,
          a.substring(NavIds.artifactPrefix.length),
        );
      case final String p when p.startsWith(NavIds.projectPrefix):
        context.go(RouteNames.projects);
      default:
        context.go(RouteNames.studio(id));
    }
  }

  /// 从搜索弹窗打开一条产物 —— 跳回它所在的会话，并在右侧面板打开这份文件。
  ///
  /// 与输出物页 `_open` 同一套顺序：**先切会话、后开面板**（切会话会关右面板），
  /// 再把文件卡滚进视野。
  void _onOpenArtifact(BuildContext context, WidgetRef ref, String artifactId) {
    final artifact = ref
        .read(artifactsControllerProvider)
        .items
        .where((a) => a.id == artifactId)
        .firstOrNull;
    if (artifact == null) return;

    final threadId = artifact.threadId;
    final chat = ref.read(chatControllerProvider.notifier);
    if (threadId != null &&
        ref.read(chatControllerProvider).currentThreadId != threadId) {
      unawaited(chat.openThreadById(threadId));
    }
    if (artifact.content.isNotEmpty) {
      ref
          .read(layoutControllerProvider.notifier)
          .showArtifact(artifact.toChatArtifact());
    }
    if (threadId != null) {
      ref.read(artifactFocusProvider.notifier).request(artifact);
    }
    context.go(RouteNames.home);
  }

  /// Projects 行的 + 按钮：打开创建项目对话框。
  Future<void> _onCreateProject(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final draft = await showCreateProjectDialog(context);
    if (draft != null && draft.name.isNotEmpty) {
      ref
          .read(projectsControllerProvider.notifier)
          .addProject(draft.name, draft.description);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建项目：${draft.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 「历史对话」标题行的斜向箭头 —— 在中栏打开完整历史列表页（跟输出物页
  /// 同一种落地方式，不是弹窗）。
  void _onViewAllHistory(BuildContext context) {
    context.go(RouteNames.history);
  }

  /// 点开一条历史会话：载入它的消息，并让后续发言接在这条 thread 上。
  ///
  /// ⚠️ 原先历史条目走的是 `newChatWithScene(sceneId)` —— 开一个**空的新对话**，
  /// 历史消息一条都不载入。点"历史对话"却看不到任何历史，是左栏原先最主要的错。
  ///
  /// ⚠️ **先跳页，再载内容**。原先 `await open()` 之后才 `context.go`，
  /// 内容没回来页面就不动（用户反馈「点历史会话要过很久才能进 L2 页面」）。
  /// 现在载入与报错都归 `ChatController.openThreadById` —— 跳页之后本 widget
  /// 已卸载，接不住结果也弹不了 SnackBar，失败会以工作台的故障条呈现。
  void _onOpenThread(BuildContext context, WidgetRef ref, String threadId) {
    // 不 await：清空与置"正在载入"在首个 await 之前，是同步跑完的，
    // 所以下一行跳过去时工作台已经是干净的载入态。
    unawaited(
      ref.read(chatControllerProvider.notifier).openThreadById(threadId),
    );
    context.go(RouteNames.home);
  }

  /// 供左栏之外的入口（视图菜单 / Ctrl+F）打开同一个搜索弹窗。
  void openSearch(BuildContext context, WidgetRef ref) => showNavSearch(
    context,
    ref,
    ref.read(threadListProvider).items,
    onSelect: (id) => _onSelect(context, ref, AppLocalizations.of(context), id),
  );

  /// 构建用户菜单，供 SideRail 底部的头像使用。
  static List<AppMenuEntry> buildUserMenu(
    BuildContext context,
    WidgetRef ref,
  ) {
    final l10n = AppLocalizations.of(context);
    final userProfile = ref.watch(userProfileControllerProvider);

    return [
      AppMenuLabel(userProfile.username),
      const AppMenuDivider(),
      AppMenuAction(
        icon: Icons.settings_outlined,
        label: l10n.navSettings,
        shortcut: 'Ctrl+,',
        onTap: () => showSettingsDialog(context),
      ),
      AppMenuAction(
        icon: Icons.language,
        label: l10n.settingsLanguage,
        onTap: () => showLanguageDialog(context),
      ),
      AppMenuAction(
        icon: Icons.help_outline,
        label: l10n.navGetHelp,
        onTap: () => showNavNotWired(context, l10n, 'get-help'),
      ),
      const AppMenuDivider(),
      AppMenuSubmenu(
        icon: Icons.info_outline,
        label: l10n.navLearnMore,
        entries: [
          AppMenuAction(
            label: l10n.navAboutBrand(BrandConfig.instance.name),
            onTap: () => showNavNotWired(context, l10n, 'about'),
          ),
          const AppMenuDivider(),
          AppMenuAction(
            label: l10n.navUsagePolicy,
            onTap: () => showNavNotWired(context, l10n, 'usage-policy'),
          ),
          AppMenuAction(
            label: l10n.navPrivacyPolicy,
            onTap: () => showNavNotWired(context, l10n, 'privacy-policy'),
          ),
          AppMenuAction(
            label: l10n.navTermsOfService,
            onTap: () => showNavNotWired(context, l10n, 'terms'),
          ),
          AppMenuAction(
            label: l10n.navPrivacyChoices,
            onTap: () => showNavNotWired(context, l10n, 'privacy-choices'),
          ),
          AppMenuAction(
            label: l10n.navGetApps,
            onTap: () => showNavNotWired(context,l10n,'get-apps'),
          ),
          const AppMenuDivider(),
          AppMenuAction(
            label: l10n.navKeyboardShortcuts,
            shortcut: 'Ctrl+/',
            onTap: () => showNavNotWired(context, l10n, 'shortcuts'),
          ),
        ],
      ),
      const AppMenuDivider(),
      AppMenuAction(
        icon: Icons.logout,
        label: l10n.navLogout,
        onTap: () => ref.read(authControllerProvider.notifier).logout(),
      ),
    ];
  }
}
