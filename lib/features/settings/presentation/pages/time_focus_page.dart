import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_section.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 设置弹窗里的 Time and focus 页面:休息提醒的时间范围下拉 + 静默时段的按星期切换。
class TimeFocusPage extends StatefulWidget {
  const TimeFocusPage({super.key});

  @override
  State<TimeFocusPage> createState() => _TimeFocusPageState();
}

class _TimeFocusPageState extends State<TimeFocusPage> {
  final Set<int> _quietDays = {};

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);

    final weekdayLabels = [
      l10n.commonSunday,
      l10n.commonMonday,
      l10n.commonTuesday,
      l10n.commonWednesday,
      l10n.commonThursday,
      l10n.commonFriday,
      l10n.commonSaturday,
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        SettingsSectionHeader(l10n.timeFocusTitle),
        const SizedBox(height: AppSpacing.sm),
        SettingsSectionRowWithDesc(
          title: l10n.timeFocusBreakReminders,
          description: l10n.timeFocusBreakRemindersDesc,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PlaceholderDropdown(skin: skin),
              const SizedBox(width: AppSpacing.xs),
              _PlaceholderDropdown(skin: skin),
            ],
          ),
        ),
        const SettingsSectionDivider(),
        SettingsSectionRowWithDesc(
          title: l10n.timeFocusQuietHours,
          description: l10n.timeFocusQuietHoursDesc,
          trailing: Wrap(
            spacing: AppSpacing.xs,
            children: List.generate(7, (index) {
              final selected = _quietDays.contains(index);
              return _DayToggle(
                label: weekdayLabels[index],
                selected: selected,
                skin: skin,
                onTap: () => setState(() {
                  if (selected) {
                    _quietDays.remove(index);
                  } else {
                    _quietDays.add(index);
                  }
                }),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _PlaceholderDropdown extends StatelessWidget {
  const _PlaceholderDropdown({required this.skin});

  final AppSkin skin;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text('-', style: TextStyle(fontSize: 14, color: skin.text)),
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.keyboard_arrow_down, size: 18, color: skin.textSecondary),
        ],
      ),
    );
  }
}

class _DayToggle extends StatelessWidget {
  const _DayToggle({
    required this.label,
    required this.selected,
    required this.skin,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AppSkin skin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? skin.text : skin.containerBgSecondary,
          shape: BoxShape.circle,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? skin.containerBg : skin.textSecondary,
          ),
        ),
      ),
    );
  }
}
