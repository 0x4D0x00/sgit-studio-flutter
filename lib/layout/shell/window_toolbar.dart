import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 顶部工具行的一个文字菜单（文件 / 编辑 / 视图 / 帮助）。
class WindowMenu {
  const WindowMenu({required this.label, required this.entries});

  final String label;
  final List<AppMenuEntry> entries;
}

/// 窗口左上角工具行：后退 / 前进 / 收起·展开导航 / 文字菜单。
///
/// ⚠️ **纯展示组件**：状态与回调由 `AppShellContainer` 注入。
class WindowToolbar extends StatelessWidget {
  const WindowToolbar({
    super.key,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onToggleNav,
    required this.navExpanded,
    required this.backTooltip,
    required this.forwardTooltip,
    required this.toggleNavTooltip,
    required this.menus,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onToggleNav;

  /// 决定第三个按钮显示「收起」还是「展开」的图标与 tooltip 由调用方给。
  final bool navExpanded;
  final String backTooltip;
  final String forwardTooltip;
  final String toggleNavTooltip;
  final List<WindowMenu> menus;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconBtn(
          icon: Icons.arrow_back_rounded,
          tooltip: backTooltip,
          onPressed: canGoBack ? onBack : null,
        ),
        _IconBtn(
          icon: Icons.arrow_forward_rounded,
          tooltip: forwardTooltip,
          onPressed: canGoForward ? onForward : null,
        ),
        _IconBtn(
          icon: navExpanded
              ? Icons.menu_open_rounded
              : Icons.view_sidebar_outlined,
          tooltip: toggleNavTooltip,
          onPressed: onToggleNav,
        ),
        const SizedBox(width: 4),
        for (final m in menus)
          AppMenuAnchor(
            align: AppMenuAlign.under,
            entries: m.entries,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                m.label,
                style: TextStyle(fontSize: 14, color: skin.textSecondary),
              ),
            ),
          ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return IconButton(
      iconSize: 18,
      visualDensity: VisualDensity.compact,
      color: skin.textSecondary,
      disabledColor: skin.textTertiary,
      tooltip: tooltip,
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}
