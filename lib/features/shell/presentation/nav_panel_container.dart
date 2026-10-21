import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sgit_studio_flutter/features/artifacts/application/artifacts_controller.dart';
import 'package:sgit_studio_flutter/features/auth/application/auth_controller.dart';
import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_focus_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/thread_list_controller.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/thread_actions.dart';
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
import 'package:sgit_studio_flutter/services/brand/brand_assets.dart';
import 'package:sgit_studio_flutter/services/brand/brand_config.dart';
import 'package:sgit_studio_flutter/services/layout/layout_controller.dart';
import 'package:sgit_studio_flutter/ui/components/dialogs/search_chats_dialog.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';
import 'package:sgit_studio_flutter/features/shell/application/history_sort_group_controller.dart';

/// 左栏容器 —— 把 provider / 路由 / 品牌 / l10n 喂给纯组件 `NavPanel`。
///
/// 这一层是**唯一**知道「导航项从哪来、点了去哪」的地方。`NavPanel` 只认 [NavEntry]，
/// 所以换状态库、换路由库都只动本文件。
class NavPanelContainer
    extends
        ConsumerWidget {
  const NavPanelContainer({
    super.key,
    this.activeNavId,
  });

  /// 当前激活的导航项 id（产物页 / 智能体子页 / null=工作台）。
  final String? activeNavId;

  // 非 studio 的固定项 id。用常量而非字面量，避免和 studio key 撞。
  static const String _idNewChat = 'nav.new-chat';
  static const String idArtifacts = 'nav.artifacts';
  static const String idProjects = 'nav.projects';
  static const String idCustomize = 'nav.customize';
  static const String idHistory = 'nav.history';
  static const String _idAgent = 'nav.agent';
  static const String _idHistoryMore = 'nav.history-more';

  /// 左栏历史对话最多显示这么多条，超出的用「查看全部」行代替（跳去全量列表页）。
  static const int _historyLimit = 20;

  /// 助理项的 id 前缀，避免与 studio 的 key 撞。
  ///
  /// **只给助理用**。选中它 = 用该场景开一轮新对话（`newChatWithScene`），
  /// 语义上就不该载入任何历史消息 —— 别把历史条目也挂到这个前缀上。
  static const String _assistantPrefix = 'assistant:';

  /// 历史会话项的 id 前缀。
  ///
  /// ⚠️ 历史区原先复用 `_assistantPrefix` —— 因为它列的是**场景标签而不是会话**。
  /// 后果不止显示错：点进去走 `newChatWithScene` 开的是**空的新对话**（点"历史
  /// 对话"却看不到任何历史），删除走 `resourceListProvider(scenes).remove()`
  /// **删掉的是场景定义本身**。
  ///
  /// 所以两个前缀必须泾渭分明：`_onSelect` 靠前缀分派，**漏改一处就会把
  /// threadId 当 sceneId 用** —— 而 sgcode 两边的 id 都是 UUID 形态，
  /// 不会报错，只会静默走错分支。
  static const String _threadPrefix = 'thread:';

  /// 搜索弹窗里的产物项前缀。点开走右侧产物面板，不进 `_onSelect` 的导航分支。
  static const String _artifactPrefix = 'artifact:';

  /// 搜索弹窗里的项目项前缀。点开落在 Projects 页。
  static const String _projectPrefix = 'project:';

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final l10n = AppLocalizations.of(
      context,
    );
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
    final threads = ref
        .watch(
          threadListProvider,
        )
        .items;

    // 从用户配置状态中读取用户名
    final userProfile = ref.watch(userProfileControllerProvider);

    // 排序和分组状态
    final sortGroupState = ref.watch(historySortGroupControllerProvider);

    // 当前接在哪条历史会话上（新对话/还没存过时为 null）。用来点亮左栏对应的
    // 历史条目 —— 打开历史会话走的是 `context.go(home)`，路由本身分不出
    // 是哪一条，`activeNavId` 在这条路径上恒为 null，必须另外比对 thread id。
    final currentThreadId =
        ref.watch(chatControllerProvider.select((s) => s.currentThreadId));
    final effectiveActiveId = activeNavId ??
        (currentThreadId == null ? _idNewChat : '$_threadPrefix$currentThreadId');

    return NavPanel(
      brandMark: BrandAssets.image(
        BrandAssets.loginMark,
      ),
      brandName: BrandConfig.instance.name,
      activeId: effectiveActiveId,
      // 导航行：新对话、输出物、Projects、Customize。
      //
      // ⚠️ 「智能体」那一行已移除：它的子页全部进了设置弹窗
      // （`StudioPlacement.settingsDialog` / `.none`），左栏这一行已经没有
      // 任何可列的子项，留着就是一个点开什么也没有的悬停菜单。
      header: [
        NavEntry(
          id: _idNewChat,
          icon: Icons.add,
          label: l10n.navNewChat,
        ),
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
        NavEntry(
          id: idCustomize,
          icon: Icons.tune,
          label: l10n.navCustomize,
        ),
      ],
      sections: [
        // // 置顶区：位于导航行下方、历史对话上方。空着也要出现（靠 emptyHint 撑住），
        // // 否则用户不知道有「置顶」这回事。
        // NavSection(
        //   title: '置顶',
        //   // action: NavSectionAction.add,
        //   emptyHint: 'Pin chats to keep them here',
        //   emptyHintIcon: Icons.push_pin_outlined,
        //   entries: const [
        //     // TODO: 接置顶对话列表（内核还没放开 thread/pin）。
        //   ],
        // ),
        // 历史对话：标题带收起箭头，右侧是菜单/排序项。
        ..._buildHistorySections(
          l10n,
          ref,
          threads,
          sortGroupState,
          context,
        ),
      ],
      onSelect:
          (
            id,
          ) => _onSelect(
            context,
            ref,
            l10n,
            id,
          ),
      userName: userProfile.username,
      avatarBytes: userProfile.avatarBytes,
      searchTooltip: l10n.navSearch,
      collapseTooltip: l10n.shellCollapseNav,
      userMenu: [
        AppMenuLabel(
          userProfile.username,
        ),
        const AppMenuDivider(),
        AppMenuAction(
          icon: Icons.settings_outlined,
          label: l10n.navSettings,
          onTap: () => showSettingsDialog(context),
        ),
        AppMenuAction(
          icon: Icons.language,
          label: l10n.settingsLanguage,
          onTap: () => showLanguageDialog(context),
        ),
        const AppMenuDivider(),
        AppMenuAction(
          icon: Icons.logout,
          label: l10n.navLogout,
          onTap: () => ref
              .read(
                authControllerProvider.notifier,
              )
              .logout(),
        ),
      ],
      onSearch: () => _onSearch(
        context,
        ref,
        threads,
      ),
      onCollapse: () => ref
          .read(
            layoutControllerProvider.notifier,
          )
          .toggleNav(),
      // onAddProject: () => _notWired(
      //   context,
      //   l10n,
      //   'add-project',
      // ),
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
      case _idNewChat:
        // 清空当前会话 + 让下次发消息新建 thread，然后回到工作台。
        ref
            .read(
              chatControllerProvider.notifier,
            )
            .newChat();
        context.go(
          RouteNames.home,
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text(
              l10n.navNewChatDone,
            ),
            duration: const Duration(
              seconds: 1,
            ),
          ),
        );
      case idArtifacts:
        context.go(
          RouteNames.artifacts,
        );
      case idProjects:
        context.go(
          RouteNames.projects,
        );
      case idCustomize:
        context.go(
          RouteNames.customize,
        );
      case _idHistoryMore:
        // 「查看全部」占位行 —— 跳转至历史列表页
        _onViewAllHistory(
          context,
        );
      case _idAgent:
        // 走不到这里 —— 这一行挂的是悬停菜单，`NavPanel` 不给带菜单的行接
        // onSelect。留着分支是为了万一将来把菜单摘掉时，这里不会静默变成
        // default 分支跳到 `/studio/nav.agent`。
        _notWired(
          context,
          l10n,
          id,
        );
      case final String
          a
          when a.startsWith(
            _assistantPrefix,
          ):
        // 切助理 = 用该场景开一轮新对话。场景 id 即 thread 的归属，
        // 由内核决定怎么用（我们只负责把选择传下去）。
        ref
            .read(
              chatControllerProvider.notifier,
            )
            .newChatWithScene(
              a.substring(
                _assistantPrefix.length,
              ),
            );
        context.go(
          RouteNames.home,
        );
      case final String
          t
          when t.startsWith(
            _threadPrefix,
          ):
        // ⚠️ 这个分支必须排在 `_assistantPrefix` **之后**只是巧合上无所谓
        //（两个前缀互不为前缀），但顺序一旦被改成某个前缀是另一个的前缀，
        // switch 的先到先得会静默吃掉后一个 —— 加新前缀时先确认互不包含。
        _onOpenThread(
          context,
          ref,
          t.substring(
            _threadPrefix.length,
          ),
        );
      case final String
          a
          when a.startsWith(
            _artifactPrefix,
          ):
        // 与输出物页的 `_open` 同一条路：先切会话（切会话会关右面板），
        // 再开面板，最后回工作台。内容已在列表里，不必等会话载完。
        _onOpenArtifact(
          context,
          ref,
          a.substring(
            _artifactPrefix.length,
          ),
        );
      case final String
          p
          when p.startsWith(
            _projectPrefix,
          ):
        context.go(
          RouteNames.projects,
        );
      default:
        context.go(
          RouteNames.studio(
            id,
          ),
        );
    }
  }

  /// 从搜索弹窗打开一条产物 —— 跳回它所在的会话，并在右侧面板打开这份文件。
  ///
  /// 与输出物页 `_open` 同一套顺序：**先切会话、后开面板**（切会话会关右面板），
  /// 再把文件卡滚进视野。
  void _onOpenArtifact(
    BuildContext context,
    WidgetRef ref,
    String artifactId,
  ) {
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
      ref.read(projectsControllerProvider.notifier).addProject(
            draft.name,
            draft.description,
          );
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
  void _onViewAllHistory(
    BuildContext context,
  ) {
    context.go(
      RouteNames.history,
    );
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
  void _onOpenThread(
    BuildContext context,
    WidgetRef ref,
    String threadId,
  ) {
    // 不 await：清空与置"正在载入"在首个 await 之前，是同步跑完的，
    // 所以下一行跳过去时工作台已经是干净的载入态。
    unawaited(
      ref
          .read(
            chatControllerProvider.notifier,
          )
          .openThreadById(
            threadId,
          ),
    );
    context.go(
      RouteNames.home,
    );
  }

  void _onSearch(
    BuildContext context,
    WidgetRef ref,
    List<
      ThreadSummary
    >
    threads,
  ) {
    final l10n = AppLocalizations.of(context);
    showSearchChatsDialog(
      context,
      // 三类数据一次摊平给弹窗：弹窗自己不碰 provider（`ui/` 层不依赖状态库），
      // 这里按 category 标好，标签页过滤就只剩一次 where。
      items: [
        for (final t in threads)
          SearchDialogItem(
            id: '$_threadPrefix${t.id}',
            // 标题的回落（用户改的名字 > 首条消息摘要 > "新对话"）在 Rust 侧
            // `thread_ops::display_title` 算好了，这边不再自己来一套 ——
            // 两边各算各的必然漂。
            label: t.title,
            category: SearchDialogCategory.chat,
            updatedAt: t.updatedAt ?? t.createdAt,
          ),
        for (final a in ref.read(artifactsControllerProvider).items)
          SearchDialogItem(
            id: '$_artifactPrefix${a.id}',
            label: a.title,
            category: SearchDialogCategory.artifact,
            updatedAt: a.updatedAt,
          ),
        for (final p in ref.read(projectsControllerProvider))
          SearchDialogItem(
            id: '$_projectPrefix${p.id}',
            label: p.name,
            category: SearchDialogCategory.project,
            updatedAt: p.updatedAt,
          ),
      ],
      onSelect: (id) => _onSelect(context, ref, l10n, id),
      onRowAction: (id, action) => _onSearchRowAction(
        context,
        ref,
        l10n,
        id,
        action,
      ),
      onNewChat: () {
        ref.read(chatControllerProvider.notifier).newChat();
        context.go(RouteNames.home);
      },
      onCompose: () {
        context.go(RouteNames.home);
        ref.read(composerFocusProvider.notifier).requestFocus();
      },
    );
  }

  /// 搜索弹窗行尾「⁝」的动作。只有聊天有改名/删除这类真落地能力 ——
  /// 产物与项目没有对应内核接口，菜单里只给「打开」。
  Future<void> _onSearchRowAction(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String id,
    SearchDialogRowAction action,
  ) async {
    final isThread = id.startsWith(_threadPrefix);
    final threadId = isThread ? id.substring(_threadPrefix.length) : null;
    switch (action) {
      case SearchDialogRowAction.open:
        _onSelect(context, ref, l10n, id);
      case SearchDialogRowAction.pin:
        _notWired(context, l10n, 'pin');
      case SearchDialogRowAction.editDetails:
        _notWired(context, l10n, 'editDetails');
      case SearchDialogRowAction.copyLink:
        _notWired(context, l10n, 'copyLink');
      case SearchDialogRowAction.rename:
        if (threadId == null) return;
        final thread = ref
            .read(threadListProvider)
            .items
            .where((t) => t.id == threadId)
            .firstOrNull;
        await renameThreadWithDialog(
          context,
          ref,
          threadId,
          thread?.title ?? '',
        );
      case SearchDialogRowAction.delete:
        if (threadId == null) {
          _notWired(context, l10n, 'delete');
          return;
        }
        final thread = ref
            .read(threadListProvider)
            .items
            .where((t) => t.id == threadId)
            .firstOrNull;
        final deleted = await deleteThreadWithConfirm(
          context,
          ref,
          threadId,
          thread?.title ?? '',
        );
        if (deleted &&
            ref.read(chatControllerProvider).currentThreadId == threadId) {
          ref.read(chatControllerProvider.notifier).newChat();
        }
    }
  }

  /// 历史对话项行尾「⁝」菜单。Rename / Delete 都真落地（`thread/name/set`、
  /// `thread/delete`）；Pin 没有对应内核能力，见下方注释。
  List<
    AppMenuEntry
  >
  _chatItemMenu(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThreadSummary t,
  ) {
    return [
      AppMenuAction(
        icon: Icons.push_pin_outlined,
        label: l10n.navChatPin,
        shortcut: 'P',
        // TODO:sgcode 没有置顶能力（React studio 的「收藏」存在 gateway 自己的
        // per-cid KV 里，客户端这条路还没接）
        onTap: () => _notWired(context,l10n,'pin'),
      ),
      AppMenuAction(
        icon: Icons.edit_outlined,
        label: l10n.navChatRename,
        shortcut: 'R',
        onTap: () => _onRenameChat(
          context,
          ref,
          l10n,
          t.id,
          t.title,
        ),
      ),
      AppMenuAction(
        icon: Icons.delete_outline,
        label: l10n.commonDelete,
        shortcut: 'D',
        danger: true,
        onTap: () => _onDeleteChat(
          context,
          ref,
          l10n,
          t.id,
          t.title,
        ),
      ),
    ];
  }

  /// 改标题。走 sgcode 的 `thread/name/set`（controller 内部乐观更新 + 失败回滚）。
  Future<void> _onRenameChat(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String threadId,
    String current,
  ) =>
      renameThreadWithDialog(context, ref, threadId, current);

  Future<void> _onDeleteChat(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String threadId,
    String label,
  ) async {
    final deleted = await deleteThreadWithConfirm(context, ref, threadId, label);
    // 删的正是当前打开的会话：中栏不能还挂着它，回到干净的新对话。
    if (deleted &&
        ref.read(chatControllerProvider).currentThreadId == threadId) {
      ref.read(chatControllerProvider.notifier).newChat();
    }
  }

  void _notWired(
    BuildContext context,
    AppLocalizations l10n,
    String id,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          l10n.commonNotWired(id,),
          ),
        duration: const Duration(
          seconds: 1,
        ),
      ),
    );
  }

  /// 构建历史对话区域（可能包含多个分组）
  List<NavSection> _buildHistorySections(
    AppLocalizations l10n,
    WidgetRef ref,
    List<ThreadSummary> threads,
    HistorySortGroupState sortGroupState,
    BuildContext context,
  ) {
    // 获取当前排序和分组的标签
    final sortLabel = switch (sortGroupState.sortBy) {
      ChatSortBy.lastActivity => l10n.chatSortLastActivity,
      ChatSortBy.name => l10n.chatSortName,
    };

    final groupLabel = switch (sortGroupState.groupBy) {
      ChatGroupBy.none => l10n.chatGroupNone,
      ChatGroupBy.date => l10n.chatGroupDate,
      ChatGroupBy.assistant => l10n.chatGroupAssistant,
    };

    // 按照当前排序和分组设置处理数据
    final grouped = sortAndGroupHistory(
      threads,
      sortGroupState.sortBy,
      sortGroupState.groupBy,
      (key) => _getGroupTitle(key, l10n),
    );

    // 如果不分组，返回单个 section
    if (sortGroupState.groupBy == ChatGroupBy.none) {
      final items = grouped.first.items;
      return [
        NavSection(
          title: l10n.navHistory,
          collapsible: true,
          viewAllTooltip: l10n.navViewAll,
          onViewAll: () => _onViewAllHistory(context),
          action: NavSectionAction.menu,
          actionTooltip: l10n.chatSortBy,
          menu: [
            AppMenuSubmenu(
              label: l10n.chatGroupBy,
              trailingValue: groupLabel,
              entries: [
                AppMenuAction(
                  label: l10n.chatGroupNone,
                  checked: sortGroupState.groupBy == ChatGroupBy.none,
                  onTap: () => ref
                      .read(historySortGroupControllerProvider.notifier)
                      .setGroupBy(ChatGroupBy.none),
                ),
                AppMenuAction(
                  label: l10n.chatGroupDate,
                  checked: sortGroupState.groupBy == ChatGroupBy.date,
                  onTap: () => ref
                      .read(historySortGroupControllerProvider.notifier)
                      .setGroupBy(ChatGroupBy.date),
                ),
                AppMenuAction(
                  label: l10n.chatGroupAssistant,
                  checked: sortGroupState.groupBy == ChatGroupBy.assistant,
                  onTap: () => _notWired(context, l10n, 'group-by-assistant'),
                ),
              ],
            ),
            AppMenuSubmenu(
              label: l10n.chatSortBy,
              trailingValue: sortLabel,
              entries: [
                AppMenuAction(
                  label: l10n.chatSortName,
                  checked: sortGroupState.sortBy == ChatSortBy.name,
                  onTap: () => ref
                      .read(historySortGroupControllerProvider.notifier)
                      .setSortBy(ChatSortBy.name),
                ),
                AppMenuAction(
                  label: l10n.chatSortLastActivity,
                  checked: sortGroupState.sortBy == ChatSortBy.lastActivity,
                  onTap: () => ref
                      .read(historySortGroupControllerProvider.notifier)
                      .setSortBy(ChatSortBy.lastActivity),
                ),
              ],
            ),
          ],
          entries: [
            for (final t in items.take(_historyLimit))
              NavEntry(
                // 前缀换成 `_threadPrefix`：这条 id 会原样回到 `_onSelect`，
                // 走错前缀就会把 threadId 喂给 `newChatWithScene`。
                id: '$_threadPrefix${t.id}',
                icon: Icons.chat_bubble_outline,
                // 回落已由 Rust 侧 `thread_ops::display_title` 算好，不再自己来一套。
                label: t.title,
                trailingMenu: _chatItemMenu(context, ref, l10n, t),
              ),
            if (threads.length > _historyLimit)
              NavEntry(
                id: _idHistoryMore,
                icon: Icons.more_horiz,
                label: l10n.navViewAll,
                isSpecialAction: true,
              ),
          ],
        ),
      ];
    }

    // 分组模式：第一个section是主标题，后续的是各个日期分组
    final sections = <NavSection>[];

    // 主标题section（不可折叠，带菜单和查看全部按钮）
    sections.add(
      NavSection(
        title: l10n.navHistory,
        collapsible: false,
        viewAllTooltip: l10n.navViewAll,
        onViewAll: () => _onViewAllHistory(context),
        actionTooltip: l10n.chatSortBy,
        action: NavSectionAction.menu,
        menu: [
          AppMenuSubmenu(
            label: l10n.chatGroupBy,
            trailingValue: groupLabel,
            entries: [
              AppMenuAction(
                label: l10n.chatGroupNone,
                checked: sortGroupState.groupBy == ChatGroupBy.none,
                onTap: () => ref
                    .read(historySortGroupControllerProvider.notifier)
                    .setGroupBy(ChatGroupBy.none),
              ),
              AppMenuAction(
                label: l10n.chatGroupDate,
                checked: sortGroupState.groupBy == ChatGroupBy.date,
                onTap: () => ref
                    .read(historySortGroupControllerProvider.notifier)
                    .setGroupBy(ChatGroupBy.date),
              ),
              AppMenuAction(
                label: l10n.chatGroupAssistant,
                checked: sortGroupState.groupBy == ChatGroupBy.assistant,
                onTap: () => _notWired(context, l10n, 'group-by-assistant'),
              ),
            ],
          ),
          AppMenuSubmenu(
            label: l10n.chatSortBy,
            trailingValue: sortLabel,
            entries: [
              AppMenuAction(
                label: l10n.chatSortName,
                checked: sortGroupState.sortBy == ChatSortBy.name,
                onTap: () => ref
                    .read(historySortGroupControllerProvider.notifier)
                    .setSortBy(ChatSortBy.name),
              ),
              AppMenuAction(
                label: l10n.chatSortLastActivity,
                checked: sortGroupState.sortBy == ChatSortBy.lastActivity,
                onTap: () => ref
                    .read(historySortGroupControllerProvider.notifier)
                    .setSortBy(ChatSortBy.lastActivity),
              ),
            ],
          ),
        ],
        entries: const [], // 主标题section不显示任何条目
      ),
    );

    // 为每个日期分组创建可折叠的section
    for (var i = 0; i < grouped.length; i++) {
      final group = grouped[i];
      final isCollapsed = sortGroupState.collapsedGroups.contains(group.groupKey);
      final isFirstGroup = i == 0; // 第一个分组
      final hasMore = group.items.length > _historyLimit; // 该分组是否超过20条

      sections.add(
        NavSection(
          title: group.groupTitle,
          collapsible: true, // 每个日期分组都可折叠
          isCollapsed: isCollapsed, // 传入折叠状态
          // 只有第一个分组需要"查看全部"和菜单按钮
          viewAllTooltip: isFirstGroup ? l10n.navViewAll : null,
          onViewAll: isFirstGroup ? () => _onViewAllHistory(context) : null,
          action: isFirstGroup ? NavSectionAction.menu : NavSectionAction.none,
          actionTooltip: isFirstGroup ? l10n.chatSortBy : null,
          menu: isFirstGroup ? [
            AppMenuSubmenu(
              label: l10n.chatGroupBy,
              trailingValue: groupLabel,
              entries: [
                AppMenuAction(
                  label: l10n.chatGroupNone,
                  checked: sortGroupState.groupBy == ChatGroupBy.none,
                  onTap: () => ref
                      .read(historySortGroupControllerProvider.notifier)
                      .setGroupBy(ChatGroupBy.none),
                ),
                AppMenuAction(
                  label: l10n.chatGroupDate,
                  checked: sortGroupState.groupBy == ChatGroupBy.date,
                  onTap: () => ref
                      .read(historySortGroupControllerProvider.notifier)
                      .setGroupBy(ChatGroupBy.date),
                ),
                AppMenuAction(
                  label: l10n.chatGroupAssistant,
                  checked: sortGroupState.groupBy == ChatGroupBy.assistant,
                  onTap: () => _notWired(context, l10n, 'group-by-assistant'),
                ),
              ],
            ),
            AppMenuSubmenu(
              label: l10n.chatSortBy,
              trailingValue: sortLabel,
              entries: [
                AppMenuAction(
                  label: l10n.chatSortName,
                  checked: sortGroupState.sortBy == ChatSortBy.name,
                  onTap: () => ref
                      .read(historySortGroupControllerProvider.notifier)
                      .setSortBy(ChatSortBy.name),
                ),
                AppMenuAction(
                  label: l10n.chatSortLastActivity,
                  checked: sortGroupState.sortBy == ChatSortBy.lastActivity,
                  onTap: () => ref
                      .read(historySortGroupControllerProvider.notifier)
                      .setSortBy(ChatSortBy.lastActivity),
                ),
              ],
            ),
          ] : [],
          onToggleCollapse: () => ref
              .read(historySortGroupControllerProvider.notifier)
              .toggleGroupCollapse(group.groupKey),
          entries: isCollapsed
              ? []
              : [
                  // 最多显示20条
                  for (final t in group.items.take(_historyLimit))
                    NavEntry(
                      // 同上：分组模式是历史区的**另一条**渲染路径，
                      // 两处前缀必须一起改 —— 只改一处的话，换个分组方式
                      // 就又会把 threadId 当 sceneId 用。
                      id: '$_threadPrefix${t.id}',
                      icon: Icons.chat_bubble_outline,
                      label: t.title,
                      trailingMenu: _chatItemMenu(context, ref, l10n, t),
                    ),
                  // 超过20条时显示"查看全部"
                  if (hasMore)
                    NavEntry(
                      id: _idHistoryMore,
                      icon: Icons.more_horiz,
                      label: l10n.navViewAll,
                      isSpecialAction: true,
                    ),
                ],
        ),
      );
    }

    return sections;
  }

  /// 分组标题。三档：今天 / 昨天 / 更早，外加一个"时间未知"兜底。
  String _getGroupTitle(String key, AppLocalizations l10n) {
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
}
