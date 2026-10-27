import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/domain/models/chat/message_quotes.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/model_list_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/services/layout/layout_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/approval_card.dart';
import 'package:sgit_studio_flutter/ui/components/chat/notice_bar.dart';
import 'package:sgit_studio_flutter/ui/components/chat/text_bubble.dart';
import 'package:sgit_studio_flutter/ui/components/chat/tool_card.dart';

/// 一条 → 一张卡。用 sealed class 的 switch，新增条目类型时编译器会在这里拦住。
Widget buildTranscriptCard(
  WidgetRef ref,
  ChatController ctrl,
  AppLocalizations l10n,
  ChatItem item, {
  required bool isLastAnswer,
  required bool replyComplete,
}) => switch (item) {
  final TextItem t => TextBubble(
    item: t,
    truncatedHint: l10n.chatTextTruncated,
    isLastAnswer: isLastAnswer,
    replyComplete: replyComplete,
    onOpenArtifact: ref.read(layoutControllerProvider.notifier).showArtifact,
    onEditSave: t.role == ChatRole.user
        // 编辑的只是正文，原消息带的引用要原样带上。
        ? (text) => ctrl.editAndResend(
            t.id,
            MessageQuotes.encode(MessageQuotes.split(t.text).quotes, text),
            model: ref
                .read(modelListProvider)
                .effective(
                  ref.read(composerSettingsProvider).settings.selectedModel,
                )
                ?.id,
          )
        : null,
  ),
  final ToolItem t => ToolCard(
    item: t,
    runningLabel: l10n.chatToolRunning,
    truncatedLabel: l10n.chatToolTruncated,
    elapsedLabel: switch (t.elapsedMs) {
      final int ms => l10n.chatToolElapsed(ms),
      null => null,
    },
  ),
  final ApprovalItem a => ApprovalCard(
    item: a,
    title: l10n.chatApprovalTitle,
    labels: {
      ApprovalDecision.accept: l10n.chatApprovalAllowOnce,
      ApprovalDecision.acceptForSession: l10n.chatApprovalAllowAlways,
      ApprovalDecision.decline: l10n.chatApprovalDeny,
    },
    resolvedLabel: (wire) => switch (wire) {
      'accept' => l10n.chatApprovalResolvedAllow,
      'acceptForSession' => l10n.chatApprovalResolvedAlways,
      'decline' => l10n.chatApprovalResolvedDeny,
      _ => wire,
    },
    onDecide: (d) => ctrl.respond(a, d),
  ),
  final NoticeItem n => NoticeBar(item: n),
};

/// 选中文字后浮出的「回复」按钮。位置由宿主（`TranscriptReplyMixin`）算好传入。
class TranscriptReplyButton extends StatelessWidget {
  const TranscriptReplyButton({
    super.key,
    required this.position,
    required this.label,
    required this.onTap,
  });

  static const size = Size(60, 34);

  /// 左上角，相对外层 Stack。null = 不显示。
  final Offset? position;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pos = position;
    if (pos == null) return const SizedBox.shrink();
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: Material(
        color: const Color(0xFF3A3A3A),
        borderRadius: BorderRadius.circular(10),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          // 不抢焦点：抢了的话选区会先被清掉。
          canRequestFocus: false,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.reply, size: 14, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ctrl+A 的入口：交给 [onSelectAll] 自己决定怎么全选。
///
/// ⚠️ 必须挂在 `SelectionArea` **外面**。`SelectableRegion` 是用
/// `Action.overridable` 注册 `SelectAllTextIntent` 的，查找方向只往祖先走 ——
/// 放在它里面永远拦不到。外层换掉之后，默认动作只剩 `callingAction` 一条路，
/// 由 [SelectAllIntentAction] 决定要不要往下传（见 `selectable_region.dart`
/// 的 `_NonOverrideAction.invoke`）。
class SelectAllIntentAction extends Action<SelectAllTextIntent> {
  SelectAllIntentAction(this.onSelectAll);

  final VoidCallback onSelectAll;

  @override
  void invoke(SelectAllTextIntent intent) => onSelectAll();
}

/// Ctrl+C 的入口：能自己处理就吞掉，否则回落给选区。
///
/// 回落走 `callingAction`（`Action.overridable` 在调用我们之前塞进来的默认动作），
/// 所以"复制当前选区"这套平台行为一点没变，只有长会话的全选快照走我们的分支。
class CopyIntentAction extends Action<CopySelectionTextIntent> {
  CopyIntentAction(this.onCopy);

  /// 返回 `true` 表示已处理，不要再往下传。
  final bool Function() onCopy;

  @override
  void invoke(CopySelectionTextIntent intent) {
    if (onCopy()) return;
    callingAction?.invoke(intent);
  }
}
