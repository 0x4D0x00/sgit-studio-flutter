import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// 主题组装器(单一真源)。把令牌 + 动态主色/次色拼成浅/深 `ThemeData`。
///
/// 关键:`scaffoldBackgroundColor` 设为**透明**，因为真正的背景由三层结构的
/// L1(全透明) + L2(霓虹) 负责绘制，内容页(L3)不自带不透明底。
class AppTheme {
  AppTheme._();

  static ThemeData light({required Color primary, required Color secondary}) =>
      _build(Brightness.light, primary, secondary);

  static ThemeData dark({required Color primary, required Color secondary}) =>
      _build(Brightness.dark, primary, secondary);

  static ThemeData _build(Brightness brightness, Color primary, Color secondary) {
    final isDark = brightness == Brightness.dark;

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
    ).copyWith(
      primary: primary,
      secondary: secondary,
      surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      surfaceContainerHighest:
          isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
      error: AppColors.error,
    );

    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final onSurface =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final onSurfaceVariant =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textTheme = AppTypography.textTheme(onSurface, onSurfaceVariant);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // 背景透明:交给三层结构绘制。
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: Colors.transparent,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        // 内容卡片用极低透明度 + 毛玻璃效果（通过 BackdropFilter 实现）。
        color: scheme.surface.withValues(alpha: isDark ? 0.3 : 0.5),
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias, // 让 BackdropFilter 生效必须裁剪
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: border.withValues(alpha: 0.6)),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant)
            .withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
    );
  }
}
