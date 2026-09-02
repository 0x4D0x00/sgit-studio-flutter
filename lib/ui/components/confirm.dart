import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 危险动作确认框。**删除、同步、批量覆盖一律走这里**。
///
/// 为什么单独抽一个：这类确认散落在各页各自 `showDialog` 时，很容易出现
/// 「有的删除问了、有的没问」，而没问的那个恰好是最不该漏的。收成一个入口，
/// 加动作时忘不了。
///
/// 返回 true 表示用户确认。
Future<bool> confirmDanger(
  BuildContext context, {
  required String title,
  String? message,
  String? confirmText,
  /// 确认键用警示色。删除类保持 true；同步这类可逆动作传 false。
  bool danger = true,
}) async {
  final l10n = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 15)),
      content: message == null
          ? null
          : SizedBox(
              width: 400,
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: scheme.error)
              : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmText ?? l10n.commonConfirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}
