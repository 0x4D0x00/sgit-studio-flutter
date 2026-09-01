import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/window_bar/app_window_bar.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_controller.dart';
import '../utils/responsive.dart';
import 'layered_scaffold.dart';
import 'nav_panel.dart';
import 'output_panel.dart';
import 'resizable_panel.dart';
import 'workspace_controller.dart';
import 'workspace_metrics.dart';

/// 工作台外壳 —— 1:1 对齐 sgit-studio 登录后主界面（`routes/(main)/_layout`）。
///
/// 结构（**层级顺序很关键**，照 studio 摆）：
/// ```
/// Row
///  ├── 左栏 NavPanel            ← 在圆角卡「外面」，背景 colorBgLayout，无右边框
///  └── Padding(top:8, left: 展开?0:8)
///        └── ClipRRect(12) + 1px 边框   ← 圆角卡，背景 colorBgContainer
///              └── Row
///                   ├── 中栏 child      ← flex:1，无固定宽
///                   └── 右栏 OutputPanel ← 在卡「里面」，左侧 1px 分割线
/// ```
/// 栏与栏之间**没有 gap、没有独立 divider**，拖拽把手是各面板自带的边缘 resizer。
///
/// 移动端（窄屏）退化：左栏收进 Drawer，右栏隐藏。
class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
    this.activeStudioKey,
  });

  final Widget child;
  final String currentRoute;

  /// 当前「智能体」子页 key(用于侧栏高亮)。
  final String? activeStudioKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ws = ref.watch(workspaceControllerProvider);

    // 透明模式(Nexus 自有能力)下让位给四层结构:底色改半透明,霓虹/桌面透出来。
    // 非透明模式用 studio 的纯色,视觉与 studio 一致。
    final transparent =
        ref.watch(themeControllerProvider.select((s) => s.transparentMode));
    double a(double opaque) => transparent ? opaque : 1.0;

    final layoutBg = (isDark ? AppColors.layoutBgDark : AppColors.layoutBgLight)
        .withValues(alpha: a(0.0));
    final containerBg =
        (isDark ? AppColors.containerBgDark : AppColors.containerBgLight)
            .withValues(alpha: a(0.35));
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    final narrow = context.useDrawerNav;

    return LayeredScaffold(
      showNeon: transparent,
      child: Scaffold(
      backgroundColor: layoutBg,
      drawer: narrow
          ? Drawer(
              backgroundColor: layoutBg,
              child: SafeArea(
                child: NavPanel(
                        currentRoute: currentRoute,
                        activeStudioKey: activeStudioKey),
              ),
            )
          : null,
      body: Column(
        children: [
          const AppWindowBar(),
          Expanded(
            child: Row(
              children: [
                // ---- 左栏：圆角卡之外 ----
                if (!narrow)
                  ResizablePanel(
                    side: AxisDirection.left,
                    width: ws.navWidth,
                    expanded: ws.navExpanded,
                    minWidth: WorkspaceMetrics.navMinWidth,
                    maxWidth: WorkspaceMetrics.navMaxWidth,
                    onWidthChanged: (w) =>
                        ref.read(workspaceControllerProvider.notifier).setNavWidth(w),
                    backgroundColor: layoutBg,
                    child: NavPanel(
                        currentRoute: currentRoute,
                        activeStudioKey: activeStudioKey),
                  ),

                // ---- 圆角卡：中栏 + 右栏 ----
                Expanded(
                  child: AnimatedPadding(
                    duration: WorkspaceMetrics.panelAnim,
                    curve: Curves.easeOut,
                    padding: EdgeInsets.only(
                      // studio：左栏展开时左边不留白，折叠时补 8。
                      left: (!narrow && ws.navExpanded)
                          ? 0
                          : WorkspaceMetrics.framePadding,
                      top: WorkspaceMetrics.framePadding,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: containerBg,
                        border: Border.all(
                            color: borderColor,
                            width: WorkspaceMetrics.frameBorder),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(WorkspaceMetrics.frameRadius),
                          topRight: Radius.circular(WorkspaceMetrics.frameRadius),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(WorkspaceMetrics.frameRadius),
                          topRight: Radius.circular(WorkspaceMetrics.frameRadius),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _navHeader(context, ref, narrow, ws.navExpanded, isDark),
                                  Expanded(child: child),
                                ],
                              ),
                            ),
                            if (!narrow)
                              ResizablePanel(
                                side: AxisDirection.right,
                                width: ws.outputWidth,
                                expanded: ws.outputExpanded,
                                minWidth: WorkspaceMetrics.outputMinWidth,
                                maxWidth: WorkspaceMetrics.outputMaxWidth,
                                onWidthChanged: (w) => ref
                                    .read(workspaceControllerProvider.notifier)
                                    .setOutputWidth(w),
                                backgroundColor: containerBg,
                                borderSide: BorderSide(
                                  color: isDark
                                      ? AppColors.borderSecondaryDark
                                      : AppColors.borderSecondaryLight,
                                ),
                                child: const OutputPanel(title: '输出物'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  /// 顶栏：studio 里**只在左栏折叠时出现**，高 44、padding 8，里面只放展开按钮。
  /// 这里额外放右栏开关（studio 是浮在右上角的 ActionIcon）。
  Widget _navHeader(BuildContext context, WidgetRef ref, bool narrow,
      bool navExpanded, bool isDark) {
    final showExpandBtn = narrow || !navExpanded;
    final fg = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return SizedBox(
      height: WorkspaceMetrics.headerHeight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            if (showExpandBtn)
              IconButton(
                iconSize: 18,
                color: fg,
                tooltip: '展开导航',
                icon: const Icon(Icons.menu_rounded),
                onPressed: () => narrow
                    ? Scaffold.of(context).openDrawer()
                    : ref.read(workspaceControllerProvider.notifier).toggleNav(),
              )
            else
              IconButton(
                iconSize: 18,
                color: fg,
                tooltip: '收起导航',
                icon: const Icon(Icons.menu_open_rounded),
                onPressed: () =>
                    ref.read(workspaceControllerProvider.notifier).toggleNav(),
              ),
            const Spacer(),
            if (!narrow)
              IconButton(
                iconSize: 18,
                color: fg,
                tooltip: '输出物面板',
                icon: const Icon(Icons.view_sidebar_outlined),
                onPressed: () =>
                    ref.read(workspaceControllerProvider.notifier).toggleOutput(),
              ),
          ],
        ),
      ),
    );
  }
}
