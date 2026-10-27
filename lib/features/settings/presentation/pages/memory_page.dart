import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_section.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/memory/memory_disable_dialog.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/memory/memory_notes.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/memory/memory_widgets.dart';

export 'package:sgit_studio_flutter/features/settings/presentation/pages/memory/memory_disable_dialog.dart';

/// 设置弹窗里的 Memory 页面。------两个形态
/// 这一页不是「一堆开关」的平铺，而是**开/关对应两套完全不同的内容**：
///
/// - **关**：只有「从对话中生成记忆」一行。功能没开，其余开关和记忆列表
///   都没有意义 —— 摆在那里只会让人以为已经生效。
/// - **开**：多出「敏感话题」「从其他 AI 导入」两行，以及记忆列表与输入框。
///
/// 所以形态由 [ComposerSettings.memoryEnabled] 推导，**不是一个独立的
/// `_expanded` 字段** —— 否则两个状态会各自漂移，出现「开关是关的但列表还在」。
///
/// ## 开关的控制权
///
/// 开关读写的仍是输入框 `+` 菜单里那个记忆开关（`config.toml` 的
/// `memories.use_memories`，见 [ComposerSettings.memoryEnabledKey]）——
/// 同一份配置，两处入口不能各写各的。
/// 关闭不是直接的：先弹确认框问「暂停」还是「重置」
class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key});

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage> {
  /// 「在记忆中包含敏感话题」。
  ///
  /// ⚠️ **只有界面态，还没落盘** —— `config.toml` 里没有对应的键，
  /// 引擎侧的 `MemoriesTool` 也不读它。接线前保持局部状态，
  /// 至少不让开关看起来是死的。
  bool _sensitiveTopics = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final skin = AppSkin.of(context);

    // 引擎设置写失败要让用户知道 —— 这里和输入框那边一样，静默失败的开关
    ref.listen(composerSettingsProvider.select((s) => s.error), (_, err) {
      if (err == null || !mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.chatSettingWriteFailed(err))));
      ref.read(composerSettingsProvider.notifier).clearError();
    });

    final enabled = ref.watch(
      composerSettingsProvider.select((s) => s.settings.memoryEnabled),
    );

    Future<void> setEnabled(bool value) =>
        ref.read(composerSettingsProvider.notifier).setMemoryEnabled(value);

    /// 关开关：先问「暂停」还是「重置」，确认后再落盘。
    Future<void> requestDisable() async {
      // 弹窗关掉后本组件可能已经不在树上，先把 messenger 抓在手里 ——
      // 跨过 await 再去问 context 是不安全的。
      final messenger = ScaffoldMessenger.of(context);
      final choice = await showMemoryDisableDialog(context);
      if (choice == null) return;
      await setEnabled(false);
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

    return enabled
        ? _enabledView(l10n, theme, skin, onDisable: requestDisable)
        : _disabledView(l10n, theme, onEnable: () => setEnabled(true));
  }

  /// 记忆未开启：只有一行开关。
  Widget _disabledView(
    AppLocalizations l10n,
    ThemeData theme, {
    required VoidCallback onEnable,
  }) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        SettingsSectionHeader(l10n.memoryTitle),
        const SizedBox(height: AppSpacing.md),
        SettingsSectionRowWithDesc(
          title: l10n.memoryGenerateFromChats,
          descriptionWidget: LearnMoreParagraph.build(
            theme,
            (placeholder) => l10n.memoryGenerateFromChatsDesc(placeholder),
            l10n.memoryLearnMore,
            () => _notWired(l10n.memoryLearnMore),
          ),
          trailing: Switch(
            value: false,
            onChanged: (value) {
              if (value) onEnable();
            },
          ),
        ),
      ],
    );
  }

  /// 记忆已开启：三行设置 + 记忆列表 + 输入框。
  Widget _enabledView(
    AppLocalizations l10n,
    ThemeData theme,
    AppSkin skin, {
    required Future<void> Function() onDisable,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: MemoryTitle(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              SettingsSectionRowWithDesc(
                title: l10n.memoryGenerateFromChats,
                descriptionWidget: LearnMoreParagraph.build(
                  theme,
                  (placeholder) =>
                      l10n.memoryGenerateFromChatsDesc(placeholder),
                  l10n.memoryLearnMore,
                  () => _notWired(l10n.memoryLearnMore),
                ),
                trailing: Switch(
                  value: true,
                  onChanged: (value) {
                    if (!value) onDisable();
                  },
                ),
              ),
              const SettingsSectionDivider(),
              SettingsSectionRowWithDesc(
                title: l10n.memorySensitiveTopics,
                descriptionWidget: LearnMoreParagraph.build(
                  theme,
                  (placeholder) => l10n.memorySensitiveTopicsDesc(placeholder),
                  l10n.memoryLearnMore,
                  () => _notWired(l10n.memoryLearnMore),
                ),
                trailing: Switch(
                  value: _sensitiveTopics,
                  onChanged: (value) =>
                      setState(() => _sensitiveTopics = value),
                ),
              ),
              const SettingsSectionDivider(),
              SettingsSectionRowWithDesc(
                title: l10n.memoryImportFromOtherAi,
                descriptionWidget: LearnMoreParagraph.build(
                  theme,
                  (placeholder) =>
                      l10n.memoryImportFromOtherAiDesc(placeholder),
                  l10n.memoryLearnMore,
                  () => _notWired(l10n.memoryLearnMore),
                ),
                trailing: MemoryOutlineActionButton(
                  label: l10n.memoryStartImport,
                  onPressed: () => _notWired(l10n.memoryStartImport),
                ),
              ),
            ],
          ),
        ),
        // 记忆列表：`.sgitai/memories/**/*.md` 的用户笔记。
        //
        // 走的是 studio 那份 `StudioPageSpecs.memory` —— 与原先左栏「智能体 →
        // 记忆」同一个数据源（Rust 侧 `sgit_studio_read("memory")` 本地直读，
        // 引擎管线文件已在那里滤掉）。入口从智能体挪到这里，数据契约没变。
        const Expanded(child: MemoryNoteList()),
        MemoryInputBar(onSubmit: () => _notWired(l10n.memoryTitle)),
      ],
    );
  }

  void _notWired(String what) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.commonNotWired(what)),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
