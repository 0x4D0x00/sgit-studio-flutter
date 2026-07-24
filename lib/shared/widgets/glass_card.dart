import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_controller.dart';

/// 毛玻璃卡片(双层结构实现磨砂效果)。
///
/// 下层:半透明底色(不怎么透明)，给卡片实体感。
/// 上层:BackdropFilter 模糊 + 极淡色叠加，产生磨砂质感。
/// 透明模式下使用 #BEBDB9 颜色。
class GlassCard extends ConsumerWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blur = 16.0,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double blur;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final transparentMode = ref.watch(themeControllerProvider.select((s) => s.transparentMode));
    final radius = borderRadius ?? BorderRadius.circular(AppRadius.lg);

    // 透明模式下使用固定颜色（更透明）
    final backgroundColor = transparentMode
        ? const Color(0xFF8A8985).withValues(alpha: 0.15) // 更透明
        : isDark
            ? const Color(0xFF4A5767).withValues(alpha: 0.5)
            : const Color(0xFFEFF4FA).withValues(alpha: 0.6);

    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          // L3:下层底色，固定颜色。
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: radius,
              ),
            ),
          ),
          // L4:上层 BackdropFilter 模糊，只模糊不加颜色。
          ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.transparent, // 只模糊，不加颜色
                  borderRadius: radius,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.3),
                    width: 1.5,
                  ),
                ),
                padding: padding,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
