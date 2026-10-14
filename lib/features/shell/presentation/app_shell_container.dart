import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/thread_title_bar.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/nav_panel_container.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/panels/artifact_output_panel.dart';
import 'package:sgit_studio_flutter/layout/panels/output_panel.dart';
import 'package:sgit_studio_flutter/layout/shell/app_shell.dart';
import 'package:sgit_studio_flutter/services/export/artifact_exporter.dart';
import 'package:sgit_studio_flutter/services/layout/layout_controller.dart';
import 'package:sgit_studio_flutter/services/layout/transcript_width.dart';
import 'package:sgit_studio_flutter/ui/components/chat/artifact/artifact_viewer.dart';

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
    // 中栏宽度档位。布局是 5 个横切状态之一，这一层是它在外壳上的唯一订阅点。
    final contentMaxWidth =
        ref.watch(transcriptWidthProvider).contentMaxWidth;

    final artifact = layout.activeArtifact;

    // 根据是否有活跃产物选择右侧面板内容
    final outputPanel = artifact != null
        ? ArtifactOutputPanel(
            artifact: artifact,
            copyLabel: l10n.chatCopy,
            downloadLabel: l10n.chatArtifactDownload,
            closeLabel: l10n.chatArtifactClose,
            onClose: ctrl.closeOutput,
            onCopy: () => copyArtifact(context, artifact, l10n.chatCopied),
            onDownload: () => _download(context, artifact),
            child: ArtifactViewer(artifact: artifact),
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
      contentMaxWidth: contentMaxWidth,
      onToggleNav: ctrl.toggleNav,
      onToggleOutput: ctrl.toggleOutput,
      onNavWidthChanged: ctrl.setNavWidth,
      onOutputWidthChanged: ctrl.setOutputWidth,
      nav: NavPanelContainer(activeNavId: activeNavId),
      output: outputPanel,
      headerTitle: activeNavId == null ? const ThreadTitleBar() : null,
      child: child,
    );
  }

  /// 面板里的 Download。与卡片上的 Download 走同一个 exporter ——
  /// 两个入口落出来的文件必须一模一样。
  Future<void> _download(BuildContext context, ChatArtifact artifact) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final outcome = await ArtifactExporter.save(
      artifact,
      dialogTitle: l10n.chatArtifactDownload,
    );
    if (outcome == SaveOutcome.cancelled) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          outcome == SaveOutcome.saved
              ? l10n.chatArtifactSaved
              : l10n.chatArtifactSaveFailed,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
