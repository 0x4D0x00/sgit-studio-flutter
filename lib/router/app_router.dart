import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sgit_studio_flutter/features/artifacts/presentation/pages/artifacts_page.dart';
import 'package:sgit_studio_flutter/features/auth/application/auth_controller.dart';
import 'package:sgit_studio_flutter/features/auth/presentation/pages/login_page.dart';
import 'package:sgit_studio_flutter/features/customize/presentation/pages/customize_page.dart';
import 'package:sgit_studio_flutter/features/projects/presentation/pages/projects_page.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/app_shell_container.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/history_page.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/nav_panel_container.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/pages/studio_page.dart';
import 'package:sgit_studio_flutter/features/workspace/presentation/pages/workspace_page.dart';
import 'package:sgit_studio_flutter/router/route_names.dart';

/// GoRouter 配置。ShellRoute 承载常驻工作台外壳（窗口 bar + 左右栏），登录页独立。
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
        builder: (context, state, child) {
          // 确定当前激活的导航项：产物页 / studio 子页 / 默认 null（工作台）。
          final path = state.uri.path;
          final activeNavId = switch (path) {
            RouteNames.artifacts =>
              NavPanelContainer.idArtifacts,
            RouteNames.history => NavPanelContainer.idHistory,
            RouteNames.projects => NavPanelContainer.idProjects,
            RouteNames.customize => NavPanelContainer.idCustomize,
            _ => state.pathParameters['key'],
          };

          return AppShellContainer(
            // 只有工作台是会话页。其余路由（输出物 / Projects / 设置 / 智能体
            // 子页）都不该带着右侧面板 —— 面板里的产物属于某条会话。
            isConversation: path == RouteNames.home,
            activeNavId: activeNavId,
            child: child,
          );
        },
        routes: [
          GoRoute(path: RouteNames.home, builder: (_, _) => const WorkspacePage()),
          GoRoute(
            path: RouteNames.artifacts,
            builder: (_, _) => const ArtifactsPage(),
          ),
          GoRoute(
            path: RouteNames.projects,
            builder: (_, _) => const ProjectsPage(),
          ),
          GoRoute(
            path: RouteNames.customize,
            builder: (_, _) => const CustomizePage(),
          ),
          GoRoute(
            path: RouteNames.history,
            builder: (_, _) => const HistoryPage(),
          ),
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
