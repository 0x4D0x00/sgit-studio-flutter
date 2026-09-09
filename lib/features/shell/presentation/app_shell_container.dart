import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/features/shell/presentation/nav_panel_container.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/panels/artifact_output_panel.dart';
import 'package:sgit_studio_flutter/layout/panels/output_panel.dart';
import 'package:sgit_studio_flutter/layout/shell/app_shell.dart';
import 'package:sgit_studio_flutter/services/layout/layout_controller.dart';

/// 外壳容器 —— 把布局状态与回调喂给纯组件 `AppShell`。
///
/// 这是**整个外壳唯一的 provider 订阅点**：`AppShell` / `NavPanel` / `OutputPanel`
/// 三个纯组件都不认识 Riverpod。
class AppShellContainer extends ConsumerWidget {
  const AppShellContainer({
    super.key,
    required this.child,
    this.activeNavId,
  });

  final Widget child;

  /// 当前激活的导航项 id（产物页 / 智能体子页 / null=工作台）。
  final String? activeNavId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final layout = ref.watch(layoutControllerProvider);
    final ctrl = ref.read(layoutControllerProvider.notifier);

    // 根据是否有活跃产物选择右侧面板内容
    final outputPanel = layout.activeArtifact != null
        ? ArtifactOutputPanel(
            artifact: layout.activeArtifact!,
            copyLabel: 'Copy',
            publishLabel: 'Publish',
            fullscreenLabel: '全屏',
            closeLabel: '关闭',
            onClose: ctrl.closeOutput,
          )
        : OutputPanel(
            title: l10n.shellOutputTitle,
            emptyText: l10n.shellOutputEmpty,
          );

    return AppShell(
      navExpanded: layout.navExpanded,
      navWidth: layout.navWidth,
      outputExpanded: layout.outputExpanded,
      outputWidth: layout.outputWidth,
      onToggleNav: ctrl.toggleNav,
      onToggleOutput: ctrl.toggleOutput,
      onNavWidthChanged: ctrl.setNavWidth,
      onOutputWidthChanged: ctrl.setOutputWidth,
      nav: NavPanelContainer(activeNavId: activeNavId),
      output: outputPanel,
      child: child,
    );
  }
}
