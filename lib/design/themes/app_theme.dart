import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/design/tokens/app_typography.dart';

/// 主题组装器(单一真源)。把令牌 + 动态主色/次色拼成浅/深 `ThemeData`。
///
/// 关键:`scaffoldBackgroundColor` 设为**透明**，因为真正的背景由三层结构的
/// L1(全透明) + L2(霓虹) 负责绘制，内容页(L3)不自带不透明底。
class AppTheme {
  AppTheme._();

  static ThemeData light({
    required Color primary,
    required Color secondary,
    bool transparent = false,
  }) =>
      _build(Brightness.light, primary, secondary, transparent);

  static ThemeData dark({
    required Color primary,
    required Color secondary,
    bool transparent = false,
  }) =>
      _build(Brightness.dark, primary, secondary, transparent);

  static ThemeData _build(
    Brightness brightness,
    Color primary,
    Color secondary,
    bool transparent,
  ) {
    final isDark = brightness == Brightness.dark;

    // 皮肤令牌：明/暗/透明三选一，选完塞进 ThemeExtension。
    // 组件从此只读 AppSkin.of(context)，不再自己判 isDark、也不问透明模式。
    final skin = switch ((transparent, isDark)) {
      (true, _) => AppSkin.transparent,
      (false, true) => AppSkin.dark,
      (false, false) => AppSkin.light,
    };

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
      extensions: <ThemeExtension<dynamic>>[skin],
      // 全局字体:随包 SGiTSans。必须在 ThemeData 这一层设，textTheme 只覆盖走
      // textTheme 的文字；裸 TextStyle / hintStyle 等要靠这里兜底，否则 Web 上不渲染。
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: AppTypography.fontFallback,
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
