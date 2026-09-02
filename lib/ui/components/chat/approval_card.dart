import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';

/// 审批卡 —— **CLI 里最高频的交互**（`/approve`、guardian 审批），GUI 不能没有。
///
/// 内核在等我们回话，**不回就一直卡在那**，所以这张卡视觉上必须够醒目，
/// 而且三个选项要分得清：允许一次 / 总是允许 / 拒绝。
/// 「总是允许」会改权限档、影响后续所有同类操作，因此单独一档，不和「允许一次」混。
class ApprovalCard extends StatelessWidget {
  const ApprovalCard({
    super.key,
    required this.item,
    required this.title,
    required this.labels,
    required this.resolvedLabel,
    required this.onDecide,
  });

  final ApprovalItem item;
  final String title;

  /// 三个按钮的文案，键即决定。
  final Map<ApprovalDecision, String> labels;

  /// 已回应后显示的文案解析器。
  final String Function(String wire) resolvedLabel;

  final void Function(ApprovalDecision) onDecide;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: item.revision,
        builder: (context, _, _) {
          final decided = item.decision;
          return Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: skin.containerBgSecondary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              // 待决时用警示色描边，决完回归普通边框 —— 一眼能看出还欠不欠动作。
              border: Border.all(
                color: decided == null
                    ? Theme.of(context).colorScheme.error
                    : skin.borderSecondary,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 16, color: Theme.of(context).colorScheme.error),
                    const SizedBox(width: AppSpacing.xs),
                    // ⚠️ 这一行原先两个都是裸 Text、没有任何弹性 —— 窄屏必溢出。
                    Flexible(
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: skin.text)),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(item.kind,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: skin.textTertiary)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                // 显示的是**被审批那条工具卡**的入参（内核不重复带内容）。
                SelectableText(
                  item.reason.isNotEmpty ? item.reason : item.detail,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      fontFamily: 'monospace',
                      color: skin.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (decided == null)
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: [
                      for (final d in ApprovalDecision.values)
                        _button(context, d),
                    ],
                  )
                else
                  Text(
                    resolvedLabel(decided),
                    style: TextStyle(fontSize: 12, color: skin.textTertiary),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _button(BuildContext context, ApprovalDecision d) {
    final label = labels[d] ?? d.wire;
    // 拒绝用实心警示，其余用描边 —— 用 switch 而非三元，加档位时不会漏。
    return switch (d) {
      ApprovalDecision.decline => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () => onDecide(d),
          child: Text(label),
        ),
      ApprovalDecision.accept ||
      ApprovalDecision.acceptForSession =>
        OutlinedButton(
          style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact),
          onPressed: () => onDecide(d),
          child: Text(label),
        ),
    };
  }
}
