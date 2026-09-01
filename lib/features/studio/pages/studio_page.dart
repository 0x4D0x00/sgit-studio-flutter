import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/layout/nav_item.dart';
import '../../menu/menu_controller.dart';

/// 「智能体」子页容器 —— 对应 studio 的 `/?studio=<key>` 就地渲染。
///
/// ⚠️ **这里也要判权**：侧栏隐藏入口只防误点，不防手输 URL。无权限时直接拒绝渲染，
/// 与侧栏用的是同一份 [visibleStudioNavProvider]（拒绝式：加载中/判权失败都不放行）。
class StudioPage extends ConsumerWidget {
  const StudioPage({super.key, required this.pageKey});

  final String pageKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(visibleStudioNavProvider);
    final item = visible.where((e) => e.key == pageKey).firstOrNull;

    if (item == null) {
      // 判权未通过：可能是加载中、无权限、或后端不可用。统一给"无权访问"，
      // 不区分原因（区分了等于把菜单是否存在这件事泄露出去）。
      return _denied(context, ref);
    }
    return _placeholder(context, item);
  }

  Widget _denied(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loading = ref.watch(accessibleMenusProvider).isLoading;
    return Center(
      child: loading
          ? const SizedBox(
              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 32,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight),
                const SizedBox(height: 12),
                Text(
                  '无权访问该功能',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
    );
  }

  // TODO 各子页的真实内容待接（数据一律走 FFI 的 sgit_request，不走 gateway）。
  Widget _placeholder(BuildContext context, StudioNavItem item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(item.icon,
              size: 32,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight),
          const SizedBox(height: 12),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textDark : AppColors.textLight,
            ),
          ),
        ],
      ),
    );
  }
}
