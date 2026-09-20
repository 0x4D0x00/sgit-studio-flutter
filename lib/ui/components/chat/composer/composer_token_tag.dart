import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/design/tokens/composer_metrics.dart';

/// 上下文窗口占用标签 —— 环形进度 + 百分比。
///
/// 1:1 对齐 studio 的 `TokenTag`（`ActionBar/Token/TokenTag.tsx:240-255`）：
/// blockSize 28 / icon 18。
///
/// ## 占用低于一半时整个不渲染
///
/// studio: `if (!isDevMode && maxTokens > 0 && totalToken / maxTokens <= 0.5) return null`
/// （TokenTag.tsx:158）。这不是省地方 —— 上下文还剩一大半时这个数字对用户
/// **没有任何决策价值**，常驻只会让人焦虑。快满了才值得出现。
///
/// 判空/判阈值由外部做（组件只管画），因为"要不要显示"牵涉 dev 模式等业务判断。
///
/// ⚠️ 纯展示组件。
class ComposerTokenTag extends StatelessWidget {
  const ComposerTokenTag({
    super.key,
    required this.used,
    required this.max,
    required this.tooltip,
  });

  /// 已用 token。
  final int used;

  /// 模型上下文窗口。
  final int max;

  /// 悬停提示（「已用 x / 共 y」之类，文案由外部本地化）。
  final String tooltip;

  /// 是否够格显示。调用方**应当先问这个**再决定建不建组件。
  ///
  /// 放在这里而不是调用方自己写 `used / max > 0.5`：阈值是设计决定，
  /// 散到调用点就会出现两个页面阈值不一样。
  static bool shouldShow({required int used, required int max}) =>
      max > 0 && used / max > ComposerMetrics.tokenTagVisibleThreshold;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final ratio = max <= 0 ? 0.0 : (used / max).clamp(0.0, 1.0);

    // 超过 90% 转警示色 —— 到这一步用户该考虑压缩会话了，
    // 跟 50%~90% 那段"知道就行"的灰色区分开。
    final scheme = Theme.of(context).colorScheme;
    final color = ratio >= 0.9 ? scheme.error : skin.textSecondary;

    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: ComposerMetrics.tokenTagHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: ComposerMetrics.tokenTagIconSize,
              height: ComposerMetrics.tokenTagIconSize,
              child: CircularProgressIndicator(
                value: ratio,
                strokeWidth: ComposerMetrics.tokenTagRingStroke,
                color: color,
                backgroundColor: skin.borderSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              '${(ratio * 100).round()}%',
              style: TextStyle(
                fontSize: ComposerMetrics.controlButtonFontSize,
                color: color,
                // 百分比会从 51% 一路跳到 99%，等宽数字避免标签宽度抖动。
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
