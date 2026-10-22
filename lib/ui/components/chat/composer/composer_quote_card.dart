import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/hover_remove_button.dart';

/// 输入框头部的「引用」卡片：左侧一道竖条 + 被引用的文字。
///
/// 点卡片本身 = 查看全文，右上角 × = 移除。纯展示组件。
class ComposerQuoteCard extends StatelessWidget {
  const ComposerQuoteCard({
    super.key,
    required this.text,
    required this.onTap,
    this.onRemove,
    this.removeSemanticLabel = '',
    this.size = 96,
  });

  final String text;
  final VoidCallback onTap;

  /// null = 不显示 ×（已发出的消息里的引用不能再移除）。
  final VoidCallback? onRemove;
  final String removeSemanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final radius = BorderRadius.circular(AppRadius.md);

    return HoverRemoveButton(
      onRemove: onRemove,
      semanticLabel: removeSemanticLabel,
      child: SizedBox(
        width: size,
        height: size,
        child: Material(
          color: skin.containerBgSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: skin.borderSecondary),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: skin.borderSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      text,
                      overflow: TextOverflow.fade,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: skin.textSecondary,
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
