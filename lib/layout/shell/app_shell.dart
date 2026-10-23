import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/effects/layered_scaffold.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/layout/panels/resizable_panel.dart';
import 'package:sgit_studio_flutter/layout/responsive/responsive.dart';
import 'package:sgit_studio_flutter/platform/window_bar/app_window_bar.dart';

/// 工作台外壳 —— 1:1 对齐 sgit-studio 登录后主界面（`routes/(main)/_layout`）。
///
/// 结构（**层级顺序很关键**，照 studio 摆）：
/// ```
/// Row
///  ├── 左栏 nav                 ← 在圆角卡「外面」，背景 layoutBg，无右边框
///  └── Padding(top:8, left: 展开?0:8)
///        └── ClipRRect(12) + 1px 边框   ← 圆角卡，背景 containerBg
///              └── Row
///                   ├── 中栏 child      ← flex:1，无固定宽
///                   └── 右栏 output     ← 在卡「里面」，左侧 1px 分割线
/// ```
/// 栏与栏之间**没有 gap、没有独立 divider**，拖拽把手是各面板自带的边缘 resizer。
///
/// 移动端（窄屏）退化：左栏收进 Drawer，右栏隐藏。
///
/// ⚠️ **纯展示组件**：不 import 状态管理库、不 import features、不判 `isDark`。
/// 状态与回调由 `features/shell/presentation/app_shell_container.dart` 注入。
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.nav,
    required this.output,
    required this.child,
    this.headerTitle,
    required this.toolbarBuilder,
    this.rail,
    required this.navExpanded,
    required this.navWidth,
    required this.outputExpanded,
    required this.outputWidth,
    required this.contentMaxWidth,
    required this.onToggleNav,
    required this.onToggleOutput,
    required this.onNavWidthChanged,
    required this.onOutputWidthChanged,
  });

  final Widget nav;
  final Widget output;
  final Widget child;

  /// 顶栏左侧（展开按钮右边）的标题槽，如会话标题。null 则留空。
  final Widget? headerTitle;

  /// 窗口左上角工具行。参数是「切换导航」回调：窄屏开 Drawer，宽屏收起/展开左栏
  /// （Drawer 要在 Scaffold 之下才找得到，所以由外壳提供回调而不是容器直接给）。
  final Widget Function(VoidCallback onToggleNav) toolbarBuilder;

  /// 最左侧固定工具列，不可收起。窄屏不显示。
  final Widget? rail;

  final bool navExpanded;
  final double navWidth;
  final bool outputExpanded;
  final double outputWidth;

  /// 中栏内容列的宽度上限（设置页「转录宽度」三档之一）。
  ///
  /// 由容器从 `transcriptWidthProvider` 取值注入 —— 本组件是纯展示组件，
  /// 不 import 状态库。窗口比这个值窄时**以窗口为准**（下方取 `min`）。
  final double contentMaxWidth;

  final VoidCallback onToggleNav;
  final VoidCallback onToggleOutput;
  final ValueChanged<double> onNavWidthChanged;
  final ValueChanged<double> onOutputWidthChanged;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final narrow = context.useDrawerNav;

    return LayeredScaffold(
      child: Scaffold(
        backgroundColor: skin.layoutBg,
        drawer: narrow
            ? Drawer(
                backgroundColor: skin.layoutBg,
                child: SafeArea(child: nav),
              )
            : null,
        body: Column(
          children: [
            Builder(
              builder: (context) => AppWindowBar(
                leading: toolbarBuilder(
                  () => narrow
                      ? Scaffold.of(context).openDrawer()
                      : onToggleNav(),
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  // ---- 最左侧工具列：固定、不可收起 ----
                  if (!narrow && rail != null) rail!,

                  // ---- 左栏：圆角卡之外 ----
                  if (!narrow)
                    ResizablePanel(
                      side: AxisDirection.left,
                      width: navWidth,
                      expanded: navExpanded,
                      minWidth: WorkspaceMetrics.navMinWidth,
                      maxWidth: WorkspaceMetrics.navMaxWidth,
                      onWidthChanged: onNavWidthChanged,
                      onToggle: onToggleNav,
                      backgroundColor: skin.layoutBg,
                      borderSide: BorderSide(color: skin.border, width: 1),
                      child: nav,
                    ),

                  // ---- 圆角卡：中栏 + 右栏 ----
                  Expanded(
                    child: AnimatedPadding(
                      duration: WorkspaceMetrics.panelAnim,
                      curve: Curves.easeOut,
                      padding: EdgeInsets.only(
                        // studio：左栏展开时左边不留白，折叠时补 8。
                        left: (!narrow && navExpanded)
                            ? 0
                            : WorkspaceMetrics.framePadding,
                        top: WorkspaceMetrics.framePadding,
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: skin.containerBg,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _header(context, skin, narrow),
                                  // 中栏内容宽度。
                                  //
                                  // ⚠️ 限宽的**初衷是会话页的正文列**（阅读舒适度），
                                  // 不该套在技能库 / 设置这类铺卡片或表格的页面上 ——
                                  // 那些页在 2560 宽的窗口里被压成 800 只够放两列，
                                  // 右半边整片空白。
                                  //
                                  // 所以这里分两种：会话页限宽居中，其余页**占满**。
                                  // [contentMaxWidth] 为 0 表示"不设上限"。
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, c) {
                                        if (contentMaxWidth <= 0) {
                                          return SizedBox(
                                            width: c.maxWidth,
                                            height: c.maxHeight,
                                            child: child,
                                          );
                                        }
                                        return Align(
                                          alignment: Alignment.topCenter,
                                          child: SizedBox(
                                            width: c.maxWidth < contentMaxWidth
                                                ? c.maxWidth
                                                : contentMaxWidth,
                                            height: c.maxHeight,
                                            child: child,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!narrow)
                              ResizablePanel(
                                side: AxisDirection.right,
                                width: outputWidth,
                                expanded: outputExpanded,
                                minWidth: WorkspaceMetrics.outputMinWidth,
                                maxWidth: WorkspaceMetrics.outputMaxWidth,
                                onWidthChanged: onOutputWidthChanged,
                                backgroundColor: skin.containerBg,
                                borderSide:
                                    BorderSide(color: skin.borderSecondary),
                                child: output,
                              ),
                          ],
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

  /// 顶栏：高 44、padding 8。
  ///
  /// 收起/展开左栏的入口统一在窗口左上角工具行（见 [WindowToolbar]），这里只放标题槽。
  Widget _header(BuildContext context, AppSkin skin, bool narrow) {
    return SizedBox(
      height: WorkspaceMetrics.headerHeight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: headerTitle ?? const SizedBox.shrink(),
              ),
            ),
            // if (!narrow)
            //   IconButton(
            //     iconSize: 18,
            //     color: skin.textSecondary,
            //     tooltip: l10n.shellToggleOutput,
            //     icon: const Icon(Icons.view_sidebar_outlined),
            //     onPressed: onToggleOutput,
            //   ),
          ],
        ),
      ),
    );
  }
}
