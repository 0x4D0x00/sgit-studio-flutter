import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

import 'dart:typed_data';

/// 左侧导航栏底部用户区域：左侧头像+名字（点击显示菜单），右侧下载按钮。
/// 收起按钮在品牌行左侧（见 `NavPanel._brand`）。
///
/// ⚠️ **纯展示组件**：数据与回调全部由外部注入。
class NavUserArea extends StatelessWidget {
  const NavUserArea({
    super.key,
    required this.userName,
    required this.userMenu,
    required this.downloadTooltip,
    this.avatarBytes,
    this.onDownload,
  });

  final String userName;
  final Uint8List? avatarBytes;
  final List<AppMenuEntry> userMenu;

  /// 用户区右侧下载按钮的 tooltip。
  final String downloadTooltip;

  final VoidCallback? onDownload;

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
            // 左侧：头像+用户名（点击显示菜单）。
            // Expanded 占满下载按钮之外的全部宽度，内层 Flexible 让灰框按内容
            // 收缩、最宽到这个上限，名字超出上限才省略。
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        WorkspaceMetrics.navItemRadius,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: userMenu.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: _content(skin),
                            )
                          : AppMenuAnchor(
                              entries: userMenu,
                              align: AppMenuAlign.above,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: _content(skin),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // 右侧：下载按钮
            if (onDownload != null)
              IconButton(
                icon: Icon(
                  Icons.download_outlined,
                  size: 18,
                  color: skin.textSecondary,
                ),
                onPressed: onDownload,
                tooltip: downloadTooltip,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
      ),
    );
  }

  /// 头像+用户名，无论有没有菜单都长一样，悬停灰框由外层
  /// `Material`/`InkWell` 负责，这里只管排版。
  Widget _content(AppSkin skin) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 13,
        backgroundColor: skin.navItemActive,
        backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes!) : null,
        child: avatarBytes == null
            ? Icon(Icons.person_rounded, size: 16, color: skin.text)
            : null,
      ),
      const SizedBox(width: 8),
      // 用 Flexible文字只占自身宽度，名字过长时仍会按剩余宽度省略。
      Flexible(
        child: Text(
          userName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, color: skin.text),
        ),
      ),
      if (userMenu.isNotEmpty) ...[
        const SizedBox(width: 10),
        Icon(Icons.expand_more, size: 16, color: skin.textSecondary),
      ],
    ],
  );
}
