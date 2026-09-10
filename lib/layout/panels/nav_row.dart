import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/layout/panels/models/nav_entry.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 一条导航行：品牌下的顶部导航、置顶项、历史对话item 通用。
///
/// ⚠️ **纯展示组件**：不 import 状态管理库、不 import features、不判 `isDark`。
///
/// 带 [NavEntry.menu] 的行走悬停菜单（智能体行）：`AppMenuAnchor` 自带
/// 触发器的点击/悬停，所以那种行不能再套一层自己的 `InkWell` —— 两层点击
/// 手势会互相吃掉，菜单钉不住。
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.menuOpen,
    required this.onSelect,
    required this.onMenuOpenChanged,
    this.isHeader = false,
    this.isChatItem = false,
  });

  final NavEntry entry;
  final bool selected;

  /// 这一行的悬停菜单当前是否开着（由容器/父状态持有，这里只读）。
  final bool menuOpen;

  final ValueChanged<String> onSelect;
  final ValueChanged<bool> onMenuOpenChanged;

  /// 顶部导航行（New、Projects 等），与品牌行左对齐。
  final bool isHeader;

  /// 历史对话列表项，采用无序列表样式（圆点 + 文字）。
  final bool isChatItem;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    // 菜单开着时这一行保持高亮，否则菜单飘在外面、行是灰的，看着不像一对。
    // 停在某个子页里时也算 —— 那一行是子页的归属。
    final highlighted = selected || menuOpen || entry.menuHasChecked;
    final fg = highlighted ? skin.text : skin.textSecondary;

    final content = SizedBox(
      height: WorkspaceMetrics.navItemHeight,
      child: Padding(
        padding: EdgeInsets.only(
          left: isHeader || isChatItem ? 24 : WorkspaceMetrics.navItemPaddingInline,
          right: WorkspaceMetrics.navItemPaddingInline,
        ),
        child: Row(
          children: [
            // 历史对话列表项显示圆点而非图标
            if (isChatItem)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fg.withOpacity(0.6),
                ),
              )
            else
              Icon(entry.icon, size: WorkspaceMetrics.navIconSize, color: fg),
            if (!isChatItem)
              const SizedBox(width: WorkspaceMetrics.navItemGap),
            Expanded(
              child: Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
                  color: fg,
                ),
              ),
            ),
            // 有子菜单就给个「往右还有」的提示，否则用户不知道这行能悬停。
            if (entry.hasMenu)
              Icon(Icons.chevron_right, size: 16, color: fg),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 0.5),
      child: Material(
        color: highlighted ? skin.navItemActive : Colors.transparent,
        borderRadius: BorderRadius.circular(WorkspaceMetrics.navItemRadius),
        clipBehavior: Clip.antiAlias,
        child: entry.hasMenu
            ? AppMenuAnchor(
                entries: entry.menu,
                trigger: AppMenuTrigger.hover,
                align: AppMenuAlign.end,
                semanticLabel: entry.label,
                onOpenChanged: onMenuOpenChanged,
                child: content,
              )
            : InkWell(
                onTap: () => onSelect(entry.id),
                child: content,
              ),
      ),
    );
  }
}
