import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sgit_studio_flutter/features/auth/application/auth_controller.dart';
import 'package:sgit_studio_flutter/features/studio/application/studio_controllers.dart';
import 'package:sgit_studio_flutter/features/studio/studio_page_specs.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/panels/models/nav_entry.dart';
import 'package:sgit_studio_flutter/layout/panels/nav_panel.dart';
import 'package:sgit_studio_flutter/router/route_names.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/services/brand/brand_assets.dart';
import 'package:sgit_studio_flutter/services/brand/brand_config.dart';
import 'package:sgit_studio_flutter/services/layout/layout_controller.dart';

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
  static const String _idAgent = 'nav.agent';

  /// 助理项的 id 前缀，避免与 studio 的 key 撞。
  static const String _assistantPrefix = 'assistant:';

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final l10n = AppLocalizations.of(
      context,
    );
    // 助理 = 场景（scene）。与「场景」子页同一个数据源，不另开一条取列表的路。
    final scenes = ref
        .watch(
          resourceListProvider(
            StudioPageSpecs.scenes,
          ),
        )
        .items;

    return NavPanel(
      brandMark: BrandAssets.image(
        BrandAssets.loginMark,
      ),
      brandName: BrandConfig.instance.name,
      activeId: activeNavId,
      // 导航行：新对话、输出物、智能体
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
          id: _idAgent,
          icon: Icons.tune,
          label: l10n.navStudioGroup,
        ),
      ],
      sections: [
        // 置顶区：位于导航行下方、历史对话上方。空着也要出现（靠 emptyHint 撑住），
        // 否则用户不知道有「置顶」这回事。
        NavSection(
          title: '置顶',
          action: NavSectionAction.add,
          emptyHint: 'Pin projects to keep them here',
          emptyHintIcon: Icons.push_pin_outlined,
          entries: const [
            // TODO: 接置顶对话列表（内核还没放开 thread/pin）。
          ],
        ),
        // 历史对话：标题带收起箭头，右侧是菜单/排序项。
        NavSection(
          title: l10n.navHistory,
          collapsible: true,
          action: NavSectionAction.sort,
          entries: [
            // TODO: 换成 thread/list 的真实历史，scenes 只是临时占位。
            for (final sc in scenes)
              NavEntry(
                id: '$_assistantPrefix${sc.id}',
                icon: Icons.chat_bubble_outline,
                label: sc.name.isEmpty
                    ? sc.id
                    : sc.name,
              ),
          ],
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
      userName: BrandConfig.instance.orgName,
      userActionTooltip: l10n.navLogout,
      onUserAction: () => ref
          .read(
            authControllerProvider.notifier,
          )
          .logout(),
      searchTooltip: l10n.navSearch,
      collapseTooltip: l10n.shellCollapseNav,
      settingsLabel: l10n.navSettings,
      groupByLabel: l10n.chatGroupBy,
      groupByValue: l10n.chatGroupNone,
      sortByLabel: l10n.chatSortBy,
      sortByValue: l10n.chatSortLastActivity,
      onSearch: () => _onSearch(
        context,
        l10n,
      ),
      onCollapse: () => ref
          .read(
            layoutControllerProvider.notifier,
          )
          .toggleNav(),
      onAddProject: () => _onAddProject(
        context,
        l10n,
      ),
      onSortChats: () => _onSortChats(
        context,
        l10n,
      ),
      onSettings: () => context.go(
        RouteNames.settings,
      ),
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
      case _idAgent:
        // 这些功能待实现
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
      default:
        context.go(
          RouteNames.studio(
            id,
          ),
        );
    }
  }

  void _onSearch(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    _notWired(
      context,
      l10n,
      'search',
    );
  }

  void _onAddProject(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    // TODO: 实现添加项目到 Projects 区域
    _notWired(
      context,
      l10n,
      'add-project',
    );
  }

  void _onSortChats(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    // TODO: 实现对话列表排序
    _notWired(
      context,
      l10n,
      'sort-chats',
    );
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
          l10n.commonNotWired(
            id,
          ),
        ),
        duration: const Duration(
          seconds: 1,
        ),
      ),
    );
  }
}
