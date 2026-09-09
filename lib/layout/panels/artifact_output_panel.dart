import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/chat/code_artifact.dart';

/// 右侧产物面板 —— 显示从对话中提取的代码/文档。
///
/// 顶栏：标题（左）+ Copy / Publish / 全屏 / 关闭（右）
/// 主区：代码内容（带语法高亮的 monospace）
///
/// ⚠️ 纯展示组件：文案由调用方传入（走 l10n），配色走 [AppSkin]。
class ArtifactOutputPanel extends StatelessWidget {
  const ArtifactOutputPanel({
    super.key,
    required this.artifact,
    required this.copyLabel,
    required this.publishLabel,
    required this.fullscreenLabel,
    required this.closeLabel,
    required this.onClose,
    this.onPublish,
  });

  final CodeArtifact artifact;
  final String copyLabel;
  final String publishLabel;
  final String fullscreenLabel;
  final String closeLabel;
  final VoidCallback onClose;
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, skin),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SelectableText(
              artifact.code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
                color: skin.text,
              ),
            ),
          ),
        ),
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
                if (artifact.language.isNotEmpty)
                  Text(
                    artifact.language.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: skin.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
          // Copy 按钮
          _HeaderButton(
            label: copyLabel,
            icon: Icons.content_copy,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: artifact.code));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已复制'),
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.xxs),
          // Publish 按钮（可选）
          if (onPublish != null)
            _HeaderButton(
              label: publishLabel,
              icon: Icons.publish,
              onPressed: onPublish!,
              filled: true,
            ),
          const SizedBox(width: AppSpacing.xxs),
          // 全屏按钮
          _HeaderButton(
            label: fullscreenLabel,
            icon: Icons.open_in_full,
            onPressed: () {
              // TODO: 实现全屏查看
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('全屏功能待实现'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.xxs),
          // 关闭按钮
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

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    if (filled) {
      return FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xxs,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: skin.textSecondary),
      label: Text(
        label,
        style: TextStyle(fontSize: 13, color: skin.textSecondary),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
