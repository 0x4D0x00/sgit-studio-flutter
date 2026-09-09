import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

/// 分段切换器的一项（**纯展示数据**，不含业务语义）。
@immutable
class SegmentOption<T> {
  const SegmentOption({
    required this.value,
    required this.icon,
    required this.label,
  });

  final T value;
  final IconData icon;
  final String label;
}

/// 胶囊分段切换器 —— 输入框上方那排「渗透 / 防护 / 竞赛 / 办公」。
///
/// 外层一个 pill 描边，选中项自己也是 pill（填充强调色 @10%）。
///
/// ⚠️ **纯展示组件**：不 import 状态管理库、不 import features、不判 `isDark`。
/// 数据与回调由 `features/chat/presentation/assistant_switcher_container.dart` 注入。
class AssistantSwitcher<T> extends StatelessWidget {
  const AssistantSwitcher({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.tooltip,
  });

  final List<SegmentOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelect;

  /// 整个控件的语义标签（读屏用；视觉上不出现）。
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return Semantics(
      label: tooltip,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: skin.borderSecondary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final o in options) _segment(skin, o),
          ],
        ),
      ),
    );
  }

  Widget _segment(AppSkin skin, SegmentOption<T> o) {
    final active = o.value == selected;
    final fg = active ? skin.accentChip : skin.textSecondary;

    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active
            ? skin.accentChip.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // 已选中的再点一次不该重开一轮对话，所以直接禁掉。
          onTap: active ? null : () => onSelect(o.value),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(o.icon, size: 15, color: fg),
                const SizedBox(width: AppSpacing.xxs + 2),
                Text(
                  o.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
