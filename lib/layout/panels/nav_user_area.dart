import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

import 'dart:typed_data';

/// 左侧导航栏底部用户区域：头像（点击显示菜单）。
/// 收起按钮在品牌行左侧（见 `NavPanel._brand`）。
///
/// ⚠️ **纯展示组件**：数据与回调全部由外部注入。
class NavUserArea extends StatelessWidget {
  const NavUserArea({
    super.key,
    required this.userName,
    required this.userMenu,
    this.avatarBytes,
  });

  final String userName;
  final Uint8List? avatarBytes;
  final List<AppMenuEntry> userMenu;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: WorkspaceMetrics.navItemHeight,
        child: Center(
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(WorkspaceMetrics.navItemRadius),
            clipBehavior: Clip.antiAlias,
            child: userMenu.isEmpty
                ? _avatarOnly(skin)
                : AppMenuAnchor(
                    entries: userMenu,
                    align: AppMenuAlign.above,
                    child: _avatarOnly(skin),
                  ),
          ),
        ),
      ),
    );
  }

  /// 只显示头像，点击弹出菜单（由外层 AppMenuAnchor 负责）。
  Widget _avatarOnly(AppSkin skin) => CircleAvatar(
    radius: 13,
    backgroundColor: skin.navItemActive,
    backgroundImage: avatarBytes != null ? MemoryImage(avatarBytes!) : null,
    child: avatarBytes == null
        ? Icon(Icons.person_rounded, size: 16, color: skin.text)
        : null,
  );
}
