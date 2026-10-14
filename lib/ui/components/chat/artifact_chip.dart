import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/design/tokens/bubble_metrics.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/ui/components/chat/artifact_kind_icon.dart';

/// 产物文件卡片 —— 回答末尾的入口，点击在右侧面板打开这条产物。
///
/// 样式：整行宽的圆角卡，左侧类型图标格，中间「标题 + 类型标签」，
/// 右侧 Download 描边按钮。标题单行省略，长标题不撑高卡片。
///
/// 从 `text_bubble.dart` 拆出来：它跟气泡的**形态**（有框/无框、填充色、内边距）
/// 毫无关系，只是恰好画在气泡里。
class ArtifactChip extends StatelessWidget {
  const ArtifactChip({
    super.key,
    required this.artifact,
    required this.onTap,
    required this.onDownload,
    required this.downloadLabel,
  });

  final ChatArtifact artifact;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final String downloadLabel;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        // 贴合内容，到上限封顶 —— 见 [ChatBubbleMetrics.artifactCardMaxWidth]。
        constraints: const BoxConstraints(
          maxWidth: ChatBubbleMetrics.artifactCardMaxWidth,
        ),
        child: Material(
          color: skin.containerBgSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: skin.borderSecondary),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            hoverColor: skin.text.withValues(alpha: 0.04),
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: ChatBubbleMetrics.artifactCardIconBox,
                    height: ChatBubbleMetrics.artifactCardIconBox,
                    decoration: BoxDecoration(
                      color: skin.containerBg,
                      border: Border.all(color: skin.border),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      artifactKindIcon(artifact.kind),
                      size: 18,
                      color: skin.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Flexible 而不是 Expanded：标题短时卡片就窄，
                  // 长时才吃掉剩余空间（到 maxWidth 为止）。
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          artifact.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: skin.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          artifact.typeLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: skin.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    height: 28,
                    child: OutlinedButton(
                      onPressed: onDownload,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: skin.text,
                        side: BorderSide(color: skin.border),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      child: Text(
                        downloadLabel,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
