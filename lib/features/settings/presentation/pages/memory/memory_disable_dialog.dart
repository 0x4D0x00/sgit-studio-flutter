import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 关掉记忆时用户选的处置方式。
enum MemoryDisableChoice {
  /// 保留已有记忆，只是不用也不再生成。
  pause,

  /// 连同已有记忆一起删掉（不可撤销）。
  reset,
}

/// 「关闭记忆」确认框：暂停 / 重置二选一。
///
/// 返回用户的选择；点取消或点掉遮罩返回 null，调用方据此什么都不做。
///
/// 按钮的**文案和配色跟着选项走**：选「暂停」是中性确认，选「重置」才变成警示红
Future<MemoryDisableChoice?> showMemoryDisableDialog(BuildContext context) {
  return showDialog<MemoryDisableChoice>(
    context: context,
    builder: (_) => const MemoryDisableDialog(),
  );
}

/// 关记忆的统一入口（设置页与输入框 `+` 菜单共用）：先弹确认框，确认后再落盘。
Future<void> requestDisableMemory(BuildContext context, WidgetRef ref) async {
  // 弹窗关掉后调用方可能已不在树上，先把 messenger 与 l10n 抓在手里 ——
  // 跨过 await 再去问 context 是不安全的。
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final choice = await showMemoryDisableDialog(context);
  if (choice == null) return;
  await ref.read(composerSettingsProvider.notifier).setMemoryEnabled(false);
  if (choice == MemoryDisableChoice.reset) {
    // 引擎侧没有「清空记忆」的入口（本 fork 的 memories 扩展返回空列表）
    // TODO: 记忆清空待接通
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.commonNotWired(l10n.memoryResetMemory)),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

class MemoryDisableDialog extends StatefulWidget {
  const MemoryDisableDialog({super.key});

  @override
  State<MemoryDisableDialog> createState() => _MemoryDisableDialogState();
}

class _MemoryDisableDialogState extends State<MemoryDisableDialog> {
  MemoryDisableChoice _selected = MemoryDisableChoice.pause;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isReset = _selected == MemoryDisableChoice.reset;

    return Dialog(
      backgroundColor: skin.containerBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: skin.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.memoryDisableTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: skin.text,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: skin.textSecondary,
                    ),
                    tooltip: l10n.commonClose,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              // 两个选项同处一块浅底卡片里，用分组把「这是一道单选题」
              // 和上方标题分开。
              Container(
                decoration: BoxDecoration(
                  color: skin.text.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: [
                    MemoryChoiceTile(
                      label: l10n.memoryPauseMemory,
                      description: l10n.memoryPauseMemoryDesc,
                      selected: _selected == MemoryDisableChoice.pause,
                      onTap: () =>
                          setState(() => _selected = MemoryDisableChoice.pause),
                    ),
                    MemoryChoiceTile(
                      label: l10n.memoryResetMemory,
                      description: l10n.memoryResetMemoryDesc,
                      selected: _selected == MemoryDisableChoice.reset,
                      onTap: () =>
                          setState(() => _selected = MemoryDisableChoice.reset),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  FilledButton(
                    style: isReset
                        ? FilledButton.styleFrom(
                            backgroundColor: theme.colorScheme.error,
                            foregroundColor: theme.colorScheme.onError,
                          )
                        : null,
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text(
                      isReset ? l10n.memoryResetMemory : l10n.memoryPauseMemory,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 确认框里的一个单选项：圆形单选标记 + 标题 + 说明。
///
/// 没用 `RadioListTile`：它自带内边距、水波纹和主题里的选中色，要压成
/// 设计稿的样子得逐项覆盖。这里的标记很小一块，手写反而更短更可控。
class MemoryChoiceTile extends StatelessWidget {
  const MemoryChoiceTile({
    super.key,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: MemoryRadioMark(selected: selected),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 14, color: skin.text)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: skin.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单选标记：选中时实心圆 + 白点，未选中时只有一圈描边。
class MemoryRadioMark extends StatelessWidget {
  const MemoryRadioMark({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final theme = Theme.of(context);

    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? theme.colorScheme.primary : Colors.transparent,
        border: selected
            ? null
            : Border.all(color: skin.textTertiary, width: 1.5),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            )
          : null,
    );
  }
}
