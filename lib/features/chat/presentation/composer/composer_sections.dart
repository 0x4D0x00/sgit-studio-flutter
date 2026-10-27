import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/design/tokens/composer_metrics.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/composer/composer_menus.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_quotes_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/model_list_controller.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/model_selector.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_attachment_chip.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_control_bar.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_quote_card.dart';
import 'package:sgit_studio_flutter/ui/components/dialogs/quote_dialog.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_token_tag.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';
import 'package:sgit_studio_flutter/services/chat/workspace_mode.dart';

/// 输入框下方的创作模式标签：模式名，Slides / Design 另带「设计系统」。
/// 由输出产物页的入口设置，普通对话模式下不显示。
class ComposerModeChips extends ConsumerWidget {
  const ComposerModeChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final mode = ref.watch(workspaceModeProvider);
    if (mode == WorkspaceMode.chat) return const SizedBox.shrink();
    final skin = AppSkin.of(context);
    final (label, removeLabel, color) = switch (mode) {
      WorkspaceMode.docs => (
        l10n.workspaceModeDocs,
        l10n.workspaceModeRemoveDocs,
        const Color(0xFF3B82F6),
      ),
      WorkspaceMode.slides => (
        l10n.workspaceModeSlides,
        l10n.workspaceModeRemoveSlides,
        const Color(0xFFE08A3C),
      ),
      _ => (
        l10n.workspaceModeDesign,
        l10n.workspaceModeRemoveDesign,
        const Color(0xFF8B5CF6),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          // 点标签弹出「移除」，移除后标签与「设计系统」一起消失。
          AppMenuAnchor(
            align: AppMenuAlign.under,
            trigger: AppMenuTrigger.tap,
            semanticLabel: label,
            entries: [
              AppMenuAction(
                icon: Icons.close,
                label: removeLabel,
                onTap: () => ref
                    .read(workspaceModeProvider.notifier)
                    .set(WorkspaceMode.chat),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text(label, style: TextStyle(fontSize: 12, color: color)),
            ),
          ),
          if (mode != WorkspaceMode.docs) ...[
            const SizedBox(width: AppSpacing.xs),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    l10n.commonNotWired(l10n.workspaceDesignSystem),
                  ),
                  duration: const Duration(seconds: 1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxs,
                  vertical: AppSpacing.xxs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.palette_outlined,
                      size: 14,
                      color: skin.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      l10n.workspaceDesignSystem,
                      style: TextStyle(fontSize: 12, color: skin.text),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 输入框**上方**的那行小字。
///
/// studio 没有这一行（它把用量塞进 token 标签的悬浮卡里），但我们保留 ——
/// 它显示的是**上一轮的成本与延迟**，和控制条上那个"上下文还剩多少"是两回事，
/// 后者替代不了前者。位置也维持原样，免得老用户找不到。
///
/// 数字全部是内核算好的，我们只显示，不重算。
class ComposerStatsLine extends ConsumerWidget {
  const ComposerStatsLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final usage = ref.watch(chatControllerProvider.select((s) => s.lastUsage));
    final timing = ref.watch(
      chatControllerProvider.select((s) => s.lastTiming),
    );
    if (usage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Text(
        l10n.chatStats(
          usage.inputTokens,
          usage.outputTokens,
          timing?.durationMs ?? 0,
        ),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: skin.textTertiary),
      ),
    );
  }
}

/// 输入框头部：引用卡 + 附件。
class ComposerAttachmentArea extends ConsumerWidget {
  const ComposerAttachmentArea({
    super.key,
    required this.quotes,
    required this.attachments,
    required this.onRemoveAttachment,
  });

  final List<String> quotes;
  final List<PlatformFile> attachments;
  final void Function(int index) onRemoveAttachment;

  static const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'};

  static bool _isImage(PlatformFile f) =>
      _imageExts.contains(f.extension?.toLowerCase());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(
        left: ComposerMetrics.attachmentAreaPaddingInline,
        right: ComposerMetrics.attachmentAreaPaddingInline,
        bottom: AppSpacing.xs,
      ),
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final (index, text) in quotes.indexed)
            ComposerQuoteCard(
              text: text,
              removeSemanticLabel: l10n.chatRemoveQuote,
              onTap: () => showQuoteDialog(context, text),
              onRemove: () =>
                  ref.read(composerQuotesProvider.notifier).removeAt(index),
            ),
          for (final (index, file) in attachments.indexed)
            ComposerAttachmentChip(
              name: file.name,
              isImage: _isImage(file),
              removeSemanticLabel: l10n.chatRemoveAttachment,
              onRemove: () => onRemoveAttachment(index),
            ),
        ],
      ),
    );
  }
}

/// 会话态底部的控制条（沙箱 / 推理强度 / 上下文窗口占用）。
class ComposerControlSection extends ConsumerWidget {
  const ComposerControlSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.watch(
      composerSettingsProvider.select((s) => s.settings),
    );
    final usage = ref.watch(chatControllerProvider.select((s) => s.lastUsage));
    final models = ref.watch(modelListProvider);

    final used = usage?.totalTokens ?? 0;
    // ⚠️ 用 effective 而不是 find：没选过模型时 find 返回 null → maxTokens 为 0
    // → `ComposerTokenTag.shouldShow` 恒为 false → **上下文窗口条永远不出现**。
    // 引擎实际用的是列表第一个，窗口大小也该按它算。
    final maxTokens =
        models.effective(settings.selectedModel)?.contextWindow ?? 0;

    return ComposerControlBar(
      leading: [
        ComposerSandboxMenu(current: settings.sandboxMode),
        ComposerEffortMenu(current: settings.reasoningEffort),
      ],
      trailing: [
        // 占用不到一半时整个不画 —— 还剩一大半的时候这个数字没有决策价值，
        // 常驻只会让人焦虑（studio 同款判断）。
        if (ComposerTokenTag.shouldShow(used: used, max: maxTokens))
          ComposerTokenTag(
            used: used,
            max: maxTokens,
            tooltip: l10n.chatContextWindowDetail(used, maxTokens),
          ),
      ],
    );
  }
}

/// 底部行（会话态）：控制条 + 模型选择器。
class ComposerBottomRow extends ConsumerWidget {
  const ComposerBottomRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(
      composerSettingsProvider.select((s) => s.settings),
    );

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(child: ComposerControlSection()),
          const SizedBox(width: AppSpacing.xs),
          ModelSelector(
            selected: settings.selectedModel,
            onChanged: (m) =>
                ref.read(composerSettingsProvider.notifier).setSelectedModel(m),
          ),
        ],
      ),
    );
  }
}
