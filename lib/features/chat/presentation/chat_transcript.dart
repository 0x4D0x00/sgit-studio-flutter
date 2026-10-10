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
          itemCount: items.length,
          // 条目身份稳定，给 key 让 Flutter 复用 Element，避免整表重建。
          itemBuilder: (context, i) => KeyedSubtree(
            key: ValueKey<int>(items[i].id),
            child: _card(context, ref, ctrl, l10n, items[i],
                isLastAnswer: items[i].id == lastAssistantId),
          ),
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
