import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/chat/code_artifact.dart';

/// 代码块芯片 —— 点击后在右侧面板打开这条产物。
///
/// 从 `text_bubble.dart` 拆出来：它跟气泡的**形态**（有框/无框、填充色、内边距）
/// 毫无关系，只是恰好画在气泡里。两者各自演化，混在一个文件里必然互相绊。
class ArtifactChip extends StatelessWidget {
  const ArtifactChip({
    super.key,
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
            Icon(Icons.code, size: 14, color: skin.textSecondary),
            const SizedBox(width: 4),
            Text(
              artifact.title,
              style: TextStyle(fontSize: 12, color: skin.text),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward, size: 12, color: skin.textTertiary),
          ],
        ),
      ),
    );
  }
}
