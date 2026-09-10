import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/menu_repository.dart';
import 'package:sgit_studio_flutter/domain/models/accessible_menus.dart';

/// 菜单判权。登录后拉一次，登出/换账号自动重拉。
///
/// 只负责「后端说哪些 menu_key 可见」这件事，**不掺和任何 feature 的菜单清单** ——
/// 谁要用就自己 watch 它去过滤自己的注册表（见 `features/studio/studio_feature.dart`）。
final accessibleMenusProvider = FutureProvider<AccessibleMenus>((ref) {
  return const MenuRepository().listAccessible();
});
