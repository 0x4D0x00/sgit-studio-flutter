import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/services/theme/theme_controller.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_section.dart';

/// 设置页(基础设施演示)。主题模式 / 主色 / 次色 / 字号缩放 / 语言，全部实时 + 持久化。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // Local UI-only state for new settings (not persisted)
  String _chatFont = 'Anthropic Serif';
  String _motionMode = 'System';
  String _voiceLanguage = 'English';
  String _voiceStyle = 'Buttery';
  String _voiceSpeed = 'Normal';
  bool _notificationsEnabled = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final skin = AppSkin.of(context);
    final ts = ref.watch(themeControllerProvider);
    final tc = ref.read(themeControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [

        // ============ Appearance Section ============
        SettingsSectionHeader(l10n.settingsAppearance),
        const SizedBox(height: AppSpacing.sm),

        // Theme mode
        SettingsSectionRow(
          title: l10n.settingsTheme,
          trailing: Align(
            alignment: Alignment.centerRight,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ThemeModeButton(
                    icon: Icons.desktop_windows_outlined,
                    selected: ts.mode == AppThemeMode.system,
                    onTap: () => tc.setMode(AppThemeMode.system),
                  ),
                  _ThemeModeButton(
                    icon: Icons.wb_sunny_outlined,
                    selected: ts.mode == AppThemeMode.light,
                    onTap: () => tc.setMode(AppThemeMode.light),
                  ),
                  _ThemeModeButton(
                    icon: Icons.dark_mode_outlined,
                    selected: ts.mode == AppThemeMode.dark,
                    onTap: () => tc.setMode(AppThemeMode.dark),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SettingsSectionDivider(),

        // Chat font dropdown
        SettingsSectionRow(
          title: l10n.settingsChatFont,
          trailing: _DropdownRow(
            value: _chatFont,
            skin: skin,
            options: [
              (l10n.settingsFontAnthropic, 'Anthropic Serif'),
              (l10n.settingsFontSystem, 'System font'),
            ],
            onChanged: (v) => setState(() => _chatFont = v),
          ),
        ),
        const SettingsSectionDivider(),

        // Primary color
        SettingsSectionRow(
          title: l10n.settingsPrimaryColor,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _dots(AppColors.primarySwatches, ts.primary, tc.setPrimary),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed: tc.resetPrimary,
                icon: const Icon(Icons.refresh_rounded, size: 12),
                label: Text(l10n.settingsResetDefault),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ],
          ),
        ),
        const SettingsSectionDivider(),

        // Secondary color
        SettingsSectionRow(
          title: l10n.settingsSecondaryColor,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _dots(AppColors.secondarySwatches, ts.secondary, tc.setSecondary),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed: tc.resetSecondary,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: Text(l10n.settingsResetDefault),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ],
          ),
        ),
        const SettingsSectionDivider(),

        // Font scale
        SettingsSectionRow(
          title: l10n.settingsFontScale,
          trailing: Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Slider(
                    min: ThemeController.minFontScale,
                    max: ThemeController.maxFontScale,
                    divisions: 8,
                    value: ts.fontScale,
                    label: '${(ts.fontScale * 100).round()}%',
                    onChanged: tc.setFontScale,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('${(ts.fontScale * 100).round()}%', style: theme.textTheme.labelLarge),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ============ Motion Section ============
        SettingsSectionHeader(l10n.settingsMotion),
        const SizedBox(height: AppSpacing.sm),

        SettingsSectionRowWithDesc(
          title: l10n.settingsMotion,
          description: l10n.settingsMotionDesc,
          trailing: _SegmentedToggle(
            options: [l10n.settingsMotionSystem, l10n.settingsMotionReduced],
            selected: _motionMode,
            onChanged: (v) => setState(() => _motionMode = v),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ============ Voice Section ============
        SettingsSectionHeader(l10n.settingsVoice),
        const SizedBox(height: AppSpacing.sm),

        SettingsSectionRow(
          title: l10n.settingsVoiceLanguage,
          trailing: _DropdownRow(
            value: _voiceLanguage,
            skin: skin,
            options: [
              (l10n.settingsVoiceEnglish, 'English'),
              (l10n.settingsVoiceChinese, '中文'),
            ],
            onChanged: (v) => setState(() => _voiceLanguage = v),
          ),
        ),
        const SettingsSectionDivider(),

        SettingsSectionRow(
          title: l10n.settingsVoiceStyle,
          trailing: _DropdownRow(
            value: _voiceStyle,
            skin: skin,
            options: [
              (l10n.settingsVoiceStyleButtery, 'Buttery'),
              (l10n.settingsVoiceStyleNormal, 'Normal'),
            ],
            onChanged: (v) => setState(() => _voiceStyle = v),
          ),
        ),
        const SettingsSectionDivider(),

        SettingsSectionRow(
          title: l10n.settingsVoiceSpeed,
          trailing: _DropdownRow(
            value: _voiceSpeed,
            skin: skin,
            options: [
              (l10n.settingsVoiceSpeedNormal, 'Normal'),
              (l10n.settingsVoiceSpeedFast, 'Fast'),
            ],
            onChanged: (v) => setState(() => _voiceSpeed = v),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ============ Notifications Section ============
        SettingsSectionHeader(l10n.settingsNotifications),
        const SizedBox(height: AppSpacing.sm),

        SettingsSectionRowWithDesc(
          title: l10n.settingsNotifResponseComplete,
          description: l10n.settingsNotifResponseCompleteDesc,
          trailing: Switch(
            value: _notificationsEnabled,
            onChanged: (v) => setState(() => _notificationsEnabled = v),
          ),
        ),
      ],
    );
  }

  Widget _dots(List<Color> colors, Color selected, void Function(Color) onTap) => Wrap(
        spacing: AppSpacing.sm,
        children: [
          for (final c in colors)
            _ColorDot(color: c, selected: selected.toARGB32() == c.toARGB32(), onTap: () => onTap(c)),
        ],
      );
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12)],
            border: selected
                ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 2)
                : null,
          ),
          child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
        ),
      );
}

class _ThemeModeButton extends StatelessWidget {
  const _ThemeModeButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skin = AppSkin.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: selected ? skin.text.withValues(alpha: 0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(
          icon,
          size: 20,
          color: selected ? skin.text : theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.value,
    required this.skin,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final AppSkin skin;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AppMenuAnchor(
      entries: [
        AppMenuRadioGroup(
          values: options.map((o) => o.$2).toList(),
          selected: value,
          labelOf: (v) => options.firstWhere((o) => o.$2 == v).$1,
          onSelect: onChanged,
        ),
      ],
      align: AppMenuAlign.underEnd,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: skin.border),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              options.firstWhere((o) => o.$2 == value).$1,
              style: TextStyle(
                fontSize: 14,
                color: skin.text,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: skin.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skin = AppSkin.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            InkWell(
              onTap: () => onChanged(option),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: selected == option
                      ? skin.text.withValues(alpha: 0.06)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected == option ? FontWeight.w500 : FontWeight.normal,
                    color: selected == option ? skin.text : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
