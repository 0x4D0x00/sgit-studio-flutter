import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';

/// 皮肤令牌 —— **明暗与透明模式的差异全部在这里解决一次**。
///
/// 铁律：组件里**禁止**出现 `isDark ? A : B`，也禁止 `ref.watch(themeController)` 去问
/// 「现在是不是透明模式」。组件只做一件事：
///
/// ```dart
/// final skin = AppSkin.of(context);
/// ... color: skin.text ...
/// ```
///
/// 这样带来两个结果：
/// 1. 加第四种模式（高对比 / 特效分级）只改本文件的工厂方法，组件一行不动；
/// 2. `design/` `ui/` `layout/` 三层彻底不依赖状态管理库 —— 皮肤随 `Theme` 走继承，
///    换 Riverpod / Signals 都影响不到它们。
@immutable
class AppSkin extends ThemeExtension<AppSkin> {
  const AppSkin({
    required this.baseBg,
    required this.layoutBg,
    required this.containerBg,
    required this.containerBgSecondary,
    required this.border,
    required this.borderSecondary,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.navItemActive,
    required this.accentChip,
    required this.glassBg,
    required this.glassBorder,
    required this.inputBg,
    required this.inputBorder,
    required this.inputShadow,
    required this.inputInsetHighlight,
    required this.showNeon,
    required this.neonIntensity,
    required this.blurSigma,
  });

  /// L0 底色。透明模式下为全透明，让桌面/毛玻璃透上来。
  final Color baseBg;

  /// 外框与左栏底色（studio 的 colorBgLayout）。
  final Color layoutBg;

  /// 圆角卡与面板底色（studio 的 colorBgContainer）。
  final Color containerBg;
  final Color containerBgSecondary;

  final Color border;
  final Color borderSecondary;

  final Color text;
  final Color textSecondary;
  final Color textTertiary;

  /// 导航选中态底色。
  final Color navItemActive;

  /// 技能标签等强调色。
  final Color accentChip;

  final Color glassBg;
  final Color glassBorder;

  final Color inputBg;
  final Color inputBorder;
  final List<BoxShadow> inputShadow;

  /// 输入框顶边的一道内高光。
  ///
  /// studio 用 `box-shadow: inset 0 1px 0 ...` 做（`glassInputStyle.ts:12-14`），
  /// Flutter 的 [BoxDecoration] **没有 inset shadow** —— 只能在内侧画一条 1px 渐变顶边。
  /// 少了它，磨砂面在暗色下会平得像一块灰卡片。
  final Color inputInsetHighlight;

  /// L2 霓虹层是否绘制。
  final bool showNeon;
  final double neonIntensity;

  /// 毛玻璃模糊半径。0 = 不模糊（P4 的特效分级会把这里降到 0 做降级）。
  final double blurSigma;

  static AppSkin of(BuildContext context) =>
      Theme.of(context).extension<AppSkin>()!;

  // ---- 三种模式的工厂。新增模式只在这里加，组件不动 ----

  static const AppSkin light = AppSkin(
    baseBg: Color(0xEBFFFFFF), // 白 @92%
    layoutBg: AppColors.layoutBgLight,
    containerBg: AppColors.containerBgLight,
    containerBgSecondary: AppColors.containerBgSecondaryLight,
    border: AppColors.borderLight,
    borderSecondary: AppColors.borderSecondaryLight,
    text: AppColors.textLight,
    textSecondary: AppColors.textSecondaryLight,
    textTertiary: AppColors.textTertiaryLight,
    navItemActive: AppColors.navItemActive,
    accentChip: AppColors.skillChip,
    glassBg: Color(0x99EFF4FA), // #EFF4FA @60%
    glassBorder: Color(0x4DFFFFFF), // 白 @30%
    inputBg: Color(0x99FFFFFF), // 白 @60%
    inputBorder: Color(0xE6DCEBF8), // #DCEBF8 @90%
    inputShadow: [
      BoxShadow(color: Color(0x24788AAA), blurRadius: 20, offset: Offset(0, 6)),
    ],
    inputInsetHighlight: AppColors.inputInsetHighlightLight,
    showNeon: true,
    neonIntensity: 0.5,
    blurSigma: 16,
  );

