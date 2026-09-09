import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/layout/panels/models/nav_entry.dart';

/// 左侧导航栏 —— 重构
///
/// 结构：
/// ```
/// 1. 品牌行
/// 2. 导航行（新对话、输出物、智能体）
/// 3. 置顶区域（带 Pin 提示）
/// 4. 历史对话列表（可折叠、可滚动）
/// 5. 用户区域（点击显示菜单）
/// ```
/// ⚠️ **纯展示组件**：不 import 状态管理库、不 import features、不判 `isDark`。
/// 数据与回调全部由 `features/shell/presentation/nav_panel_container.dart` 注入。
class NavPanel
    extends
        StatefulWidget {
  const NavPanel({
    super.key,
    required this.brandMark,
    required this.brandName,
    required this.header,
    required this.sections,
    required this.activeId,
    required this.onSelect,
    required this.userName,
    required this.userActionTooltip,
    required this.onUserAction,
    required this.searchTooltip,
    required this.collapseTooltip,
    required this.settingsLabel,
    required this.groupByLabel,
    required this.groupByValue,
    required this.sortByLabel,
    required this.sortByValue,
    this.onSearch,
    this.onCollapse,
    this.onAddProject,
    this.onSortChats,
    this.onSettings,
  });

  final ImageProvider brandMark;
  final String brandName;
  final List<
    NavEntry
  >
  header;
  final List<
    NavSection
  >
  sections;
  final String? activeId;
  final ValueChanged<
    String
  >
  onSelect;
  final String userName;
  final String userActionTooltip;
  final VoidCallback onUserAction;

  /// 用户区右下角搜索按钮的 tooltip。
  final String searchTooltip;

  /// 搜索右边那颗收起按钮的 tooltip。收起左栏的入口**只有这一处**
  /// （中栏顶栏只负责展开），所以它得说清楚自己是干什么的。
  final String collapseTooltip;

  /// 用户菜单里「设置」一项的文案（「退出」复用 [userActionTooltip]）。
  final String settingsLabel;

  /// 会话列表菜单的两行：标签 + 当前值。
  final String groupByLabel;
  final String groupByValue;
  final String sortByLabel;
  final String sortByValue;

  final VoidCallback? onSearch;
  final VoidCallback? onCollapse;
  final VoidCallback? onAddProject;
  final VoidCallback? onSortChats;
  final VoidCallback? onSettings;

  @override
  State<
    NavPanel
  >
  createState() => _NavPanelState();
}

