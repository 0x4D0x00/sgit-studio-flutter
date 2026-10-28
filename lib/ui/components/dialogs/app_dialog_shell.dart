import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 重命名 / 删除确认这类小弹窗的统一外壳：大圆角、左上粗标题、
/// 右上关闭、可选副标题，底部右对齐操作按钮。
class AppDialogShell extends StatelessWidget {
  const AppDialogShell({
    super.key,
    required this.title,
    this.subtitle,
    this.body,
    required this.actions,
    this.width = 440,
  });

  final String title;
  final String? subtitle;
  final Widget? body;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    return Dialog(
      backgroundColor: skin.containerBg,
      elevation: 0,
      insetPadding: const EdgeInsets.all(AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md + 6),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: skin.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  InkResponse(
                    radius: 16,
                    onTap: () => Navigator.of(context).pop(),
                    child: Tooltip(
                      message: l10n.commonClose,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close, size: 18, color: skin.text),
                      ),
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: skin.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
              if (body != null) ...[const SizedBox(height: 16), body!],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    actions[i],
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 弹窗底部的胶囊按钮；[kind] 决定配色。
enum AppDialogButtonKind { neutral, primary, danger }

class AppDialogButton extends StatelessWidget {
  const AppDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = AppDialogButtonKind.neutral,
  });

  final String label;
  final VoidCallback onPressed;
  final AppDialogButtonKind kind;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final error = Theme.of(context).colorScheme.error;
    final (bg, fg, side) = switch (kind) {
      AppDialogButtonKind.neutral => (
        skin.containerBg,
        skin.text,
        BorderSide(color: skin.border),
      ),
      AppDialogButtonKind.primary => (
        skin.text,
        skin.containerBg,
        BorderSide.none,
      ),
      AppDialogButtonKind.danger => (
        error.withValues(alpha: 0.12),
        error,
        BorderSide.none,
      ),
    };
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(72, 44),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: side,
        ),
      ),
      child: Text(label),
    );
  }
}
