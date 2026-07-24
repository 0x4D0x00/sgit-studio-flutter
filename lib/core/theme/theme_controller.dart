import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage.dart';
import 'app_colors.dart';

/// 应用主题模式：透明 / 浅色 / 深色 / 跟随系统。
enum AppThemeMode {
  transparent, // 透明模式：L0 和 L2 都透明
  light,
  dark,
  system;

  /// 转成 Flutter 的 ThemeMode（透明模式底层用深色）。
  ThemeMode get flutterMode => switch (this) {
        AppThemeMode.transparent => ThemeMode.dark,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      };

  bool get isTransparent => this == AppThemeMode.transparent;
}

/// 主题偏好状态:模式 + 主色 + 次色 + 字号缩放。全部可运行时动态修改并持久化。
@immutable
class ThemeState {
  const ThemeState({
    required this.mode,
    required this.primary,
    required this.secondary,
    required this.fontScale,
  });

  final AppThemeMode mode;
  final Color primary;
  final Color secondary;

  /// 全局字号缩放因子。Ctrl+滚轮实时调整，范围见 [minFontScale]/[maxFontScale]。
  final double fontScale;

  /// 透明模式：L0 和 L2 都透明。
  bool get transparentMode => mode.isTransparent;

  ThemeState copyWith({
    AppThemeMode? mode,
    Color? primary,
    Color? secondary,
    double? fontScale,
  }) =>
      ThemeState(
        mode: mode ?? this.mode,
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        fontScale: fontScale ?? this.fontScale,
      );
}

/// 主题控制器。运行时切换模式/主色/次色/字号，并持久化到本地。
class ThemeController extends Notifier<ThemeState> {
  static const double minFontScale = 0.8;
  static const double maxFontScale = 1.6;
  static const double _fontStep = 0.1;

  @override
  ThemeState build() {
    final s = LocalStorage.instance;
    return ThemeState(
      mode: _parseMode(s.themeMode),
      primary: s.primary != null ? Color(s.primary!) : AppColors.defaultPrimary,
      secondary:
          s.secondary != null ? Color(s.secondary!) : AppColors.defaultSecondary,
      fontScale: s.fontScale ?? 1.0,
    );
  }

  void setMode(AppThemeMode mode) {
    // 透明模式自动用白色主题色，其他模式恢复默认
    final primary = mode.isTransparent ? Colors.white : AppColors.defaultPrimary;
    state = state.copyWith(mode: mode, primary: primary);
    LocalStorage.instance.setThemeMode(mode.name);
    LocalStorage.instance.setPrimary(primary.toARGB32());
  }

  void setPrimary(Color c) {
    state = state.copyWith(primary: c);
    LocalStorage.instance.setPrimary(c.toARGB32());
  }

  void setSecondary(Color c) {
    state = state.copyWith(secondary: c);
    LocalStorage.instance.setSecondary(c.toARGB32());
  }

  void resetPrimary() {
    state = state.copyWith(primary: AppColors.defaultPrimary);
    LocalStorage.instance.setPrimary(AppColors.defaultPrimary.toARGB32());
  }

  void resetSecondary() {
    state = state.copyWith(secondary: AppColors.defaultSecondary);
    LocalStorage.instance.setSecondary(AppColors.defaultSecondary.toARGB32());
  }

  void setFontScale(double scale) {
    final clamped = scale.clamp(minFontScale, maxFontScale).toDouble();
    state = state.copyWith(fontScale: clamped);
    LocalStorage.instance.setFontScale(clamped);
  }

  /// Ctrl+滚轮:向上放大、向下缩小(一步 [_fontStep])。
  void bumpFontScale(int direction) =>
      setFontScale(state.fontScale + _fontStep * direction);

  void resetFontScale() => setFontScale(1.0);

  static AppThemeMode _parseMode(String? v) => switch (v) {
        'transparent' => AppThemeMode.transparent,
        'light' => AppThemeMode.light,
        'dark' => AppThemeMode.dark,
        _ => AppThemeMode.system,
      };
}

final themeControllerProvider =
    NotifierProvider<ThemeController, ThemeState>(ThemeController.new);
