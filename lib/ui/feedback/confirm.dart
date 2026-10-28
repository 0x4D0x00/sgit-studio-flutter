import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/dialogs/app_dialog_shell.dart';

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

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialogShell(
      title: title,
      subtitle: message,
      actions: [
        AppDialogButton(
          label: l10n.commonCancel,
          onPressed: () => Navigator.of(ctx).pop(false),
        ),
        AppDialogButton(
          label: confirmText ?? l10n.commonConfirm,
          kind: danger
              ? AppDialogButtonKind.danger
              : AppDialogButtonKind.primary,
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return ok ?? false;
}
