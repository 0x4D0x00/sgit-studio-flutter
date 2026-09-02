import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

/// 毛玻璃卡片（双层结构实现磨砂效果）。
///
/// 下层：半透明底色 [AppSkin.glassBg]，给卡片实体感。
/// 上层：[BackdropFilter] 模糊 + 1.5px 亮边，产生磨砂质感。
///
/// ⚠️ 两条约束：
/// 1. **不依赖状态管理库**。明暗/透明模式的差异在 [AppSkin] 里已经解决。
/// 2. `BackdropFilter` 是 Web 上最贵的合成操作。[AppSkin.blurSigma] 为 0 时**整层不建**
///    （不是模糊半径设 0 —— 那样依然会付出一次离屏合成的代价）。P4 的特效分级靠这条降级。
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blur,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  /// 覆盖皮肤的默认模糊半径。传 0 可单点关掉模糊。
  final double? blur;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.lg);
    final sigma = blur ?? skin.blurSigma;

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: skin.glassBg,
        borderRadius: radius,
        border: Border.all(color: skin.glassBorder, width: 1.5),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );

    if (sigma <= 0) {
      return ClipRRect(borderRadius: radius, child: surface);
    }

    return ClipRRect(
      borderRadius: radius,
      // RepaintBoundary：模糊层一旦重绘就要重新采样底下所有像素，别让它跟着邻居一起重绘。
      child: RepaintBoundary(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: surface,
        ),
      ),
    );
  }
}
