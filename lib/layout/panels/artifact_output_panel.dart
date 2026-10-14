import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/ui/components/chat/artifact_kind_icon.dart';

/// 右侧产物面板 —— 显示从对话中提取的代码/文档/图表/工具产出。
///
/// 顶栏：类型图标 + 标题（左）+ Copy / Download / 全屏 / 关闭（右）
/// 主区：[child] —— 正文**不由本组件决定**。
///
/// ⚠️ 正文渲染下沉到 `ArtifactViewer`（`ui/`）是有意的：按类型分派要复用
/// `MarkdownView`，而本文件在 `layout/`，那里的定位是"只管空间，不管内容"。
/// 这个组件退化成纯外壳 —— 它只认识 [ChatArtifact] 的标题与类型，
/// **不认识内容长什么样**。
class ArtifactOutputPanel extends StatelessWidget {
  const ArtifactOutputPanel({
    super.key,
    required this.artifact,
    required this.child,
    required this.copyLabel,
    required this.downloadLabel,
    required this.closeLabel,
    required this.onClose,
    required this.onCopy,
    this.onDownload,
  });

  final ChatArtifact artifact;

  /// 正文。由调用方注入（`ArtifactViewer`）。
  final Widget child;

  final String copyLabel;
  final String downloadLabel;
  final String closeLabel;

  final VoidCallback onClose;
  final VoidCallback onCopy;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, skin),
        Expanded(child: child),
      ],
    );
  }

  Widget _header(BuildContext context, AppSkin skin) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: skin.borderSecondary)),
      ),
      child: Row(
        children: [
          // 类型图标 —— 面板里也要能一眼看出这是代码还是图表。
          Icon(
            artifactKindIcon(artifact.kind),
            size: 16,
            color: skin.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  artifact.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: skin.text,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  artifact.typeLabel,
                  style: TextStyle(fontSize: 11, color: skin.textTertiary),
                ),
              ],
            ),
          ),
          _HeaderButton(
            label: copyLabel,
            icon: Icons.content_copy,
            onPressed: onCopy,
          ),
          if (onDownload != null) ...[
            const SizedBox(width: AppSpacing.xxs),
            _HeaderButton(
              label: downloadLabel,
              icon: Icons.download_outlined,
              onPressed: onDownload!,
            ),
          ],
          const SizedBox(width: AppSpacing.xxs),
          _HeaderButton(
            label: closeLabel,
            icon: Icons.close,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// 顶栏图标按钮：只画图标，文字（[label]）仅在鼠标悬停时以 tooltip 出现。
class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      icon: Icon(icon, size: 18),
      color: skin.textSecondary,
      hoverColor: skin.text.withValues(alpha: 0.06),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      padding: const EdgeInsets.all(AppSpacing.xs),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// 复制用的共享实现 —— 面板与卡片走同一套，避免两处各写一个 snackbar 文案。
void copyArtifact(BuildContext context, ChatArtifact artifact, String label) {
  Clipboard.setData(ClipboardData(text: artifact.content));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(label), duration: const Duration(seconds: 1)),
  );
}
