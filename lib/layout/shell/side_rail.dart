import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 最左侧工具列的一项。[menu] 非空时点击弹菜单而不是触发 [onTap]。
class SideRailItem {
  const SideRailItem({
    required this.icon,
    required this.tooltip,
    this.selected = false,
    this.onTap,
    this.menu = const [],
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback? onTap;
  final List<AppMenuEntry> menu;
}

/// 最左侧窄工具列 —— 固定宽度，**不可收起**（不参与 nav 的展开/折叠）。
///
/// ⚠️ **纯展示组件**：项目由容器注入。
class SideRail extends StatelessWidget {
  const SideRail({super.key, required this.items, this.bottom});

  final List<SideRailItem> items;

  /// 列底部（头像等）。
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return SizedBox(
      width: WorkspaceMetrics.railWidth,
      child: ColoredBox(
        color: skin.layoutBg,
        child: Column(
          children: [
            const SizedBox(height: 8),
            for (final item in items) _RailButton(item: item),
            const Spacer(),
            if (bottom != null) ...[bottom!, const SizedBox(height: 12)],
          ],
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({required this.item});

  final SideRailItem item;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    Widget button(VoidCallback? onTap) => Tooltip(
          message: item.tooltip,
          child: Material(
            color: item.selected ? skin.navItemActive : Colors.transparent,
            borderRadius: BorderRadius.circular(WorkspaceMetrics.navItemRadius),
            child: InkWell(
              borderRadius:
                  BorderRadius.circular(WorkspaceMetrics.navItemRadius),
              onTap: onTap,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  item.icon,
                  size: 20,
                  color: item.selected ? skin.text : skin.textSecondary,
                ),
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: item.menu.isEmpty
          ? button(item.onTap)
          : AppMenuAnchor(
              align: AppMenuAlign.end,
              entries: item.menu,
              child: button(null),
            ),
    );
  }
}
