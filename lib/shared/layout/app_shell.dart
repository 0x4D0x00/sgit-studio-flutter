import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/platform/window_bar/app_window_bar.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/auth/auth_controller.dart';
import '../utils/responsive.dart';
import 'app_sidebar.dart';
import 'layered_scaffold.dart';
import 'nav_item.dart';

/// 全端自适应外壳。承载 GoRouter ShellRoute。
///
/// 结构:整页套 [LayeredScaffold](L1/L2/L3) → 顶部透明窗口 bar → (侧栏 | 内容)。
/// 因为背景透明由三层结构负责，这里的 Scaffold 也保持透明。
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.currentRoute});

  final Widget child;
  final String currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final items = <NavItemData>[
      NavItemData(icon: Icons.dashboard_rounded, label: l10n.navDashboard, route: RouteNames.dashboard),
      NavItemData(icon: Icons.people_rounded, label: l10n.navUsers, route: RouteNames.users),
      NavItemData(icon: Icons.account_tree_rounded, label: l10n.navOrganizations, route: RouteNames.organizations),
      NavItemData(icon: Icons.shield_rounded, label: l10n.navPermissions, route: RouteNames.permissions),
      NavItemData(icon: Icons.hub_rounded, label: l10n.navModels, route: RouteNames.models),
      NavItemData(icon: Icons.vpn_key_rounded, label: l10n.navApiKeys, route: RouteNames.apikeys),
      NavItemData(icon: Icons.settings_rounded, label: l10n.navSettings, route: RouteNames.settings),
    ];

    return LayeredScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: context.useDrawerNav
            ? Drawer(
                backgroundColor:
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                child: SafeArea(
                  child: Builder(
                    builder: (ctx) => AppSidebar(
                      items: items,
                      currentRoute: currentRoute,
                      onNavigate: () => Scaffold.of(ctx).closeDrawer(),
                    ),
                  ),
                ),
              )
            : null,
        body: Column(
          children: [
            // 顶部透明窗口 bar(桌面);Web/移动自动 0 高。
            AppWindowBar(),
            Expanded(child: _bodyByLayout(context, ref, items)),
          ],
        ),
      ),
    );
  }

  Widget _bodyByLayout(BuildContext context, WidgetRef ref, List<NavItemData> items) {
    if (context.useDrawerNav) {
      return Column(
        children: [
          _mobileTopBar(context, ref),
          Expanded(child: _content(context, child)),
        ],
      );
    }
    // 桌面/平板：强制折叠模式（只显示图标）
    return Row(
      children: [
        AppSidebar(items: items, currentRoute: currentRoute, collapsed: true),
        Expanded(child: _content(context, child)),
      ],
    );
  }

  Widget _mobileTopBar(BuildContext context, WidgetRef ref) {
    return Builder(
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, Widget child) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.contentMaxWidth),
        child: Padding(
          padding: EdgeInsets.all(context.isMobile ? AppSpacing.md : AppSpacing.lg),
          child: child,
        ),
      ),
    );
  }
}
