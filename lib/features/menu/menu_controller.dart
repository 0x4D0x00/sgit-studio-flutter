import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/layout/nav_item.dart';
import 'models/accessible_menus.dart';
import 'services/menu_service.dart';

/// 「智能体」菜单判权。登录后拉一次，登出/换账号自动重拉。
final accessibleMenusProvider = FutureProvider<AccessibleMenus>((ref) async {
  return const MenuService().listAccessible();
});

/// 当前可见的「智能体」菜单项。
///
/// ⚠️ **拒绝式（deny by default）**，与 studio `StudioNav.tsx` 的实际行为一致：
/// - 加载中 → 空（不先显示全部再抽走，避免闪现无权限菜单）；
/// - 判权失败 / 未登录（resolved=false）→ 空（**不放行**，避免后端抖动时漏出全部菜单）；
/// - 判权成功 → 只显示命中的 key。
///
/// 注意 studio 的 `services/sgcodeMenu.ts` 文件头注释写的是「失败即全开」，那是**过时的**，
/// 组件里早已改成拒绝式。以组件行为为准，别照那句注释写。
final visibleStudioNavProvider = Provider<List<StudioNavItem>>((ref) {
  final async = ref.watch(accessibleMenusProvider);
  final menus = async.asData?.value;
  if (menus == null || !menus.resolved) return const <StudioNavItem>[];
  return StudioNavItem.all
      .where((item) => menus.accessibleKeys.contains(item.key))
      .toList();
});
