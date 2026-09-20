import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/composer_metrics.dart';

/// 控制条上的「图标 + 文字 + chevron」按钮（沙箱档位、推理强度）。
///
/// 1:1 对齐 studio 的 `ControlBar/ModeSelector.tsx:45-67`：
/// 高 28 / 左右 8 / 圆角 6 / 字 12 / icon 14 / chevron 12 / gap 6。
///
/// ⚠️ 纯展示组件：它只是个触发器，弹什么由外面的 `AppMenuAnchor` 决定。
class ComposerControlButton extends StatelessWidget {
  const ComposerControlButton({
    super.key,
    required this.icon,
    required this.label,
    this.enabled = true,
  });

  final IconData icon;

  /// 当前值（如「只读」「中」）—— 不是控件名。控制条是**状态显示**，
  /// 用户扫一眼要知道"现在是什么档"，而不是"这里可以设档"。
  final String label;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final fg = enabled ? skin.textSecondary : skin.textTertiary;

    return Container(
      height: ComposerMetrics.controlButtonHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: ComposerMetrics.controlButtonPaddingInline,
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: ComposerMetrics.controlButtonIconSize, color: fg),
          const SizedBox(width: ComposerMetrics.controlButtonGap),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: ComposerMetrics.controlButtonFontSize,
              color: fg,
            ),
          ),
          const SizedBox(width: ComposerMetrics.controlButtonGap),
          Icon(
            Icons.expand_more_rounded,
            size: ComposerMetrics.controlButtonChevronSize,
            color: enabled ? skin.textTertiary : skin.borderSecondary,
          ),
        ],
      ),
    );
  }
}
