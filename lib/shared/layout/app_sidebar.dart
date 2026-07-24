import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_controller.dart';
import '../widgets/glass_card.dart';
import 'nav_item.dart';

/// 侧边导航栏。圆角毛玻璃，只显示图标，鼠标悬浮显示文字（Tooltip）。
class AppSidebar extends ConsumerWidget {
  const AppSidebar({
    super.key,
    required this.items,
    required this.currentRoute,
    this.collapsed = false,
    this.onNavigate,
  });

  final List<NavItemData> items;
  final String currentRoute;
  final bool collapsed;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: IntrinsicHeight( // 自适应内容高度
          child: SizedBox(
            width: 64, // 固定宽度，只显示图标
            child: Column(
              mainAxisSize: MainAxisSize.min, // 高度适应内容
              crossAxisAlignment: CrossAxisAlignment.center,
              children: items.map((item) => _buildItem(context, ref, item)).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(BuildContext context, WidgetRef ref, NavItemData item) {
    final selected = currentRoute == item.route;
    final theme = Theme.of(context);
    final transparentMode =
        ref.watch(themeControllerProvider.select((s) => s.transparentMode));

    // 透明模式下图标统一用白色
    final Color color;
    if (transparentMode) {
      color = selected ? Colors.white : Colors.white.withValues(alpha: 0.6);
    } else {
      color = selected
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }

    return Tooltip(
      message: item.label, // 悬浮显示文字
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () {
            if (currentRoute != item.route) context.go(item.route);
            onNavigate?.call();
          },
          child: Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(item.icon, color: color, size: 24),
          ),
        ),
      ),
    );
  }
}
