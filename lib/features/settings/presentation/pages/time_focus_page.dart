import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_section.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 静默时段的起止时间，以从 0 点开始的半小时格数表示（0..47，即 12:00am..11:30pm）。
class _QuietRange {
  _QuietRange({required this.startSlot, required this.endSlot});

  int startSlot;
  int endSlot;

  /// 结束格数不晚于起始格数时，说明跨到了次日。
  bool get isOvernight => endSlot <= startSlot;
}

/// 设置弹窗里的 Time and focus 页面:休息提醒的时间范围下拉 + 静默时段的按星期切换。
class TimeFocusPage extends StatefulWidget {
  const TimeFocusPage({super.key});

  @override
  State<TimeFocusPage> createState() => _TimeFocusPageState();
}

class _TimeFocusPageState extends State<TimeFocusPage> {
  final Set<int> _quietDays = {};

  /// 每个已勾选星期的静默时段，key 为星期序号(0=周日..6=周六)。
  final Map<int, _QuietRange> _quietRanges = {};

  /// 每隔几小时提醒一次，`null` 表示未设置（显示为 "-"）。
  int? _reminderEveryHours;

  /// 提醒可暂停（snooze）的分钟数，`null` 表示未设置（显示为 "-"）。
  int? _snoozeMinutes;

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
              _ValueDropdown(
                skin: skin,
                selected: _reminderEveryHours,
                values: const [1, 2, 3, 4, 5, 6, 7, 8,9,10,11,12],
                labelOf: (v) => v == null
                    ? l10n.commonDashPlaceholder
                    : l10n.commonHoursValue(v),
                onSelect: (v) => setState(() => _reminderEveryHours = v),
              ),
              const SizedBox(width: AppSpacing.xs),
              _ValueDropdown(
                skin: skin,
                selected: _snoozeMinutes,
                values: const [15, 30, 45],
                labelOf: (v) => v == null
                    ? l10n.commonDashPlaceholder
                    : l10n.commonMinutesValue(v),
                onSelect: (v) => setState(() => _snoozeMinutes = v),
              ),
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
                    _quietRanges.remove(index);
                  } else {
                    _quietDays.add(index);
                    _quietRanges[index] = _QuietRange(startSlot: 44, endSlot: 14);
                  }
                }),
              );
            }),
          ),
        ),
        for (final day in List.generate(7, (i) => i).where(_quietDays.contains)) ...[
          const SettingsSectionDivider(),
          _QuietRangeRow(
            skin: skin,
            l10n: l10n,
            weekdayFullLabel: _weekdayFullLabel(day),
            range: _quietRanges[day]!,
            onChanged: () => setState(() {}),
          ),
        ],
      ],
    );
  }

  /// 本地化的星期全称（"Sunday" / "星期日" ...）。以 2023-01-01(周日) 为基准推算。
  String _weekdayFullLabel(int weekdayIndex) {
    final locale = Localizations.localeOf(context).toString();
    final date = DateTime(2023, 1, 1 + weekdayIndex);
    return DateFormat.EEEE(locale).format(date);
  }
}

/// 通用的值下拉选择框:显示当前值 + 下拉箭头,点击弹出 [AppMenuAnchor] 单选列表。
class _ValueDropdown<T> extends StatelessWidget {
  const _ValueDropdown({
    required this.skin,
    required this.selected,
    required this.values,
    required this.labelOf,
    required this.onSelect,
  });

  final AppSkin skin;
  final T? selected;
  final List<T> values;
  final String Function(T? value) labelOf;
  final ValueChanged<T?> onSelect;

  @override
  Widget build(BuildContext context) {
    return AppMenuAnchor(
      entries: [
        AppMenuRadioGroup<T?>(
          values: [null, ...values],
          selected: selected,
          labelOf: labelOf,
          onSelect: onSelect,
        ),
      ],
      align: AppMenuAlign.underEnd,
      maxHeight: 260,
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
            Text(labelOf(selected), style: TextStyle(fontSize: 14, color: skin.text)),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.keyboard_arrow_down, size: 18, color: skin.textSecondary),
          ],
        ),
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

/// 一天的静默时段行:星期全称 + 起始时间下拉 + "to" + 结束时间下拉 (+ "next day")。
class _QuietRangeRow extends StatelessWidget {
  const _QuietRangeRow({
    required this.skin,
    required this.l10n,
    required this.weekdayFullLabel,
    required this.range,
    required this.onChanged,
  });

  final AppSkin skin;
  final AppLocalizations l10n;
  final String weekdayFullLabel;
  final _QuietRange range;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(weekdayFullLabel, style: TextStyle(fontSize: 14, color: skin.text)),
          ),
          _TimeSlotDropdown(
            skin: skin,
            locale: locale,
            selectedSlot: range.startSlot,
            onSelect: (slot) {
              range.startSlot = slot;
              onChanged();
            },
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(l10n.timeFocusQuietHoursTo, style: TextStyle(fontSize: 14, color: skin.textSecondary)),
          const SizedBox(width: AppSpacing.xs),
          _TimeSlotDropdown(
            skin: skin,
            locale: locale,
            selectedSlot: range.endSlot,
            onSelect: (slot) {
              range.endSlot = slot;
              onChanged();
            },
          ),
          if (range.isOvernight) ...[
            const SizedBox(width: AppSpacing.xs),
            Text(
              l10n.timeFocusQuietHoursNextDay,
              style: TextStyle(fontSize: 13, color: skin.textTertiary),
            ),
          ],
        ],
      ),
    );
  }
}

/// 半小时精度的时间下拉:12:00am 到 11:30pm 共 48 档，[slot] = 距 0 点的半小时数。
class _TimeSlotDropdown extends StatelessWidget {
  const _TimeSlotDropdown({
    required this.skin,
    required this.locale,
    required this.selectedSlot,
    required this.onSelect,
  });

  final AppSkin skin;
  final String locale;
  final int selectedSlot;
  final ValueChanged<int> onSelect;

  String _labelOf(int slot) {
    final minutes = slot * 30;
    final time = DateTime(2023, 1, 1, minutes ~/ 60, minutes % 60);
    return DateFormat.jm(locale).format(time);
  }

  @override
  Widget build(BuildContext context) {
    return AppMenuAnchor(
      entries: [
        AppMenuRadioGroup<int>(
          values: List.generate(48, (slot) => slot),
          selected: selectedSlot,
          labelOf: _labelOf,
          onSelect: onSelect,
        ),
      ],
      align: AppMenuAlign.underEnd,
      maxHeight: 260,
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
            Text(_labelOf(selectedSlot), style: TextStyle(fontSize: 14, color: skin.text)),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.keyboard_arrow_down, size: 18, color: skin.textSecondary),
          ],
        ),
      ),
    );
  }
}
