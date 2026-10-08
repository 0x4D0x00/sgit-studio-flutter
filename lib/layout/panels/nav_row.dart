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
///
/// 带 [NavEntry.trailingMenu] 的行（历史对话项）不一样：整行仍要能点选中，
/// 「⋯」只是悬停才露出的第二个热区 —— 所以两者是 `Row` 里的**兄弟节点**，
/// 不是嵌套，才不会重演上面那句注释里的手势互吃。
class NavRow
    extends
        StatefulWidget {
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

  final ValueChanged<
    String
  >
  onSelect;
  final ValueChanged<
    bool
  >
  onMenuOpenChanged;

  /// 顶部导航行（New、Projects 等），与品牌行左对齐。
  final bool isHeader;

  /// 历史对话列表项，采用无序列表样式（圆点 + 文字）。
  final bool isChatItem;

  @override
  State<
    NavRow
  >
  createState() => _NavRowState();
}

class _NavRowState
    extends
        State<
          NavRow
        > {
  /// 鼠标是否停在这一行上。只用来决定「⋯」按钮露不露出，不影响选中态。
  bool _hovering = false;

  @override
  Widget build(
    BuildContext context,
  ) {
    final entry = widget.entry;
    final selected = widget.selected;
    final menuOpen = widget.menuOpen;
    final onSelect = widget.onSelect;
    final onMenuOpenChanged = widget.onMenuOpenChanged;
    final isHeader = widget.isHeader;
    final isChatItem = widget.isChatItem;
    final skin = AppSkin.of(
      context,
    );

    // 菜单开着时这一行保持高亮，否则菜单飘在外面、行是灰的，看着不像一对。
    // 停在某个子页里时也算 —— 那一行是子页的归属。
    // 历史对话项（isChatItem）选中时也保持灰底常驻
    final highlighted =
        selected ||
            menuOpen ||
            entry.menuHasChecked;
    // 所有行统一灰底 —— 点击选中和鼠标悬停用同一个颜色
    final hoverBg = skin.text.withValues(
      alpha: 0.06,
    );
    // 历史对话项：选中、悬停、菜单开着都出灰底常驻；其余行悬停或高亮时出底色
    final showBackground = isChatItem
        ? (selected ||
              _hovering ||
              menuOpen)
        : (highlighted ||
              _hovering);
    final fg = highlighted
        ? skin.text
        : skin.textSecondary;

    // 整行右边距 —— 有 trailingMenu 时右边距挪给按钮那个 SizedBox。
    final core = Padding(
      padding: EdgeInsets.only(
        left:
            isHeader ||
                isChatItem
            ? 24
            : WorkspaceMetrics.navItemPaddingInline,
        right: (entry.hasTrailingMenu || entry.hasTrailingAdd || entry.hasMenu)
            ? 0
            : WorkspaceMetrics.navItemPaddingInline,
      ),
      child: Row(
        children: [
          // 历史对话列表项显示圆点而非图标，特殊操作行例外（如「查看全部」）
          if (isChatItem && !entry.isSpecialAction)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(
                right: 12,
              ),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: fg.withValues(alpha: 0.4)),
              ),
            )
          else
            Icon(
              entry.icon,
              size: WorkspaceMetrics.navIconSize,
              color: fg,
            ),
          if (!isChatItem || entry.isSpecialAction)
            const SizedBox(
              width: WorkspaceMetrics.navItemGap,
            ),
          Expanded(
            child: Text(
              entry.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    // highlighted &&
                    //     !isChatItem
                    // ? FontWeight.w600
                    // : FontWeight.w400,
                    FontWeight.w400,
                color: fg,
              ),
            ),
          ),
          // 有子菜单就给个「往右还有」的提示，否则用户不知道这行能悬停。
          if (entry.hasMenu)
            // 与 Projects 行的「+」热区同宽同居中（32 宽、图标 18），右边缘对齐
            SizedBox(
              width: 32,
              child: Center(
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: fg,
                ),
              ),
            ),
        ],
      ),
    );

    final content = SizedBox(
      height: WorkspaceMetrics.navItemHeight,
      child: core,
    );

    // 「⋯」/「+」热区：跟点行选中是**兄弟**，不是父子 —— 否则两层手势会互相吃掉
    final hasTrailingArea = entry.hasTrailingMenu || entry.hasTrailingAdd;
    final trailingButton = !hasTrailingArea
        ? null
        : SizedBox(
            width: 32,
            height: WorkspaceMetrics.navItemHeight,
            child:
                (_hovering ||
                    menuOpen)
                ? Center(
                    child: entry.hasTrailingMenu
                        ? AppMenuAnchor(
                            entries: entry.trailingMenu,
                            trigger: AppMenuTrigger.tap,
                            align: AppMenuAlign.underEnd,
                            semanticLabel: entry.label,
                            onOpenChanged: onMenuOpenChanged,
                            child: Icon(
                              Icons.more_horiz,
                              size: 18,
                              color: fg,
                            ),
                          )
                        : Tooltip(
                            message: entry.trailingAddTooltip ?? '',
                            child: InkWell(
                              onTap: entry.onTrailingAdd,
                              borderRadius: BorderRadius.circular(4),
                              child: Icon(
                                Icons.add,
                                size: 18,
                                color: fg,
                              ),
                            ),
                          ),
                  )
                : null,
          );

    final Widget body = switch (true) {
      _ when entry.hasMenu => AppMenuAnchor(
        entries: entry.menu,
        trigger: AppMenuTrigger.hover,
        align: AppMenuAlign.end,
        semanticLabel: entry.label,
        onOpenChanged: onMenuOpenChanged,
        child: content,
      ),
      _ when hasTrailingArea => Row(
        children: [
          // 「⋯」/「+」跟点行选中必须是兄弟节点、不能嵌套 —— 否则点击它们
          // 或菜单项时，点击会一并冒泡到这个 InkWell 触发 onSelect
          Expanded(
            child: InkWell(
              onTap: () => onSelect(
                entry.id,
              ),
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: content,
            ),
          ),
          trailingButton!,
        ],
      ),
      _ => InkWell(
        onTap: () => onSelect(
          entry.id,
        ),
        child: content,
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 0.5,
      ),
      child: MouseRegion(
        onEnter:
            (
              _,
            ) => setState(
              () => _hovering = true,
            ),
        onExit:
            (
              _,
            ) => setState(
              () => _hovering = false,
            ),
        child: Material(
          color: showBackground
              ? hoverBg
              : Colors.transparent,
          borderRadius: BorderRadius.circular(
            WorkspaceMetrics.navItemRadius,
          ),
          clipBehavior: Clip.antiAlias,
          // 历史对话项自己已经在整行外层画了灰底（上面 color）
          child: hasTrailingArea
              ? Theme(
                  data:
                      Theme.of(
                        context,
                      ).copyWith(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                      ),
                  child: body,
                )
              : body,
        ),
      ),
    );
  }
}
