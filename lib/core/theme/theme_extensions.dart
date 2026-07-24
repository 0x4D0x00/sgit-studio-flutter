import 'package:flutter/material.dart';

/// 主题扩展：存储渐变色等非标准属性。
class GradientTheme extends ThemeExtension<GradientTheme> {
  const GradientTheme({required this.primaryGradient});

  /// 主渐变色（用于按钮、彗星等）。
  final Gradient primaryGradient;

  @override
  GradientTheme copyWith({Gradient? primaryGradient}) {
    return GradientTheme(
      primaryGradient: primaryGradient ?? this.primaryGradient,
    );
  }

  @override
  GradientTheme lerp(ThemeExtension<GradientTheme>? other, double t) {
    if (other is! GradientTheme) return this;
    return GradientTheme(
      primaryGradient: Gradient.lerp(primaryGradient, other.primaryGradient, t)!,
    );
  }

  /// 从 Theme 获取渐变主题。
  static GradientTheme of(BuildContext context) {
    return Theme.of(context).extension<GradientTheme>()!;
  }
}
