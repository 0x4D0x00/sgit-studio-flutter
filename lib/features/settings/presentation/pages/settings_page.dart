import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/services/theme/theme_controller.dart';
// import 'package:sgit_studio_flutter/features/auth/application/auth_controller.dart';
import 'package:sgit_studio_flutter/ui/components/glass_card.dart';

/// 设置页(基础设施演示)。主题模式 / 主色 / 次色 / 字号缩放 / 语言，全部实时 + 持久化。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ts = ref.watch(themeControllerProvider);
    final tc = ref.read(themeControllerProvider.notifier);

    // 主题模式面板
    final modeSection = _section(theme, l10n.settingsThemeMode, SegmentedButton<AppThemeMode>(
      segments: [
        ButtonSegment(value: AppThemeMode.transparent, label: Text(l10n.settingsThemeTransparent)),
        ButtonSegment(value: AppThemeMode.light, label: Text(l10n.settingsThemeLight)),
        ButtonSegment(value: AppThemeMode.dark, label: Text(l10n.settingsThemeDark)),
        ButtonSegment(value: AppThemeMode.system, label: Text(l10n.settingsThemeSystem)),
      ],
      selected: {ts.mode},
      onSelectionChanged: (s) => tc.setMode(s.first),
      showSelectedIcon: false,
    ));

    // 主题色面板
    final primarySection = _section(theme, l10n.settingsPrimaryColor, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dots(AppColors.primarySwatches, ts.primary, tc.setPrimary),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: tc.resetPrimary,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text(l10n.settingsResetDefault),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
        ),
      ],
    ));

    // 次主题色面板
    final secondarySection = _section(theme, l10n.settingsSecondaryColor, Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dots(AppColors.secondarySwatches, ts.secondary, tc.setSecondary),
        const SizedBox(height: AppSpacing.sm),
        TextButton.icon(
          onPressed: tc.resetSecondary,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text(l10n.settingsResetDefault),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
        ),
      ],
    ));

    // 字体缩放面板（占满整行）
    final fontSection = _section(theme, l10n.settingsFontScale, Row(
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
    ));

    return ListView(
      children: [
        Text(l10n.settingsTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.lg),

        // 第一行：主题模式（整行，语言已挪到侧栏用户菜单）
        modeSection,

        // 第二行：主题色 | 次主题色
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: primarySection),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: secondarySection),
            ],
          ),
        ),

        // 第三行：字体缩放（整行）
        fontSection,

        // 退出登录
        // _section(theme, l10n.navLogout, Align(
        //   alignment: Alignment.centerLeft,
        //   child: FilledButton.icon(
        //     style: FilledButton.styleFrom(
        //       backgroundColor: theme.colorScheme.error,
        //       foregroundColor: Colors.white,
        //     ),
        //     icon: const Icon(Icons.logout_rounded, size: 18),
        //     label: Text(l10n.navLogout),
        //     onPressed: () => ref.read(authControllerProvider.notifier).logout(),
        //   ),
        // )),
      ],
    );
  }

  Widget _section(ThemeData theme, String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: GlassCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
        ),
      );

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
