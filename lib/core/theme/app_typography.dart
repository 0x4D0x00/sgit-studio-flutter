import 'package:flutter/material.dart';

/// 字体排版令牌。只定义**结构**(字号/字重/行高)，颜色交给语义色。
///
/// 动态字号缩放不在这里实现——它由 `ThemeController.fontScale` 通过
/// `MediaQuery.textScaler` 全局应用(Ctrl+滚轮实时调)，所以这里写的是基准字号。
class AppTypography {
  AppTypography._();

  static const List<String> fontFallback = <String>[
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans SC',
    'Segoe UI',
    'Roboto',
  ];

  static TextTheme textTheme(Color onSurface, Color onSurfaceVariant) {
    TextStyle s(double size, FontWeight w, {Color? c, double h = 1.4}) => TextStyle(
          fontSize: size,
          fontWeight: w,
          height: h,
          color: c ?? onSurface,
          fontFamilyFallback: fontFallback,
        );

    return TextTheme(
      displayLarge: s(32, FontWeight.w700, h: 1.2),
      displayMedium: s(28, FontWeight.w700, h: 1.2),
      headlineMedium: s(24, FontWeight.w600, h: 1.25),
      headlineSmall: s(20, FontWeight.w600),
      titleLarge: s(18, FontWeight.w600),
      titleMedium: s(16, FontWeight.w600),
      titleSmall: s(14, FontWeight.w600),
      bodyLarge: s(16, FontWeight.w400),
      bodyMedium: s(14, FontWeight.w400),
      bodySmall: s(12, FontWeight.w400, c: onSurfaceVariant),
      labelLarge: s(14, FontWeight.w500),
      labelMedium: s(12, FontWeight.w500),
      labelSmall: s(11, FontWeight.w500, c: onSurfaceVariant),
    );
  }
}
