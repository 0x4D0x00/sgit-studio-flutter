import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

/// 卡片自适应换行：列数由可用宽度**自动算**，不是写死两列 ——
/// 大窗口下铺满整行，窄窗口自动降列。
///
/// Skills / Connectors / Plugins 三页共用同一份列数逻辑，
/// 否则同一个窗口宽度下三页的卡片宽窄不一，切换 Tab 时会跳。
class ResponsiveCardWrap extends StatelessWidget {
  const ResponsiveCardWrap({
    super.key,
    required this.children,
    this.minWidth = 300,
  });

  final List<Widget> children;

  /// 卡片宽度下限。窄于此就不再并排，退成单列。
  final double minWidth;

  /// 再宽的窗口也不无限加列：超过这个数卡片会窄得放不下描述。
  static const int _maxColumns = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 能放几列就放几列（至少一列）。间距从总宽里先扣掉。
        final avail = constraints.maxWidth;
        final cols = ((avail + AppSpacing.md) / (minWidth + AppSpacing.md))
            .floor()
            .clamp(1, _maxColumns);
        final w = (avail - AppSpacing.md * (cols - 1)) / cols;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final child in children) SizedBox(width: w, child: child),
          ],
        );
      },
    );
  }
}
