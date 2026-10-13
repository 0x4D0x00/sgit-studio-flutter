import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/model_list_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/services/brand/brand_assets.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/approval_card.dart';
import 'package:sgit_studio_flutter/ui/components/chat/notice_bar.dart';
import 'package:sgit_studio_flutter/ui/components/chat/text_bubble.dart';
import 'package:sgit_studio_flutter/ui/components/chat/thinking_row.dart';
import 'package:sgit_studio_flutter/ui/components/chat/tool_card.dart';

/// 对话流。
///
/// ## 为什么订阅的是 `itemsRevision` 而不是 provider 的 state
///
/// 列表**只在增删条目时**重建；流式文本的每一条 delta 只让对应气泡自己重建
/// （见各卡片内部的 `ValueListenableBuilder`）。如果这里改成
/// `ref.watch(chatControllerProvider)`，一条 delta 就会重建整个 `ListView`，
/// 长会话直接掉帧 —— 那样 FFI 那一堆零拷贝的努力全白费。
class ChatTranscript extends ConsumerWidget {
  const ChatTranscript({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(chatControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);

    // ⚠️ **只订阅这一个 bool**，不订整个 state。真正的流式热路径是
    // `itemsRevision` + 各气泡自己的 `revision`，这里多订一个字段会让
    // 每次 parse state 变化都过一遍本 widget 的 build —— `select` 把它缩到
    // "这一个 bool 变了才重建"。
    final thinking =
        ref.watch(chatControllerProvider.select((s) => s.thinking));

    return ValueListenableBuilder<int>(
      valueListenable: ctrl.itemsRevision,
      builder: (context, _, _) {
        final items = ctrl.items;
        // 最后一组回答的末尾气泡（当前/最近这轮的 assistant 文本）—— 从后往前
        // 找第一条 assistant TextItem，工具行对它常驻显示。
        int? lastAssistantId;
        for (var i = items.length - 1; i >= 0; i--) {
          final it = items[i];
          if (it is TextItem && it.role == ChatRole.assistant) {
            lastAssistantId = it.id;
            break;
          }
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(
              horizontal: WorkspaceMetrics.contentPaddingInline,
              vertical: WorkspaceMetrics.framePadding),
          // ⚠️ 思考行是列表的**最后一项**（索引 == items.length），不是 index 0
          // 的头部 —— 它跟着"最新一轮"走，而不是钉在会话顶端。
          //
          // 代价是 items 每加一条就让它的索引+1，也就是说**它无法被 Element 复用**，
          // 每轮对话都会重新 mount（Timer 跟着重建，见 ThinkingRow 的 dispose）。
          // 换来的是不用在每张卡前面插一刀、也不必管它该排在哪条旁边。
          // 这一行一轮只出现一次，重建的代价可以忽略。
          itemCount: items.length + (thinking ? 1 : 0),
          // 条目身份稳定，给 key 让 Flutter 复用 Element，避免整表重建。
          itemBuilder: (context, i) {
            if (i >= items.length) return const ThinkingRow();
            return KeyedSubtree(
              key: ValueKey<int>(items[i].id),
              child: _card(context, ref, ctrl, l10n, items[i],
                  isLastAnswer: items[i].id == lastAssistantId),
            );
          },
        );
      },
    );
  }

  /// 一条 → 一张卡。用 sealed class 的 switch，新增条目类型时编译器会在这里拦住。
  Widget _card(BuildContext context, WidgetRef ref, ChatController ctrl,
          AppLocalizations l10n, ChatItem item,
          {required bool isLastAnswer}) =>
      switch (item) {
        final TextItem t => TextBubble(
            item: t,
            truncatedHint: l10n.chatTextTruncated,
            isLastAnswer: isLastAnswer,
            // 品牌头像在这里注入 —— `ui/` 层不许 import `services/`，
            // 所以 TextBubble 只收 ImageProvider，自己去哪取归本层管。
            assistantAvatar: BrandAssets.image(BrandAssets.loginMark),
            onEditSave: t.role == ChatRole.user
                ? (text) => ctrl.editAndResend(t.id, text,
                    model: ref
                        .read(modelListProvider)
                        .effective(ref
                            .read(composerSettingsProvider)
                            .settings
                            .selectedModel)
                        ?.id)
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
}
