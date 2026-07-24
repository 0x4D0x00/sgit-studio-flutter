import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/apikeys/pages/apikeys_page.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/dashboard/pages/dashboard_page.dart';
import '../../features/models/pages/models_page.dart';
import '../../features/organizations/pages/organizations_page.dart';
import '../../features/permissions/pages/permissions_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/users/pages/users_page.dart';
import '../../shared/layout/app_shell.dart';
import 'route_names.dart';

/// GoRouter 配置。ShellRoute 承载常驻布局(窗口bar+侧栏+三层)，登录页独立。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteNames.dashboard,
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final authed = ref.read(authControllerProvider).isAuthenticated;
      final atLogin = state.matchedLocation == RouteNames.login;
      if (!authed) return atLogin ? null : RouteNames.login;
      if (atLogin) return RouteNames.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: RouteNames.login, builder: (_, __) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(currentRoute: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: RouteNames.dashboard, builder: (_, __) => const DashboardPage()),
          GoRoute(path: RouteNames.users, builder: (_, __) => const UsersPage()),
          GoRoute(path: RouteNames.organizations, builder: (_, __) => const OrganizationsPage()),
          GoRoute(path: RouteNames.permissions, builder: (_, __) => const PermissionsPage()),
          GoRoute(path: RouteNames.models, builder: (_, __) => const ModelsPage()),
          GoRoute(path: RouteNames.apikeys, builder: (_, __) => const ApiKeysPage()),
          GoRoute(path: RouteNames.settings, builder: (_, __) => const SettingsPage()),
        ],
      ),
    ],
  );
});

/// 把登录态变化桥接成 GoRouter 可监听的 Listenable。
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider.select((s) => s.isAuthenticated),
        (_, __) => notifyListeners());
  }
}
