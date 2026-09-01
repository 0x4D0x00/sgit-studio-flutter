import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/home/pages/home_page.dart';
import '../../features/settings/pages/settings_page.dart';
import '../../features/studio/pages/studio_page.dart';
import '../../shared/layout/app_shell.dart';
import 'route_names.dart';

/// GoRouter 配置。ShellRoute 承载常驻工作台外壳(窗口bar+左右栏)，登录页独立。
///
/// 路由结构对齐 sgit-studio：`/` 是工作台，「智能体」8 个子页走 `/studio/<key>`。
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: RouteNames.home,
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final authed = ref.read(authControllerProvider).isAuthenticated;
      final atLogin = state.matchedLocation == RouteNames.login;
      if (!authed) return atLogin ? null : RouteNames.login;
      if (atLogin) return RouteNames.home;
      return null;
    },
    routes: [
      GoRoute(path: RouteNames.login, builder: (_, _) => const LoginPage()),
      ShellRoute(
        builder: (context, state, child) => AppShell(
          currentRoute: state.matchedLocation,
          activeStudioKey: state.pathParameters['key'],
          child: child,
        ),
        routes: [
          GoRoute(path: RouteNames.home, builder: (_, _) => const HomePage()),
          GoRoute(
            path: '${RouteNames.studioPrefix}/:key',
            builder: (_, state) =>
                StudioPage(pageKey: state.pathParameters['key'] ?? ''),
          ),
          GoRoute(
              path: RouteNames.settings,
              builder: (_, _) => const SettingsPage()),
        ],
      ),
    ],
  );
});

/// 把登录态变化桥接成 GoRouter 可监听的 Listenable。
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider.select((s) => s.isAuthenticated),
        (_, _) => notifyListeners());
  }
}
