import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/hover_remove_button.dart';

/// 输入框头部的附件 chip。
///
/// 对齐 studio 的 `ContextContainer`（`Desktop/ContextContainer/index.tsx`）——
/// 附件区在编辑区**上方**，不是下方：用户先看到"要带什么走"，再写"让它做什么"。
///
/// ⚠️ 纯展示组件：文件名/是否图片由外部判好传进来。
class ComposerAttachmentChip extends StatelessWidget {
  const ComposerAttachmentChip({
    super.key,
    required this.name,
    required this.isImage,
    required this.onRemove,
    required this.removeSemanticLabel,
    this.size = 96,
  });

  final double size;

  final String name;
  final bool isImage;
  final VoidCallback onRemove;

  /// × 按钮的读屏标签。
  final String removeSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    // 与 ComposerQuoteCard 同尺寸方块：文件名在上，扩展名角标在左下，× 在右上角。
    final dot = name.lastIndexOf('.');
    final ext = dot > 0 && dot < name.length - 1
        ? name.substring(dot + 1).toUpperCase()
        : (isImage ? 'IMAGE' : 'FILE');

    return HoverRemoveButton(
      onRemove: onRemove,
      semanticLabel: removeSemanticLabel,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: skin.containerBgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: skin.borderSecondary),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
              style: TextStyle(fontSize: 13, height: 1.3, color: skin.text),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: skin.borderSecondary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(
                ext,
                style: TextStyle(fontSize: 10, color: skin.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
