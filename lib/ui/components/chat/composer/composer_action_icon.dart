import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/composer_metrics.dart';

/// 动作栏上的图标按钮（`+`、审批策略、模型图标共用）。
///
/// 1:1 对齐 studio 的 `<Action size={{ blockSize: 32, borderRadius: 8, size: 18 }} />`
/// （`ActionBar/components/Action.tsx:76-81`、`ActionBar/Plus/index.tsx:706`）。
///
/// 不用 [IconButton]：它自带 8px 的视觉内边距和 48×48 的最小命中区，
/// 实际占位会变成 48 而不是 32，一排放三个就把动作栏顶高一截。
///
/// ## [onTap] 为什么可以不传
///
/// 这个图标多数时候是 `AppMenuAnchor` 的触发器，而**锚点自己会在外面套一层
/// `InkWell` 负责开合菜单**。如果这里再套一层自己的 `InkWell`，内层会先命中并
/// 吃掉点击 —— 菜单永远打不开，而且看不出任何异常（有涟漪、有 hover，就是不弹）。
///
/// 所以：当触发器由外部锚点驱动时**不要传 [onTap]**，只传 [enabled] 控制长相。
/// 独立使用（不在菜单里）时才传 [onTap]，那种情况下才建自己的 `InkWell`。
///
/// ⚠️ 纯展示组件：只收值与回调。
class ComposerActionIcon extends StatelessWidget {
  const ComposerActionIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.enabled = true,
    this.active = false,
  });

  final IconData icon;

  /// 悬停提示。**必填** —— 一排没有文字的图标按钮，没有 tooltip 就是在让用户猜。
  final String tooltip;

  /// 独立使用时的点击回调。在 `AppMenuAnchor` 里**必须不传**（见类注释）。
  final VoidCallback? onTap;

  /// 是否可用。与 [onTap] 分开：菜单触发器不传 onTap 但仍然是可用的。
  final bool enabled;

  /// 选中态（如审批策略当前不是默认档时高亮）。
  final bool active;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final color = switch ((enabled, active)) {
      (false, _) => skin.borderSecondary,
      (true, true) => skin.accentChip,
      (true, false) => skin.textSecondary,
    };

    final box = SizedBox(
      width: ComposerMetrics.actionButtonSize,
      height: ComposerMetrics.actionButtonSize,
      child: Icon(
        icon,
        size: ComposerMetrics.actionIconSize,
        color: color,
      ),
    );

    return Tooltip(
      message: tooltip,
      child: onTap == null
          ? box
          : InkWell(
              onTap: enabled ? onTap : null,
              borderRadius:
                  BorderRadius.circular(ComposerMetrics.actionButtonRadius),
              child: box,
            ),
    );
  }
}
