import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 气泡下方的悬浮工具行。复制，编辑是真功能，其余（朗读/赞/踩/重试）目前只是可点击的占位
/// 用户气泡与回答气泡的图标顺序不同：用户气泡日期在最左，
/// 回答气泡日期在最右。
class BubbleActionsRow extends StatelessWidget {
  const BubbleActionsRow({
    super.key,
    required this.isUser,
    required this.createdAt,
    required this.onCopy,
    this.onEdit,
  });

  final bool isUser;
  final DateTime createdAt;
  final VoidCallback onCopy;

  /// 仅用户气泡传入。
  final void Function()? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateWidget = _DateLabel(createdAt: createdAt);

    final icons = isUser
        ? [
            _iconBtn(context, Icons.content_copy, l10n.chatCopy, onCopy),
            _iconBtn(context, Icons.edit_outlined, l10n.chatEdit, onEdit),
            _iconBtn(context, Icons.refresh_rounded, l10n.chatRetry, () {}),
          ]
        : [
            _iconBtn(context, Icons.content_copy, l10n.chatCopy, onCopy),
            _iconBtn(
                context, Icons.volume_up_outlined, l10n.chatReadAloud, () {}),
            _iconBtn(
                context, Icons.thumb_up_outlined, l10n.chatThumbUp, () {}),
            _iconBtn(
                context, Icons.thumb_down_outlined, l10n.chatThumbDown, () {}),
            _iconBtn(context, Icons.refresh_rounded, l10n.chatRetry, () {}),
          ];

    final children = isUser
        ? [dateWidget, ...icons]
        : [...icons, dateWidget];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, w) in children.indexed) ...[
          if (i > 0) const SizedBox(width: AppSpacing.xxs),
          w,
        ],
      ],
    );
  }

  Widget _iconBtn(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback? onTap,
  ) {
    final skin = AppSkin.of(context);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: Icon(icon, size: 14, color: skin.textTertiary),
        ),
      ),
    );
  }
}

class _DateLabel extends StatelessWidget {
  const _DateLabel({required this.createdAt});

  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final locale = Localizations.localeOf(context).toString();
    final short = DateFormat.MMMd(locale).format(createdAt);
    final full = DateFormat.yMMMd(locale).add_jm().format(createdAt);

    return Tooltip(
      message: full,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
        child: Text(
          short,
          style: TextStyle(fontSize: 12, color: skin.textTertiary),
        ),
      ),
    );
  }
}

/// 复制文本到剪贴板并提示。气泡工具行的复制按钮共用这个动作。
void copyToClipboard(BuildContext context, String text, String copiedLabel) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(copiedLabel), duration: const Duration(seconds: 1)),
  );
}
