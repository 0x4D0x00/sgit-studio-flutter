import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/domain/models/chat/code_artifact.dart';
import 'package:sgit_studio_flutter/services/layout/layout_controller.dart';

/// 文本气泡。**流式期间只有它自己重建。**
///
/// 订阅的是 [TextItem.revision] 这一条 `ValueListenable`，不是整个列表的状态 ——
/// 所以 native 推来一条 delta，重建范围就是这一个气泡，而不是 `ListView` 全体。
/// 这是长回答不掉帧的关键，改之前先读 `docs/KERNEL_FFI.md` §4。
class TextBubble extends ConsumerWidget {
  const TextBubble({super.key, required this.item, required this.truncatedHint});

  final TextItem item;

  /// 「内容可能不完整」提示文案（native 背压丢过 delta 时显示）。
  final String truncatedHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = AppSkin.of(context);
    final isUser = item.role == ChatRole.user;

    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: item.revision,
        builder: (context, _, _) {
          // 提取代码块
          final artifacts = item.done
              ? CodeArtifact.extractFromMarkdown(item.text)
              : <CodeArtifact>[];

          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isUser ? skin.navItemActive : skin.containerBgSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: skin.borderSecondary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SelectableText(
                      item.text,
                      style: TextStyle(
                          fontSize: 14, height: 1.6, color: skin.text),
                    ),
                    if (item.truncated)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Text(
                          truncatedHint,
                          style: TextStyle(
                              fontSize: 11, color: skin.textTertiary),
                        ),
                      ),
                    // 代码块操作按钮
                    if (artifacts.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xxs,
                        children: [
                          for (final artifact in artifacts)
                            _ArtifactChip(
                              artifact: artifact,
                              onTap: () => ref
                                  .read(layoutControllerProvider.notifier)
                                  .showArtifact(artifact),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 代码块芯片 —— 点击后在右侧打开。
class _ArtifactChip extends StatelessWidget {
  const _ArtifactChip({
    required this.artifact,
    required this.onTap,
  });

  final CodeArtifact artifact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: skin.containerBg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: skin.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.code,
              size: 14,
              color: skin.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              artifact.title,
              style: TextStyle(
                fontSize: 12,
                color: skin.text,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward,
              size: 12,
              color: skin.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
