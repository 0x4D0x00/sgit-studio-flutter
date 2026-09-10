import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 左侧导航栏底部用户区域：左侧头像+名字（点击显示菜单），右侧搜索 + 收起按钮。
///
/// ⚠️ **纯展示组件**：数据与回调全部由外部注入。
class NavUserArea extends StatelessWidget {
  const NavUserArea({
    super.key,
    required this.userName,
    required this.userMenu,
    required this.searchTooltip,
    required this.collapseTooltip,
    this.onSearch,
    this.onCollapse,
  });

  final String userName;
  final List<AppMenuEntry> userMenu;

  /// 用户区右下角搜索按钮的 tooltip。
  final String searchTooltip;

  /// 搜索右边那颗收起按钮的 tooltip。收起左栏的入口**只有这一处**
  /// （中栏顶栏只负责展开），所以它得说清楚自己是干什么的。
  final String collapseTooltip;

  final VoidCallback? onSearch;
  final VoidCallback? onCollapse;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                borderRadius:
                    BorderRadius.circular(WorkspaceMetrics.navItemRadius),
                clipBehavior: Clip.antiAlias,
                child: userMenu.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _content(skin),
                      )
                    : AppMenuAnchor(
                        entries: userMenu,
                        align: AppMenuAlign.above,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _content(skin),
                        ),
                      ),
              ),
            ),

            // 右侧：搜索按钮
            if (onSearch != null)
              IconButton(
                icon: Icon(Icons.search, size: 20, color: skin.textSecondary),
                onPressed: onSearch,
                tooltip: searchTooltip,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),

            // 收起侧边栏按钮
            if (onCollapse != null)
              IconButton(
                icon: Icon(Icons.menu_open_sharp,
                    size: 20, color: skin.textSecondary),
                onPressed: onCollapse,
                tooltip: collapseTooltip,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
      ),
    );
  }

  /// 头像+用户名，无论有没有菜单都长一样，悬停灰框由外层
  /// `Material`/`InkWell` 负责，这里只管排版。
  Widget _content(AppSkin skin) => Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: skin.navItemActive,
            child: Icon(Icons.person_rounded, size: 16, color: skin.text),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              userName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: skin.text),
            ),
          ),
        ],
      );
}
