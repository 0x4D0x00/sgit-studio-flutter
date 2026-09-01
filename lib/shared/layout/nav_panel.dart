import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/brand/brand_assets.dart';
import '../../core/brand/brand_config.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/menu/menu_controller.dart';
import 'workspace_metrics.dart';

/// 左侧导航栏 —— 对齐 sgit-studio `home/_layout/SidebarContent`。
///
/// 结构（照 studio 摆，不增不减）：
/// ```
/// Header : 品牌行(Brand) + 搜索(Nav，studio 里 HEADER_KEYS 只留 search)
/// Body   : 助理区(AgentNav：新建对话 + 历史对话)
///          ─ spacer ─
///          智能体区(StudioNav：组标题「智能体」+ 判权后的 8 项)
/// Footer : 分割线 + 用户区
/// ```
/// studio 已明确把「首页」项移除（首页本身就是当前页，入口多余），故这里也没有；
/// 原来那批「总览/用户管理/组织架构/权限分配/API 密钥」不属于 studio 结构，已去掉。
class NavPanel extends ConsumerWidget {
  const NavPanel({super.key, required this.currentRoute, this.activeStudioKey});

  final String currentRoute;

  /// 当前处于哪个「智能体」子页（对应 studio 的 `?studio=<key>`）。
  final String? activeStudioKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final studioItems = ref.watch(visibleStudioNavProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(
          vertical: WorkspaceMetrics.navPanelPaddingBlock),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(isDark),
          // Header 里的搜索项。
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: WorkspaceMetrics.navPanelPaddingInline),
            child: _navRow(
              icon: Icons.search_rounded,
              label: '搜索',
              isDark: isDark,
              onTap: () => _todo(context, '搜索'),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                  horizontal: WorkspaceMetrics.navPanelPaddingInline),
              children: [
                // ---- 助理区 ----
                _navRow(
                  icon: Icons.add_comment_outlined,
                  label: '新建对话',
                  isDark: isDark,
                  onTap: () => _todo(context, '新建对话'),
                ),
                _navRow(
                  icon: Icons.history_rounded,
                  label: '历史对话',
                  isDark: isDark,
                  onTap: () => _todo(context, '历史对话'),
                ),

                // ---- 智能体区（判权后才显示；无权限则整组不出现，连组标题都不留）----
                if (studioItems.isNotEmpty) ...[
                  _groupTitle('智能体', isDark),
                  for (final item in studioItems)
                    _navRow(
                      icon: item.icon,
                      label: item.label,
                      isDark: isDark,
                      selected: activeStudioKey == item.key,
                      onTap: () => _todo(context, item.label),
                    ),
                ],
              ],
            ),
          ),
          _divider(isDark),
          _user(context, ref, isDark),
        ],
      ),
    );
  }

  /// 组标题：fontSize 12 / weight 600 / padding 6,8,2（studio StudioNav）。
  Widget _groupTitle(String text, bool isDark) => Padding(
        padding: const EdgeInsets.only(left: 8, right: 8, top: 6, bottom: 2),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      );

  /// 品牌行：盾牌 mark + 字标（字标取 brand.json 的 name，不写死）。
  Widget _brand(bool isDark) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Image(
              image: BrandAssets.image(BrandAssets.loginMark),
              width: WorkspaceMetrics.brandMarkWidth,
              height: WorkspaceMetrics.brandMarkHeight,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: WorkspaceMetrics.brandGap),
            Flexible(
              child: Text(
                BrandConfig.instance.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: WorkspaceMetrics.brandFontSize,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: isDark ? AppColors.textDark : AppColors.textLight,
                ),
              ),
            ),
          ],
        ),
      );

  /// 导航行：height 48 / 圆角 8 / paddingInline 16 / gap 8 / 图标 18。
  Widget _navRow({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    final fg = selected
        ? (isDark ? AppColors.textDark : AppColors.textLight)
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Material(
        color: selected ? AppColors.navItemActive : Colors.transparent,
        borderRadius: BorderRadius.circular(WorkspaceMetrics.navItemRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: WorkspaceMetrics.navItemHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: WorkspaceMetrics.navItemPaddingInline),
              child: Row(
                children: [
                  Icon(icon, size: WorkspaceMetrics.navIconSize, color: fg),
                  const SizedBox(width: WorkspaceMetrics.navItemGap),
                  Expanded(
                    child: Text(
                      label,
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

  Widget _divider(bool isDark) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          height: 1,
          margin: const EdgeInsets.only(bottom: 8),
          color: isDark
              ? AppColors.borderSecondaryDark
              : AppColors.borderSecondaryLight,
        ),
      );

  /// 用户区：height 48 / paddingInline 16 / 头像 26。
  Widget _user(BuildContext context, WidgetRef ref, bool isDark) {
    final fg = isDark ? AppColors.textDark : AppColors.textLight;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(WorkspaceMetrics.navItemRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => ref.read(authControllerProvider.notifier).logout(),
          child: SizedBox(
            height: WorkspaceMetrics.navItemHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: AppColors.navItemActive,
                    child: Icon(Icons.person_rounded, size: 16, color: fg),
                  ),
                  const SizedBox(width: WorkspaceMetrics.brandGap),
                  Expanded(
                    child: Text(
                      BrandConfig.instance.orgName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: fg),
                    ),
                  ),
                  Tooltip(
                    message: '退出登录',
                    child: Icon(Icons.logout_rounded,
                        size: 16,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _todo(BuildContext context, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$what：功能待接'), duration: const Duration(seconds: 1)),
    );
  }
}
