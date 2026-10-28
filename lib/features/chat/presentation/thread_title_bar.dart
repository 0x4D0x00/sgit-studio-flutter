import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/chat/application/thread_list_controller.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/thread_actions.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 中栏左上角的会话标题 + 下拉菜单（置顶 / 重命名 / 删除）。
///
/// 标题直接取 [threadListProvider] 里当前 thread 的 `title`，与左栏历史条目
/// 读的是同一份数据 —— 改名后两边同时变，且回落规则（用户改的名 > 首条消息
/// 摘要 > "新对话"）由 Rust 侧算好，这里不再自己来一套。
///
/// 当前 thread 还不在列表里（刚发第一条消息、列表尚未刷新）时不显示。
class ThreadTitleBar extends ConsumerWidget {
  const ThreadTitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadId =
        ref.watch(chatControllerProvider.select((s) => s.currentThreadId));
    if (threadId == null) return const SizedBox.shrink();

    final thread = ref.watch(threadListProvider.select(
      (s) => s.items.where((t) => t.id == threadId).firstOrNull,
    ));
    if (thread == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);

    return Padding(
      padding: EdgeInsets.zero,
      child: Align(
        alignment: Alignment.centerLeft,
        child: AppMenuAnchor(
          align: AppMenuAlign.underEnd,
          semanticLabel: thread.title,
          entries: [
            AppMenuAction(
              icon: Icons.push_pin_outlined,
              label: l10n.navChatPin,
              shortcut: kMenuPinShortcutLabel,
              shortcutActivator: kMenuPinActivator,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  // TODO：置顶功能待接
                  content: Text(l10n.commonNotWired('pin')),
                  duration: const Duration(seconds: 1),
                ),
              ),
            ),
            AppMenuAction(
              icon: Icons.edit_outlined,
              label: l10n.navChatRename,
              shortcut: kMenuRenameShortcutLabel,
              shortcutActivator: kMenuRenameActivator,
              onTap: () => renameThreadWithDialog(
                  context, ref, thread.id, thread.title),
            ),
            AppMenuAction(
              icon: Icons.delete_outline,
              label: l10n.commonDelete,
              danger: true,
              onTap: () async {
                final deleted = await deleteThreadWithConfirm(
                    context, ref, thread.id, thread.title);
                if (deleted) {
                  ref.read(chatControllerProvider.notifier).newChat();
                }
              },
            ),
          ],
          child: Padding(
            // 顶栏内容区只有 28 高（44 - 上下 padding 8），竖向不再加 padding，
            // 否则字被裁掉；行高固定为 1.2 避免中文字体的大行高撑破。
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Text(
                      thread.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, height: 1.2, color: skin.text),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.keyboard_arrow_down,
                    size: 18, color: skin.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
