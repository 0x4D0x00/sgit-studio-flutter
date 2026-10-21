import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/features/chat/application/thread_list_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/confirm.dart';

/// 会话的改名 / 删除交互。
///
/// 左栏历史条目的「⋯」菜单和中栏顶部的标题下拉菜单是**同一批动作**，
/// 放在一处，两边的对话框、回落规则就不会各写一份然后漂开。

/// 弹改名框并提交。取消则什么都不做。返回提交的新名字（取消为 null）。
Future<String?> renameThreadWithDialog(
  BuildContext context,
  WidgetRef ref,
  String threadId,
  String current,
) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _RenameDialog(initial: current),
  );
  // null = 取消。空串是"用户真的清空了"，交给 controller 回落到 preview，
  // 与"没点确认"是两回事，不能合并判断。
  if (name == null) return null;
  await ref.read(threadListProvider.notifier).rename(threadId, name.trim());
  return name.trim();
}

/// 危险确认后删除。返回是否真的删了。
Future<bool> deleteThreadWithConfirm(
  BuildContext context,
  WidgetRef ref,
  String threadId,
  String label,
) async {
  final l10n = AppLocalizations.of(context);
  final ok = await confirmDanger(
    context,
    title: l10n.studioRemoveConfirm(label),
    confirmText: l10n.commonDelete,
  );
  if (!ok) return false;
  await ref.read(threadListProvider.notifier).remove(threadId);
  return true;
}

/// controller 由对话框自己的 State 持有：pop 之后退场动画还会重建 TextField，
/// 在调用处 dispose 会 "used after being disposed"。
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});
  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.navChatRename),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.chatRenameHint),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.commonConfirm),
        ),
      ],
    );
  }
}
