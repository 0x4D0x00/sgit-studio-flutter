import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/chat/application/model_list_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 输入框上的模型选择器。
///
/// 数据源与「大模型中转站」页**同一份**（relay 三表），取法与 React studio 的
/// `useEnabledChatModels` 一致 —— 见 [ModelListController] 的说明。
///
/// 按厂商分组显示；个人直连的模型单独成组并标注。
class ModelSelector extends ConsumerWidget {
  const ModelSelector({super.key, required this.onChanged, this.selected});

  final ValueChanged<String?> onChanged;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(modelListProvider);

    // ⚠️ 加载中/没模型时**也要显示**，只是禁用 —— 早期版本在这里 `SizedBox.shrink()`，
    // 结果取不到模型时控件整个消失，用户以为功能没做。宁可显示一个灰的。
    final current = s.find(selected);
    final enabled = !s.isEmpty;

    return PopupMenuButton<String?>(
      enabled: enabled,
      tooltip: l10n.modelSelector,
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(maxHeight: 420, minWidth: 240),
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem<String?>(
          value: null,
          height: 36,
          child: Text(l10n.modelSelectorDefault,
              style: TextStyle(fontSize: 13, color: skin.textTertiary)),
        ),
        for (final g in s.groups) ...[
          PopupMenuItem<String?>(
            enabled: false,
            height: 28,
            child: Text(
              g.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: skin.textTertiary,
              ),
            ),
          ),
          for (final m in g.models)
            PopupMenuItem<String?>(
              value: m.id,
              height: 36,
              child: Row(
                children: [
                  Expanded(
                    child: Text(m.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: skin.text)),
                  ),
                  if (m.contextWindow != null)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xs),
                      child: Text(l10n.relayContextWindow(m.contextWindow!),
                          style: TextStyle(
                              fontSize: 10, color: skin.textTertiary)),
                    ),
                  if (m.id == selected)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.xxs),
                      child: Icon(Icons.check_rounded,
                          size: 14, color: skin.accentChip),
                    ),
                ],
              ),
            ),
        ],
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: skin.borderSecondary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (s.loading)
              SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: skin.textTertiary),
              )
            else
              Icon(Icons.auto_awesome_outlined,
                  size: 13, color: skin.textTertiary),
            const SizedBox(width: AppSpacing.xxs),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                switch ((s.loading, enabled, current)) {
                  (true, _, _) => l10n.commonLoading,
                  (_, false, _) => l10n.modelSelectorNone,
                  (_, _, final m?) => m.displayName,
                  _ => l10n.modelSelectorDefault,
                },
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: skin.textSecondary),
              ),
            ),
            Icon(Icons.expand_more_rounded,
                size: 14,
                color: enabled ? skin.textTertiary : skin.borderSecondary),
          ],
        ),
      ),
    );
  }
}
