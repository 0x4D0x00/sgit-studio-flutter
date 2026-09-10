import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/layout/panels/models/nav_entry.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

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
    required this.searchTooltip,
    required this.collapseTooltip,
    this.userMenu = const [],
    this.onSearch,
    this.onCollapse,
    this.onAddProject,
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

  /// 用户区右下角搜索按钮的 tooltip。
  final String searchTooltip;

  /// 搜索右边那颗收起按钮的 tooltip。收起左栏的入口**只有这一处**
  /// （中栏顶栏只负责展开），所以它得说清楚自己是干什么的。
  final String collapseTooltip;

  /// 用户菜单内容（设置、退出登录）。容器注入，由
  /// `features/shell/presentation/nav_panel_container.dart` 管业务。
  final List<
    AppMenuEntry
  >
  userMenu;

  final VoidCallback? onSearch;
  final VoidCallback? onCollapse;
  final VoidCallback? onAddProject;

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

  /// 当前弹着菜单的导航行 id（智能体行）。用来让那一行在菜单开着时保持高亮。
  String? _openMenuId;

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
            Column(
              children: [
                for (final e in widget.header)
                  _row(
                    skin,
                    e,
                    isHeader: true,
                  ),
              ],
            ),

          const SizedBox(
            height: 6,
          ),

          // 3-4. 可滚动区域（置顶和历史会话列表）
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
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
                          isChatItem: s.collapsible,
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
        left: 24,
        right: 24,
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
                  section.actionIcon ??
                      Icons.add,
                  size: 16,
                  color: skin.textSecondary,
                ),
              ),
            )
          else if (section.action ==
                  NavSectionAction.menu &&
              section.menu.isNotEmpty)
            AppMenuAnchor(
              entries: section.menu,
              minWidth: 180,
              child: Padding(
                padding: const EdgeInsets.all(
                  4,
                ),
                child: Icon(
                  section.actionIcon ??
                      Icons.tune,
                  size: 16,
                  color: skin.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 空组占位提示（设计图里 Projects 空时的「Pin chats to keep them here」）。
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
  ///
  /// 带 [NavEntry.menu] 的行走悬停菜单（智能体行）：`AppMenuAnchor` 自带
  /// 触发器的点击/悬停，所以那种行不能再套一层自己的 `InkWell` —— 两层点击
  /// 手势会互相吃掉，菜单钉不住。
  ///
  /// [isHeader] 为 true 时是顶部导航行（New、Projects 等），与品牌行左对齐。
  /// [isChatItem] 为 true 时是历史对话列表项，采用无序列表样式（圆点 + 文字）。
  Widget _row(
    AppSkin skin,
    NavEntry e, {
    bool isHeader = false,
    bool isChatItem = false,
  }) {
    final selected =
        widget.activeId ==
        e.id;
    // 菜单开着时这一行保持高亮，否则菜单飘在外面、行是灰的，看着不像一对。
    // 停在某个子页里时也算 —— 那一行是子页的归属。
    final highlighted =
        selected ||
        _openMenuId ==
            e.id ||
        e.menuHasChecked;
    final fg = highlighted
        ? skin.text
        : skin.textSecondary;

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
              Icon(
                e.icon,
                size: WorkspaceMetrics.navIconSize,
                color: fg,
              ),
            if (!isChatItem)
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
                  fontWeight: highlighted
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: fg,
                ),
              ),
            ),
            // 有子菜单就给个「往右还有」的提示，否则用户不知道这行能悬停。
            if (e.hasMenu)
              Icon(
                Icons.chevron_right,
                size: 16,
                color: fg,
              ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 0.5,
      ),
      child: Material(
        color: highlighted
            ? skin.navItemActive
            : Colors.transparent,
        borderRadius: BorderRadius.circular(
          WorkspaceMetrics.navItemRadius,
        ),
        clipBehavior: Clip.antiAlias,
        child: e.hasMenu
            ? AppMenuAnchor(
                entries: e.menu,
                trigger: AppMenuTrigger.hover,
                align: AppMenuAlign.end,
                semanticLabel: e.label,
                onOpenChanged:
                    (
                      open,
                    ) => setState(
                      () => _openMenuId = open
                          ? e.id
                          : null,
                    ),
                child: content,
              )
            : InkWell(
                onTap: () => widget.onSelect(
                  e.id,
                ),
                child: content,
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
  ///
  /// 悬停灰框跟历史会话行（见 [_row]）同一套写法：`Material` 直接包
  /// `AppMenuAnchor`，靠它自带的 InkWell 出悬停态 —— 中间不能再套一层没有
  /// `onTap` 的 InkWell，那种没有任何手势回调的 InkWell 是禁用态，悬停时
  /// 不会画出灰框。
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
        // Material 没有显式高度，靠 stretch 让它撑满整行高度 —— 否则
        // 悬停灰框只会包住头像+文字的intrinsic 高度，上下留白像没对齐。
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左侧：头像+用户名（点击显示菜单）
          Expanded(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(
                WorkspaceMetrics.navItemRadius,
              ),
              clipBehavior: Clip.antiAlias,
              child: widget.userMenu.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      child: _userRowContent(
                        skin,
                      ),
                    )
                  : AppMenuAnchor(
                      entries: widget.userMenu,
                      align: AppMenuAlign.above,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        child: _userRowContent(
                          skin,
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

  /// 用户区行内的头像+用户名，无论有没有菜单都长一样，悬停灰框由外层
  /// `Material`/`InkWell` 负责，这里只管排版。
  Widget
  _userRowContent(
    AppSkin skin,
  ) => Row(
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
  );
}