  static const AppSkin dark = AppSkin(
    baseBg: Color(0xF21A1A1A), // #1A1A1A @95%
    layoutBg: AppColors.layoutBgDark,
    containerBg: AppColors.containerBgDark,
    containerBgSecondary: AppColors.containerBgSecondaryDark,
    border: AppColors.borderDark,
    borderSecondary: AppColors.borderSecondaryDark,
    text: AppColors.textDark,
    textSecondary: AppColors.textSecondaryDark,
    textTertiary: AppColors.textTertiaryDark,
    navItemActive: AppColors.navItemActive,
    accentChip: AppColors.skillChip,
    glassBg: Color(0x804A5767), // #4A5767 @50%
    glassBorder: Color(0x1AFFFFFF), // 白 @10%
    inputBg: Color(0x8C18181B), // #18181B @55%
    inputBorder: Color(0x1AFFFFFF),
    inputShadow: [
      BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
    inputInsetHighlight: AppColors.inputInsetHighlightDark,
    showNeon: true,
    neonIntensity: 1.0,
    blurSigma: 16,
  );

  /// 透明模式（本客户端自有能力，React 版 studio 没有）：L0 全透、卡底半透、霓虹让位给桌面。
  static const AppSkin transparent = AppSkin(
    baseBg: Colors.transparent,
    layoutBg: Colors.transparent,
    containerBg: Color(0x590D0D0D), // #0D0D0D @35%
    containerBgSecondary: Color(0x59070707),
    border: AppColors.borderDark,
    borderSecondary: AppColors.borderSecondaryDark,
    text: AppColors.textDark,
    textSecondary: AppColors.textSecondaryDark,
    textTertiary: AppColors.textTertiaryDark,
    navItemActive: AppColors.navItemActive,
    accentChip: AppColors.skillChip,
    glassBg: Color(0x268A8985), // #8A8985 @15%
    glassBorder: Color(0x1AFFFFFF),
    inputBg: Color(0x8C18181B),
    inputBorder: Color(0x1AFFFFFF),
    inputShadow: [
      BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
    inputInsetHighlight: AppColors.inputInsetHighlightDark,
    showNeon: false,
    neonIntensity: 0,
    blurSigma: 16,
  );

  @override
  AppSkin copyWith({
    Color? baseBg,
    Color? layoutBg,
    Color? containerBg,
    Color? containerBgSecondary,
    Color? border,
    Color? borderSecondary,
    Color? text,
    Color? textSecondary,
    Color? textTertiary,
    Color? navItemActive,
    Color? accentChip,
    Color? glassBg,
    Color? glassBorder,
    Color? inputBg,
    Color? inputBorder,
    List<BoxShadow>? inputShadow,
    Color? inputInsetHighlight,
    bool? showNeon,
    double? neonIntensity,
    double? blurSigma,
  }) =>
      AppSkin(
        baseBg: baseBg ?? this.baseBg,
        layoutBg: layoutBg ?? this.layoutBg,
        containerBg: containerBg ?? this.containerBg,
        containerBgSecondary: containerBgSecondary ?? this.containerBgSecondary,
        border: border ?? this.border,
        borderSecondary: borderSecondary ?? this.borderSecondary,
        text: text ?? this.text,
        textSecondary: textSecondary ?? this.textSecondary,
        textTertiary: textTertiary ?? this.textTertiary,
        navItemActive: navItemActive ?? this.navItemActive,
        accentChip: accentChip ?? this.accentChip,
        glassBg: glassBg ?? this.glassBg,
        glassBorder: glassBorder ?? this.glassBorder,
        inputBg: inputBg ?? this.inputBg,
        inputBorder: inputBorder ?? this.inputBorder,
        inputShadow: inputShadow ?? this.inputShadow,
        inputInsetHighlight: inputInsetHighlight ?? this.inputInsetHighlight,
        showNeon: showNeon ?? this.showNeon,
        neonIntensity: neonIntensity ?? this.neonIntensity,
        blurSigma: blurSigma ?? this.blurSigma,
      );

  @override
  AppSkin lerp(ThemeExtension<AppSkin>? other, double t) {
    if (other is! AppSkin) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSkin(
      baseBg: c(baseBg, other.baseBg),
      layoutBg: c(layoutBg, other.layoutBg),
      containerBg: c(containerBg, other.containerBg),
      containerBgSecondary: c(containerBgSecondary, other.containerBgSecondary),
      border: c(border, other.border),
      borderSecondary: c(borderSecondary, other.borderSecondary),
      text: c(text, other.text),
      textSecondary: c(textSecondary, other.textSecondary),
      textTertiary: c(textTertiary, other.textTertiary),
      navItemActive: c(navItemActive, other.navItemActive),
      accentChip: c(accentChip, other.accentChip),
      glassBg: c(glassBg, other.glassBg),
      glassBorder: c(glassBorder, other.glassBorder),
      inputBg: c(inputBg, other.inputBg),
      inputBorder: c(inputBorder, other.inputBorder),
      inputShadow:
          BoxShadow.lerpList(inputShadow, other.inputShadow, t) ?? inputShadow,
      inputInsetHighlight: c(inputInsetHighlight, other.inputInsetHighlight),
      // 布尔与强度按 0.5 切换，避免动画中途出现半透霓虹闪烁。
      showNeon: t < 0.5 ? showNeon : other.showNeon,
      neonIntensity: neonIntensity + (other.neonIntensity - neonIntensity) * t,
      blurSigma: blurSigma + (other.blurSigma - blurSigma) * t,
    );
  }
}
