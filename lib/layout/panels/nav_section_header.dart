import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/layout/panels/models/nav_entry.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 导航分组的标题行：标题 +（可选）展开箭头 +（可选）右侧操作按钮。
///
/// ⚠️ **纯展示组件**：折叠态由外部持有，这里只读 [collapsed] 并回调 [onToggleCollapse]。
class NavSectionHeader extends StatelessWidget {
  const NavSectionHeader({
    super.key,
    required this.section,
    required this.collapsed,
    this.onToggleCollapse,
    this.onAddProject,
    this.hovered = false,
  });

  final NavSection section;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;
  final VoidCallback? onAddProject;

  /// 鼠标是否停在整个分组（标题 + 条目）上。折叠箭头、查看全部只在悬停时显示
  /// （Opacity 保留占位，标题行宽度不跳动）。
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 8, top: 6, bottom: 2),
      child: Row(
        children: [
          // 标题（可折叠的带点击）
          if (section.collapsible)
            InkWell(
              onTap: onToggleCollapse,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _title(skin),
                    const SizedBox(width: 4),
                    Opacity(
                      opacity: hovered ? 1 : 0,
                      child: Icon(
                        collapsed ? Icons.chevron_right : Icons.expand_more,
                        size: 16,
                        color: skin.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            _title(skin),
          const Spacer(),
          // 「查看全部」箭头 —— 画在操作按钮**前面**，两者是独立热区。
          if (section.viewAllTooltip != null && section.onViewAll != null)
            Opacity(
              opacity: hovered ? 1 : 0,
              child: InkWell(
                onTap: section.onViewAll,
                borderRadius: BorderRadius.circular(4),
                child: Tooltip(
                  message: section.viewAllTooltip!,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.north_east,
                      size: 14,
                      color: skin.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          // 搜索按钮 —— 紧贴排序/分组菜单按钮左侧。
          if (section.onSearch != null)
            InkWell(
              onTap: section.onSearch,
              borderRadius: BorderRadius.circular(4),
              child: Tooltip(
                message: section.searchTooltip ?? '',
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.search,
                    size: 16,
                    color: skin.textSecondary,
                  ),
                ),
              ),
            ),
          // 操作按钮
          if (section.action == NavSectionAction.add && onAddProject != null)
            InkWell(
              onTap: onAddProject,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  section.actionIcon ?? Icons.add,
                  size: 16,
                  color: skin.textSecondary,
                ),
              ),
            )
          else if (section.action == NavSectionAction.menu &&
              section.menu.isNotEmpty)
            AppMenuAnchor(
              entries: section.menu,
              minWidth: 180,
              child: Tooltip(
                message: section.actionTooltip ?? '',
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    section.actionIcon ?? Icons.tune,
                    size: 16,
                    color: skin.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _title(AppSkin skin) => Text(
        section.title!,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: skin.textSecondary,
        ),
      );
}

/// 空组占位提示（设计图里 Projects 空时的「Pin chats to keep them here」）。
class NavSectionEmptyHint extends StatelessWidget {
  const NavSectionEmptyHint({super.key, required this.section});

  final NavSection section;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: WorkspaceMetrics.navItemPaddingInline,
        vertical: 10,
      ),
      child: Row(
        children: [
          if (section.emptyHintIcon != null) ...[
            Icon(
              section.emptyHintIcon,
              size: WorkspaceMetrics.navIconSize,
              color: skin.textTertiary,
            ),
            const SizedBox(width: WorkspaceMetrics.navItemGap),
          ],
          Expanded(
            child: Text(
              section.emptyHint!,
              style: TextStyle(fontSize: 14, color: skin.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
