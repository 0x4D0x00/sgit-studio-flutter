import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/thread_title_bar.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/nav_panel_container.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
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
///
/// ⚠️ 它同时是**右侧面板的收口点**。面板里的产物属于某条会话，所以它的可见性
/// 由「布局状态」与「当前是不是会话页」两个条件共同决定 —— 只看前者，用户在
/// Projects 页会看到一个占着半屏、内容却来自那条会话的面板（见 [didUpdateWidget]）。
class AppShellContainer extends ConsumerStatefulWidget {
  const AppShellContainer({
    super.key,
    required this.child,
    required this.isConversation,
    this.activeNavId,
  });

  final Widget child;

  /// 当前路由是不是**会话页**（工作台）。
  ///
  /// 由路由层判定后注入 —— 不在这一层靠 `activeNavId == null` 反推：那个条件
  /// 是"没有激活的导航项"，而设置页、登录页同样满足，会把非会话页误判成会话页。
  /// 右侧面板只在会话页上有效，判错就会漏关（见 [didUpdateWidget]）。
  final bool isConversation;

  /// 当前激活的导航项 id（产物页 / 智能体子页 / null=工作台）。
  final String? activeNavId;

  @override
  ConsumerState<AppShellContainer> createState() => _AppShellContainerState();
}

class _AppShellContainerState extends ConsumerState<AppShellContainer> {
  @override
  void didUpdateWidget(AppShellContainer old) {
    super.didUpdateWidget(old);
    // 离开会话页 → 真的关掉右侧面板（不只是藏起来）。
    //
    // ⚠️ 判据是**离开**会话页，而不是"路由变了"。产物页点一张卡片的顺序是
    // `showArtifact()` 之后才 `go(home)` —— 打开面板那一刻人还站在产物页上。
    // 按"路由变了"关，会在跳回会话的路上把它当场关掉。
    if (old.isConversation && !widget.isConversation) {
      // 延到帧后再改状态：本回调跑在 build 之前，此刻动 provider 会把正在
      // 构建的这棵树标脏。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(layoutControllerProvider.notifier).closeOutput();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用宽度动态计算右侧面板的安全宽度
        // 总宽度 - 左栏宽度(如果展开) - 中栏最小宽度 = 右侧面板可用空间
        final totalWidth = constraints.maxWidth;
        final navActualWidth = layout.navExpanded ? layout.navWidth : 0;
        final minCenterWidth = contentMaxWidth * 0.6; // 中栏至少保留 70% 的内容宽度
        final availableForOutput = totalWidth - navActualWidth - minCenterWidth;
        final safeOutputWidth = layout.outputWidth.clamp(
          WorkspaceMetrics.outputMinWidth,
          availableForOutput.clamp(
            WorkspaceMetrics.outputMinWidth,
            WorkspaceMetrics.outputMaxWidth,
          ),
        );

        return AppShell(
          navExpanded: layout.navExpanded,
          navWidth: layout.navWidth,
          // ⚠️ 非会话页恒为 false。关状态是 post-frame 的（见 didUpdateWidget），
          // 只靠它会让离开会话页的那一帧仍把面板画出来 —— 肉眼就是"闪一下"。
          outputExpanded: widget.isConversation && layout.outputExpanded,
          outputWidth: safeOutputWidth,
          contentMaxWidth: contentMaxWidth,
          onToggleNav: ctrl.toggleNav,
          onToggleOutput: ctrl.toggleOutput,
          onNavWidthChanged: ctrl.setNavWidth,
          onOutputWidthChanged: ctrl.setOutputWidth,
          nav: NavPanelContainer(activeNavId: widget.activeNavId),
          output: outputPanel,
          headerTitle: widget.isConversation ? const ThreadTitleBar() : null,
          child: widget.child,
        );
      },
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
