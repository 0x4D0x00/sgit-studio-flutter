import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_section.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatSettingWriteFailed(err))),
      );
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
          descriptionWidget: _LearnMoreParagraph.build(
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
          child: _MemoryTitle(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            children: [
              SettingsSectionRowWithDesc(
                title: l10n.memoryGenerateFromChats,
                descriptionWidget: _LearnMoreParagraph.build(
                  theme,
                  (placeholder) => l10n.memoryGenerateFromChatsDesc(placeholder),
                  l10n.memoryLearnMore,
                  () => _notWired(l10n.memoryLearnMore),
                ),
                trailing: Switch(value: true, onChanged: (value) {
                  if (!value) onDisable();
                }),
              ),
              const SettingsSectionDivider(),
              SettingsSectionRowWithDesc(
                title: l10n.memorySensitiveTopics,
                descriptionWidget: _LearnMoreParagraph.build(
                  theme,
                  (placeholder) => l10n.memorySensitiveTopicsDesc(placeholder),
                  l10n.memoryLearnMore,
                  () => _notWired(l10n.memoryLearnMore),
                ),
                trailing: Switch(
                  value: _sensitiveTopics,
                  onChanged: (value) => setState(() => _sensitiveTopics = value),
                ),
              ),
              const SettingsSectionDivider(),
              SettingsSectionRowWithDesc(
                title: l10n.memoryImportFromOtherAi,
                descriptionWidget: _LearnMoreParagraph.build(
                  theme,
                  (placeholder) =>
                      l10n.memoryImportFromOtherAiDesc(placeholder),
                  l10n.memoryLearnMore,
                  () => _notWired(l10n.memoryLearnMore),
                ),
                trailing: _OutlineActionButton(
                  label: l10n.memoryStartImport,
                  onPressed: () => _notWired(l10n.memoryStartImport),
                ),
              ),
            ],
          ),
        ),
        // 记忆列表。引擎侧没有列记忆文件的入口，恒为空态。
        Expanded(
          child: Center(
            child: Text(
              l10n.memoryNoFiles,
              style: theme.textTheme.bodyMedium?.copyWith(color: skin.textSecondary),
            ),
          ),
        ),
        _MemoryInputBar(onSubmit: () => _notWired(l10n.memoryTitle)),
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

/// 页头标题。抽出来是因为已开启形态下它要参与外层 [Column] 的布局，
/// 不能像未开启形态那样直接塞进 `ListView` 里。
class _MemoryTitle extends StatelessWidget {
  const _MemoryTitle();

  @override
  Widget build(BuildContext context) =>
      SettingsSectionHeader(AppLocalizations.of(context).memoryTitle);
}

/// 一段带行内「了解更多」链接的说明文字。按占位符拆分才能在换语言后
/// 让链接仍落在正确的位置上。
///
/// 拆分用不可见哨兵字符 `\u0000`，因为它不会出现在自然语言里。
///
/// 链接用 [WidgetSpan] + `InkWell` 而不是 `TextSpan.recognizer`：
/// recognizer 是**有状态对象**，每次 build 新建一个就得自己负责 dispose，
/// 漏掉就是一条泄漏；`WidgetSpan` 里的组件由框架管生命周期，不用管。
class _LearnMoreParagraph {
  _LearnMoreParagraph._();

  static const String _sentinel = '\u0000';

  static Widget build(
    ThemeData theme,
    String Function(String placeholder) template,
    String linkText,
    VoidCallback onTap,
  ) {
    final base = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final raw = template(_sentinel);
    final at = raw.indexOf(_sentinel);

    if (at < 0) return Text(raw, style: base);

    return RichText(
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: raw.substring(0, at)),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: InkWell(
              onTap: onTap,
              child: Text(
                linkText,
                style: base?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          TextSpan(text: raw.substring(at + _sentinel.length)),
        ],
      ),
    );
  }
}

/// 右侧带描边的动作按钮（「开始导入」）。
class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Text(label),
    );
  }
}

/// 记忆输入框：底部常驻，把一句话交给 Claude 记下来。
class _MemoryInputBar extends StatefulWidget {
  const _MemoryInputBar({required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  State<_MemoryInputBar> createState() => _MemoryInputBarState();
}

class _MemoryInputBarState extends State<_MemoryInputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child:Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                style: TextStyle(fontSize: 14, color: skin.text),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  filled: false,
                  hintText: l10n.memoryInputHint,
                  hintStyle: TextStyle(fontSize: 14, color: skin.textTertiary),
                  suffixIcon: _SendButton(onPressed: _submit,),
                ),
              ),
            ),
          ],
        //),
      ),
    );
  }
}

/// 圆形上箭头发送键。
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return SizedBox(
      width: 26,
      height: 26,
      child: Material(
        color: skin.text.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Icon(Icons.arrow_upward, size: 18, color: skin.text),
        ),
      ),
    );
  }
}

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
    builder: (_) => const _MemoryDisableDialog(),
  );
}

class _MemoryDisableDialog extends StatefulWidget {
  const _MemoryDisableDialog();

  @override
  State<_MemoryDisableDialog> createState() => _MemoryDisableDialogState();
}

class _MemoryDisableDialogState extends State<_MemoryDisableDialog> {
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
                    icon: Icon(Icons.close, size: 20, color: skin.textSecondary),
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
                    _ChoiceTile(
                      label: l10n.memoryPauseMemory,
                      description: l10n.memoryPauseMemoryDesc,
                      selected: _selected == MemoryDisableChoice.pause,
                      onTap: () => setState(
                        () => _selected = MemoryDisableChoice.pause,
                      ),
                    ),
                    _ChoiceTile(
                      label: l10n.memoryResetMemory,
                      description: l10n.memoryResetMemoryDesc,
                      selected: _selected == MemoryDisableChoice.reset,
                      onTap: () => setState(
                        () => _selected = MemoryDisableChoice.reset,
                      ),
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
                      isReset
                          ? l10n.memoryResetMemory
                          : l10n.memoryPauseMemory,
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
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
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
              child: _RadioMark(selected: selected),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 14, color: skin.text),
                  ),
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
class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

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
