import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sgit_studio_flutter/features/auth/application/auth_controller.dart';
import 'package:sgit_studio_flutter/features/studio/application/studio_controllers.dart';
import 'package:sgit_studio_flutter/features/studio/studio_feature.dart';
import 'package:sgit_studio_flutter/features/studio/studio_page_specs.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/panels/models/nav_entry.dart';
import 'package:sgit_studio_flutter/layout/panels/nav_panel.dart';
import 'package:sgit_studio_flutter/router/route_names.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/services/brand/brand_assets.dart';
import 'package:sgit_studio_flutter/services/brand/brand_config.dart';

/// 左栏容器 —— 把 provider / 路由 / 品牌 / l10n 喂给纯组件 `NavPanel`。
///
/// 这一层是**唯一**知道「导航项从哪来、点了去哪」的地方。`NavPanel` 只认 [NavEntry]，
/// 所以换状态库、换路由库都只动本文件。
class NavPanelContainer extends ConsumerWidget {
  const NavPanelContainer({super.key, this.activeStudioKey});

  /// 当前处于哪个「智能体」子页（对应 studio 的 `?studio=<key>`）。
  final String? activeStudioKey;

  // 非 studio 的固定项 id。用常量而非字面量，避免和 studio key 撞。
  static const String _idSearch = 'nav.search';
  static const String _idNewChat = 'nav.new-chat';
  static const String _idHistory = 'nav.history';

  /// 助理项的 id 前缀，避免与 studio 的 key 撞。
  static const String _assistantPrefix = 'assistant:';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final studioPages = ref.watch(visibleStudioPagesProvider);
    // 助理 = 场景（scene）。与「场景」子页同一个数据源，不另开一条取列表的路。
    final scenes = ref.watch(resourceListProvider(StudioPageSpecs.scenes)).items;

    return NavPanel(
      brandMark: BrandAssets.image(BrandAssets.loginMark),
      brandName: BrandConfig.instance.name,
      activeId: activeStudioKey,
      header: [
        NavEntry(id: _idSearch, icon: Icons.search_rounded, label: l10n.navSearch),
      ],
      sections: [
        NavSection(entries: [
          NavEntry(
              id: _idNewChat,
              icon: Icons.add_comment_outlined,
              label: l10n.navNewChat),
          NavEntry(
              id: _idHistory,
              icon: Icons.history_rounded,
              label: l10n.navHistory),
        ]),
        // 助理区：点一个场景 = 用该场景开新对话。
        NavSection(
          title: l10n.navAssistants,
          entries: [
            for (final sc in scenes)
              NavEntry(
                id: '$_assistantPrefix${sc.id}',
                icon: Icons.smart_toy_outlined,
                label: sc.name.isEmpty ? sc.id : sc.name,
              ),
          ],
        ),
        // 智能体区：判权后才显示；整组为空时连组标题都不出现。
        NavSection(
          title: l10n.navStudioGroup,
          entries: [
            for (final p in studioPages)
              NavEntry(id: p.key, icon: p.icon, label: p.label(l10n)),
          ],
        ),
      ],
      onSelect: (id) => _onSelect(context, ref, l10n, id),
      userName: BrandConfig.instance.orgName,
      userActionTooltip: l10n.navLogout,
      onUserAction: () => ref.read(authControllerProvider.notifier).logout(),
    );
  }

  void _onSelect(
      BuildContext context, WidgetRef ref, AppLocalizations l10n, String id) {
    // 用 switch 而非 if-else 链：将来接上剩下的项时，漏改一个分支会在这里显形。
    switch (id) {
      case _idNewChat:
        // 清空当前会话 + 让下次发消息新建 thread，然后回到工作台。
        ref.read(chatControllerProvider.notifier).newChat();
        context.go(RouteNames.home);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(l10n.navNewChatDone),
              duration: const Duration(seconds: 1)),
        );
      case final String a when a.startsWith(_assistantPrefix):
        // 切助理 = 用该场景开一轮新对话。场景 id 即 thread 的归属，
        // 由内核决定怎么用（我们只负责把选择传下去）。
        ref
            .read(chatControllerProvider.notifier)
            .newChatWithScene(a.substring(_assistantPrefix.length));
        context.go(RouteNames.home);
      case _idSearch:
      case _idHistory:
        // 会话检索与历史列表要 thread/list、thread/search 两个内核方法，
        // 中继的受限动作集里还没放开 —— 明说待接，别装作能用。
        _notWired(context, l10n, id);
      default:
        context.go(RouteNames.studio(id));
    }
  }

  void _notWired(BuildContext context, AppLocalizations l10n, String id) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.commonNotWired(id)),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
