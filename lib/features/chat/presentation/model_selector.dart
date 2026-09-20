import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/chat/application/model_list_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

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
    //
    // ⚠️ 用 effective 而不是 find：没选过时显示**列表第一个**（引擎实际会用的那个），
    // 不是「默认模型」四个字 —— 用户想知道的是"现在这条消息由谁回答"。
    final current = s.effective(selected);
    final enabled = !s.isEmpty;

    return AppMenuAnchor(
      enabled: enabled,
      semanticLabel: l10n.modelSelector,
      minWidth: 260,
      maxWidth: 340,
      maxHeight: 420,
      entries: [
        // 右侧标出它实际解析成谁 —— 否则触发器显示 "GLM-4" 而菜单勾着"默认模型"，
        // 看起来像两个不同的选择。
        AppMenuAction(
          label: l10n.modelSelectorDefault,
          trailingValue: s.first?.displayName,
          checked: selected == null,
          onTap: () => onChanged(null),
        ),
        for (final g in s.groups) ...[
          AppMenuLabel(g.name),
          for (final m in g.models)
            AppMenuAction(
              label: m.displayName,
              // 上下文窗口挂在右侧那一格：它是这一项的属性，不是快捷键，
              // 但视觉位置与快捷键同列，所以复用 trailingValue。
              trailingValue: m.contextWindow == null
                  ? null
                  : l10n.relayContextWindow(m.contextWindow!),
              checked: m.id == selected,
              onTap: () => onChanged(m.id),
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
