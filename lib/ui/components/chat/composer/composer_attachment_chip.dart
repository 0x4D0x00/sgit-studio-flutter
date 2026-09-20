import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/composer_metrics.dart';

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
  });

  final String name;
  final bool isImage;
  final VoidCallback onRemove;

  /// × 按钮的读屏标签。
  final String removeSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return Container(
      height: ComposerMetrics.attachmentChipHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: ComposerMetrics.attachmentChipPaddingInline,
      ),
      decoration: BoxDecoration(
        color: skin.containerBgSecondary,
        borderRadius:
            BorderRadius.circular(ComposerMetrics.attachmentChipRadius),
        border: Border.all(color: skin.borderSecondary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
            size: ComposerMetrics.attachmentChipIconSize,
            color: skin.textSecondary,
          ),
          const SizedBox(width: ComposerMetrics.attachmentChipGap),
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ComposerMetrics.attachmentChipMaxNameWidth,
            ),
            child: Text(
              name,
              maxLines: 1,
              // 文件名的**尾部**才是有信息量的那半截（扩展名、序号），
              // 所以从中间截而不是末尾截。
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: ComposerMetrics.attachmentChipFontSize,
                color: skin.text,
              ),
            ),
          ),
          const SizedBox(width: ComposerMetrics.attachmentChipGap),
          Semantics(
            label: removeSemanticLabel,
            button: true,
            child: InkWell(
              onTap: onRemove,
              child: Icon(
                Icons.close,
                size: ComposerMetrics.chipCloseIconSize,
                color: skin.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
