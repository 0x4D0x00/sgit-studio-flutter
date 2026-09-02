import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/layout/panels/models/nav_entry.dart';

/// 左侧导航栏 —— 对齐 sgit-studio `home/_layout/SidebarContent`。
///
/// 结构（照 studio 摆，不增不减）：
/// ```
/// Header : 品牌行 + [header] 里的项（studio 的 HEADER_KEYS 只留 search）
/// Body   : [sections] 逐组渲染，可滚动
/// Footer : 分割线 + 用户区
/// ```
///
/// ⚠️ **纯展示组件**：不 import 状态管理库、不 import features、不判 `isDark`。
/// 数据与回调全部由 `features/shell/presentation/nav_panel_container.dart` 注入。
class NavPanel extends StatelessWidget {
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
  });

  final ImageProvider brandMark;

  /// 字标。来自 brand.json，禁止写死。
  final String brandName;

  /// 固定在顶部、不随 body 滚动的项。
  final List<NavEntry> header;

  /// 可滚动的分组。
  final List<NavSection> sections;

  /// 当前选中项的 [NavEntry.id]。
  final String? activeId;

  final ValueChanged<String> onSelect;

  final String userName;
  final String userActionTooltip;
  final VoidCallback onUserAction;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: WorkspaceMetrics.navPanelPaddingBlock),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(skin),
          if (header.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: WorkspaceMetrics.navPanelPaddingInline),
              child: Column(
                children: [for (final e in header) _row(skin, e)],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: WorkspaceMetrics.navPanelPaddingInline),
              children: [
                for (final s in sections)
                  // 整组为空时连组标题都不留（无权限就该彻底不出现）。
                  if (!s.isEmpty) ...[
                    if (s.title != null) _groupTitle(skin, s.title!),
                    for (final e in s.entries) _row(skin, e),
                  ],
              ],
            ),
          ),
          _divider(skin),
          _user(skin),
        ],
      ),
    );
  }

  /// 组标题：fontSize 12 / weight 600 / padding 6,8,2（studio StudioNav）。
  Widget _groupTitle(AppSkin skin, String text) => Padding(
        padding: const EdgeInsets.only(left: 8, right: 8, top: 6, bottom: 2),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: skin.textSecondary,
          ),
        ),
      );

  /// 品牌行：盾牌 mark + 字标。
  Widget _brand(AppSkin skin) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Image(
              image: brandMark,
              width: WorkspaceMetrics.brandMarkWidth,
              height: WorkspaceMetrics.brandMarkHeight,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: WorkspaceMetrics.brandGap),
            Flexible(
              child: Text(
                brandName,
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

  /// 导航行：height 48 / 圆角 8 / paddingInline 16 / gap 8 / 图标 18。
  Widget _row(AppSkin skin, NavEntry e) {
    final selected = activeId == e.id;
    final fg = selected ? skin.text : skin.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: selected ? skin.navItemActive : Colors.transparent,
        borderRadius: BorderRadius.circular(WorkspaceMetrics.navItemRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onSelect(e.id),
          child: SizedBox(
            height: WorkspaceMetrics.navItemHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: WorkspaceMetrics.navItemPaddingInline),
              child: Row(
                children: [
                  Icon(e.icon, size: WorkspaceMetrics.navIconSize, color: fg),
                  const SizedBox(width: WorkspaceMetrics.navItemGap),
                  Expanded(
                    child: Text(
                      e.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
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

  Widget _divider(AppSkin skin) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 8),
          color: skin.borderSecondary,
        ),
      );

  /// 用户区：height 48 / paddingInline 16 / 头像 26。
  Widget _user(AppSkin skin) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(WorkspaceMetrics.navItemRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onUserAction,
            child: SizedBox(
              height: WorkspaceMetrics.navItemHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: skin.navItemActive,
                      child: Icon(Icons.person_rounded,
                          size: 16, color: skin.text),
                    ),
                    const SizedBox(width: WorkspaceMetrics.brandGap),
                    Expanded(
                      child: Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: skin.text),
                      ),
                    ),
                    Tooltip(
                      message: userActionTooltip,
                      child: Icon(Icons.logout_rounded,
                          size: 16, color: skin.textTertiary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
