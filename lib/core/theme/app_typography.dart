import 'package:flutter/material.dart';

/// 字体排版令牌。只定义**结构**(字号/字重/行高)，颜色交给语义色。
///
/// 动态字号缩放不在这里实现——它由 `ThemeController.fontScale` 通过
/// `MediaQuery.textScaler` 全局应用(Ctrl+滚轮实时调)，所以这里写的是基准字号。
class AppTypography {
  AppTypography._();

  /// 随包主字体(见 pubspec.yaml `fonts:`)——**拉丁字母/数字/符号**。
  /// 必须作为主字体而不能只放 fallback：Web(CanvasKit)不认系统字体，也拉不到 gstatic
  /// 的 Roboto/Noto(内网 + CSP 双重挡)，主字体缺失时文字直接不渲染。
  static const String fontFamily = 'SGiTSans';

  /// 随包中日韩兜底字体。**必须排在系统字体名之前**——Web 上那些系统名一个都解析不到，
  /// 只有这份随包的能兜住汉字；桌面端有系统字体时也无妨(主字体已覆盖拉丁)。
  static const String fontFamilyCJK = 'SGiTSansCJK';

  /// 回退链:随包 CJK → 各平台系统字体。
  static const List<String> fontFallback = <String>[
    fontFamilyCJK,
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
          fontFamily: fontFamily,
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
