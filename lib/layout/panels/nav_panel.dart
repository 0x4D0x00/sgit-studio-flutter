import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/layout/panels/models/nav_entry.dart';
import 'package:sgit_studio_flutter/layout/panels/nav_row.dart';
import 'package:sgit_studio_flutter/layout/panels/nav_section_header.dart';
import 'package:sgit_studio_flutter/layout/panels/nav_user_area.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 左侧导航栏 —— 重构
///
/// 结构：
/// ```
/// 1. 品牌行
/// 2. 导航行（新对话、输出物、智能体）—— NavRow
/// 3. 置顶区域（带 Pin 提示）—— NavRow
/// 4. 历史对话列表（可折叠、可滚动）—— NavRow
/// 5. 用户区域（点击显示菜单）—— NavUserArea
/// ```
/// ⚠️ **纯展示组件**：不 import 状态管理库、不 import features、不判 `isDark`。
/// 数据与回调全部由 `features/shell/presentation/nav_panel_container.dart` 注入。
class NavPanel extends StatefulWidget {
  const NavPanel({
    super.key,
    required this.brandMark,
    required this.brandName,
    required this.header,
    required this.sections,
    required this.activeId,
    required this.onSelect,
    required this.userName,
    required this.searchTooltip,
    required this.collapseTooltip,
    this.avatarBytes,
    this.userMenu = const [],
    this.onSearch,
    this.onCollapse,
    this.onAddProject,
  });

  final ImageProvider brandMark;
  final String brandName;
  final List<NavEntry> header;
  final List<NavSection> sections;
  final String? activeId;
  final ValueChanged<String> onSelect;
  final String userName;
  final Uint8List? avatarBytes;

  /// 用户区右下角搜索按钮的 tooltip。
  final String searchTooltip;

  /// 品牌行左侧收起按钮的 tooltip。收起左栏的入口**只有这一处**
  /// （中栏顶栏只负责展开），所以它得说清楚自己是干什么的。
  final String collapseTooltip;

  /// 用户菜单内容（设置、退出登录）。容器注入，由
  /// `features/shell/presentation/nav_panel_container.dart` 管业务。
  final List<AppMenuEntry> userMenu;

  final VoidCallback? onSearch;
  final VoidCallback? onCollapse;
  final VoidCallback? onAddProject;

  @override
  State<NavPanel> createState() => _NavPanelState();
}

class _NavPanelState extends State<NavPanel> {
  bool _chatsCollapsed = false;

  /// 当前弹着菜单的导航行 id（智能体行）。用来让那一行在菜单开着时保持高亮。
  String? _openMenuId;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: WorkspaceMetrics.navPanelPaddingBlock,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 品牌行
          _brand(skin),

          // 2. 导航行
          if (widget.header.isNotEmpty)
            Column(
              children: [
                for (final e in widget.header) _row(e, isHeader: true),
              ],
            ),

          const SizedBox(height: 6),

          // 3-4. 可滚动区域（置顶和历史会话列表）
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final s in widget.sections)
                  if (!s.isEmpty) ...[
                    // 组标题行（带操作按钮）
                    if (s.title != null)
                      NavSectionHeader(
                        section: s,
                        collapsed: s.isCollapsed ?? _chatsCollapsed,
                        onToggleCollapse: s.onToggleCollapse ??
                            (s.collapsible
                                ? () => setState(() => _chatsCollapsed = !_chatsCollapsed)
                                : null),
                        onAddProject: widget.onAddProject,
                      ),

                    // 空组走占位提示
                    if (s.entries.isEmpty && s.emptyHint != null)
                      NavSectionEmptyHint(section: s)
                    else if (s.entries.isNotEmpty &&
                            (!_chatsCollapsed || !s.collapsible || s.onToggleCollapse != null))
                      // 显示条目（未折叠 或 不可折叠 或 有自定义折叠回调）
                      for (final e in s.entries)
                        _row(e, isChatItem: s.collapsible),

                    const SizedBox(height: 8),
                  ],
              ],
            ),
          ),

          // 5. 分割线
          _divider(skin),

          // 6. 用户区域
          NavUserArea(
            userName: widget.userName,
            avatarBytes: widget.avatarBytes,
            userMenu: widget.userMenu,
            searchTooltip: widget.searchTooltip,
            onSearch: widget.onSearch,
          ),
        ],
      ),
    );
  }

  Widget _row(NavEntry e, {bool isHeader = false, bool isChatItem = false}) =>
      NavRow(
        entry: e,
        selected: widget.activeId == e.id,
        menuOpen: _openMenuId == e.id,
        onSelect: widget.onSelect,
        onMenuOpenChanged: (open) =>
            setState(() => _openMenuId = open ? e.id : null),
        isHeader: isHeader,
        isChatItem: isChatItem,
      );

  /// 品牌行：左侧收起按钮 + 字标。
  Widget _brand(AppSkin skin) => Padding(
        padding: EdgeInsets.only(
          left: widget.onCollapse != null ? 12 : 24,
          right: 24,
          top: 8,
          bottom: 8,
        ),
        child: Row(
          children: [
            // 收起侧边栏按钮（收起左栏的唯一入口）
            if (widget.onCollapse != null) ...[
              IconButton(
                icon: Icon(Icons.menu_open_sharp,
                    size: 20, color: skin.textSecondary),
                onPressed: widget.onCollapse,
                tooltip: widget.collapseTooltip,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 4),
            ],
            Expanded(
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
            ),
          ],
        ),
      );

  Widget _divider(AppSkin skin) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 8),
          color: skin.borderSecondary,
        ),
      );
}
