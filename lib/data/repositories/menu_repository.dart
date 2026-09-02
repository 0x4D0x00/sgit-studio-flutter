import 'package:sgit_studio_flutter/data/transport/api_client.dart';
import 'package:sgit_studio_flutter/domain/models/accessible_menus.dart';

/// 「智能体」菜单判权服务。
///
/// ⚠️ **走 FFI，不走 gateway**。studio 那边打的是 gateway 的 `/sgcode-menu/list`，
/// 而 gateway 内部也只是转手向 sgit-server 的 `menu_system` 判权而已
/// （`sgit-services/src/bin/gateway.rs:4096` → `MenuPermissionsService::list_accessible_menus`）。
/// 我们直接用 FFI 的统一入口打同一个后端方法，少一跳、且不依赖 gateway。
///
/// 后端契约（`sgit-server/backend/main/http/menusystem.go:12-19`）：
/// ```
/// operation=menu_system, action=menu_management, method=list_accessible_menus
/// → { status:"success", menus:[ { menu_key, ... } ] }
/// ```
class MenuRepository {
  const MenuRepository();

  static const String _operation = 'menu_system';
  static const String _action = 'menu_management';

  /// 取当前登录用户可见的菜单 key。
  ///
  /// 任何异常都返回 [AccessibleMenus.unresolved]（resolved=false），由调用方决定策略。
  ///
  /// 注：`communication_id` / `user_auth_token` **不在这里拼** —— FFI 侧（桌面 .so /
  /// Web wasm）从自己的会话里自动注入。Go 这个 handler 认的是请求数据里的
  /// communication_id（不是 token），但那属于协议细节，归 Rust 管。
  Future<AccessibleMenus> listAccessible() async {
    try {
      final data = await ApiClient.instance.dispatch(
        type: 'command',
        operation: _operation,
        action: _action,
        payload: const {'method': 'list_accessible_menus'},
      );

      final menus = (data is Map ? data['menus'] : null);
      if (menus is! List) return AccessibleMenus.unresolved;

      final keys = <String>{};
      for (final m in menus) {
        if (m is Map) {
          final k = m['menu_key']?.toString();
          if (k != null && k.isNotEmpty) keys.add(k);
        }
      }
      return AccessibleMenus(accessibleKeys: keys, resolved: true);
    } catch (_) {
      return AccessibleMenus.unresolved;
    }
  }
}