class _NavPanelState
    extends
        State<
          NavPanel
        > {
  bool _chatsCollapsed = false;

  @override
  Widget build(
    BuildContext context,
  ) {
    final skin = AppSkin.of(
      context,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: WorkspaceMetrics.navPanelPaddingBlock,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 品牌行
          _brand(
            skin,
          ),

          // 2. 导航行
          if (widget.header.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: WorkspaceMetrics.navPanelPaddingInline,
              ),
              child: Column(
                children: [
                  for (final e in widget.header)
                    _row(
                      skin,
                      e,
                    ),
                ],
              ),
            ),

          const SizedBox(
            height: 6,
          ),

          // 3-4. 可滚动区域（置顶和历史会话列表）
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: WorkspaceMetrics.navPanelPaddingInline,
              ),
              children: [
                for (final s in widget.sections)
                  if (!s.isEmpty) ...[
                    // 组标题行（带操作按钮）
                    if (s.title !=
                        null)
                      _sectionHeader(
                        skin,
                        s,
                      ),

                    // 空组走占位提示
                    if (s.entries.isEmpty)
                      _emptyHint(
                        skin,
                        s,
                      )
                    else if (!_chatsCollapsed ||
                        !s.collapsible)
                      // 未折叠或不可折叠的组显示条目
                      for (final e in s.entries)
                        _row(
                          skin,
                          e,
                        ),

                    const SizedBox(
                      height: 8,
                    ),
                  ],
              ],
            ),
          ),

          // 5. 分割线
          _divider(
            skin,
          ),

          // 6. 用户区域
          _userArea(
            skin,
          ),
        ],
      ),
    );
  }

  /// 组标题行：标题 +（可选）展开箭头 +（可选）右侧操作按钮。
  Widget _sectionHeader(
    AppSkin skin,
    NavSection section,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 8,
        right: 4,
        top: 6,
        bottom: 2,
      ),
      child: Row(
        children: [
          // 标题（可折叠的带点击）
          if (section.collapsible)
            InkWell(
              onTap: () => setState(
                () => _chatsCollapsed = !_chatsCollapsed,
              ),
              borderRadius: BorderRadius.circular(
                4,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      section.title!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: skin.textSecondary,
                      ),
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    Icon(
                      _chatsCollapsed
                          ? Icons.chevron_right
                          : Icons.expand_more,
                      size: 16,
                      color: skin.textSecondary,
                    ),
                  ],
                ),
              ),
            )
          else
            Text(
              section.title!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: skin.textSecondary,
              ),
            ),
          const Spacer(),
          // 操作按钮
          if (section.action ==
                  NavSectionAction.add &&
              widget.onAddProject !=
                  null)
            InkWell(
              onTap: widget.onAddProject,
              borderRadius: BorderRadius.circular(
                4,
              ),
              child: Padding(
                padding: const EdgeInsets.all(
                  4,
                ),
                child: Icon(
                  Icons.add,
                  size: 16,
                  color: skin.textSecondary,
                ),
              ),
            )
          else if (section.action ==
              NavSectionAction.sort)
            PopupMenuButton<
              String
            >(
              icon: Icon(
                Icons.tune,
                size: 16,
                color: skin.textSecondary,
              ),
              offset: const Offset(
                0,
                8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  8,
                ),
              ),
              padding: EdgeInsets.zero,
              itemBuilder:
                  (
                    context,
                  ) => [
                    PopupMenuItem(
                      enabled: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        widget.groupByLabel,
                        style: TextStyle(
                          fontSize: 14,
                          color: skin.text,
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      enabled: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        widget.sortByLabel,
                        style: TextStyle(
                          fontSize: 14,
                          color: skin.text,
                        ),
                      ),
                    ),
                  ],
            ),
        ],
      ),
    );
  }

  /// 空组占位提示（设计图里 Projects 空时的「Pin projects to keep them here」）。
  Widget
  _emptyHint(
    AppSkin skin,
    NavSection section,
  ) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: WorkspaceMetrics.navItemPaddingInline,
      vertical: 10,
    ),
    child: Row(
      children: [
        if (section.emptyHintIcon !=
            null) ...[
          Icon(
            section.emptyHintIcon,
            size: WorkspaceMetrics.navIconSize,
            color: skin.textTertiary,
          ),
          const SizedBox(
            width: WorkspaceMetrics.navItemGap,
          ),
        ],
        Expanded(
          child: Text(
            section.emptyHint!,
            style: TextStyle(
              fontSize: 14,
              color: skin.textTertiary,
            ),
          ),
        ),
      ],
    ),
  );

  /// 品牌行：字标。
  Widget
  _brand(
    AppSkin skin,
  ) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 24,
      vertical: 8,
    ),
    child: Text(
      widget.brandName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: WorkspaceMetrics.brandFontSize,
        fontWeight: FontWeight.w700,
        height: 1,
        color: skin.text,
      ),
    ),
  );

  /// 导航行：height 48 / 圆角 8 / paddingInline 16 / gap 8 / 图标 18。
  Widget _row(
    AppSkin skin,
    NavEntry e,
  ) {
    final selected =
        widget.activeId ==
        e.id;
    final fg = selected
        ? skin.text
        : skin.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 0.5,
      ),
      child: Material(
        color: selected
            ? skin.navItemActive
            : Colors.transparent,
        borderRadius: BorderRadius.circular(
          WorkspaceMetrics.navItemRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => widget.onSelect(
            e.id,
          ),
          child: SizedBox(
            height: WorkspaceMetrics.navItemHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: WorkspaceMetrics.navItemPaddingInline,
              ),
              child: Row(
                children: [
                  Icon(
                    e.icon,
                    size: WorkspaceMetrics.navIconSize,
                    color: fg,
                  ),
                  const SizedBox(
                    width: WorkspaceMetrics.navItemGap,
                  ),
                  Expanded(
                    child: Text(
                      e.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget
  _divider(
    AppSkin skin,
  ) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 24,
    ),
    child: Container(
      height: 1,
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      color: skin.borderSecondary,
    ),
  );

  /// 用户区域：左侧头像+名字（点击显示菜单），右侧收起侧边栏按钮
  Widget
  _userArea(
    AppSkin skin,
  ) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 8,
    ),
    child: SizedBox(
      height: WorkspaceMetrics.navItemHeight,
      child: Row(
        children: [
          // 左侧：头像+用户名（点击显示菜单）
          Expanded(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(
                WorkspaceMetrics.navItemRadius,
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _showUserMenu,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: skin.navItemActive,
                        child: Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: skin.text,
                        ),
                      ),
                      const SizedBox(
                        width: 8,
                      ),
                      Expanded(
                        child: Text(
                          widget.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: skin.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 右侧：搜索按钮
          if (widget.onSearch !=
              null)
            IconButton(
              icon: Icon(
                Icons.search,
                size: 20,
                color: skin.textSecondary,
              ),
              onPressed: widget.onSearch,
              tooltip: widget.searchTooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),

          // 收起侧边栏按钮
          if (widget.onCollapse !=
              null)
            IconButton(
              icon: Icon(
                Icons.menu_open_sharp,
                size: 20,
                color: skin.textSecondary,
              ),
              onPressed: widget.onCollapse,
              tooltip: widget.collapseTooltip,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
        ],
      ),
    ),
  );

  /// 显示用户菜单（设置 + 退出登录）。
  void _showUserMenu() {
    final skin = AppSkin.of(
      context,
    );

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder:
          (
            context,
          ) => Stack(
            children: [
              Positioned(
                left: 24,
                bottom: 80,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(
                    8,
                  ),
                  child: Container(
                    width: 240,
                    decoration: BoxDecoration(
                      color: skin.containerBg,
                      borderRadius: BorderRadius.circular(
                        8,
                      ),
                      border: Border.all(
                        color: skin.border,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 用户邮箱/名称
                        Padding(
                          padding: const EdgeInsets.all(
                            12,
                          ),
                          child: Text(
                            widget.userName,
                            style: TextStyle(
                              fontSize: 13,
                              color: skin.textSecondary,
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: skin.borderSecondary,
                        ),

                        // 设置
                        if (widget.onSettings !=
                            null)
                          ListTile(
                            leading: Icon(
                              Icons.settings_outlined,
                              size: 18,
                              color: skin.text,
                            ),
                            title: Text(
                              widget.settingsLabel,
                              style: TextStyle(
                                fontSize: 14,
                                color: skin.text,
                              ),
                            ),
                            dense: true,
                            onTap: () {
                              Navigator.pop(
                                context,
                              );
                              widget.onSettings?.call();
                            },
                          ),

                        Divider(
                          height: 1,
                          color: skin.borderSecondary,
                        ),

                        // 退出登录
                        ListTile(
                          leading: Icon(
                            Icons.logout,
                            size: 18,
                            color: skin.text,
                          ),
                          title: Text(
                            widget.userActionTooltip,
                            style: TextStyle(
                              fontSize: 14,
                              color: skin.text,
                            ),
                          ),
                          dense: true,
                          onTap: () {
                            Navigator.pop(
                              context,
                            );
                            widget.onUserAction();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }
}
