import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/thread_actions.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/nav/nav_common.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 历史对话项行尾「⁝」菜单。Rename / Delete 都真落地（`thread/name/set`、
/// `thread/delete`）；Pin 没有对应内核能力，见下方注释。
List<AppMenuEntry> buildChatItemMenu(
  BuildContext context,
  WidgetRef ref,
  AppLocalizations l10n,
  ThreadSummary t,
) {
  return [
    AppMenuAction(
      icon: Icons.push_pin_outlined,
      label: l10n.navChatPin,
      shortcut: kMenuPinShortcutLabel,
      shortcutActivator: kMenuPinActivator,
      // TODO:sgcode 没有置顶能力（React studio 的「收藏」存在 gateway 自己的
      // per-cid KV 里，客户端这条路还没接）
      onTap: () => showNavNotWired(context, l10n, 'pin'),
    ),
    AppMenuAction(
      icon: Icons.edit_outlined,
      label: l10n.navChatRename,
      shortcut: kMenuRenameShortcutLabel,
      shortcutActivator: kMenuRenameActivator,
      // 改标题。走 sgcode 的 `thread/name/set`（controller 内部乐观更新 + 失败回滚）。
      onTap: () => renameThreadWithDialog(context, ref, t.id, t.title),
    ),
    AppMenuAction(
      icon: Icons.delete_outline,
      label: l10n.commonDelete,
      danger: true,
      onTap: () => deleteThreadResettingIfCurrent(context, ref, t.id, t.title),
    ),
  ];
}

/// 删一条会话（带确认）；删的正是当前打开的那条时，中栏不能还挂着它，
/// 回到干净的新对话。返回是否真的删了。
Future<bool> deleteThreadResettingIfCurrent(
  BuildContext context,
  WidgetRef ref,
  String threadId,
  String label,
) async {
  final deleted = await deleteThreadWithConfirm(context, ref, threadId, label);
  if (deleted && ref.read(chatControllerProvider).currentThreadId == threadId) {
    ref.read(chatControllerProvider.notifier).newChat();
  }
  return deleted;
}
