import 'package:flutter/material.dart';

/// 颜色令牌(单一真源)。
///
/// 三层页面结构的底色约定:
/// - **L1** 背景层，默认全透明(不在这里出现颜色，就是 `Colors.transparent`)；
///   登录页在这一层铺品牌背景图(见 `BrandAssets.loginBg`)
/// - **L2** 霓虹层，只在有霓虹的位置上色，其余纯透明；霓虹色**跟随主题色**(见 NeonLayer)
/// - **L3** 内容层，用下面的表面/文字语义色
///
/// 组件禁止硬编码 `Color(0x..)`，一律引用此处或 `Theme.of(context).colorScheme`。
class AppColors {
  AppColors._();

  // ---- 品牌色(默认主色/次色，可在设置里动态换) ----
  static const Color defaultPrimary = Color(0xFF6FA8D4); // 浅色主题主色（柔和蓝）
  static const Color defaultSecondary = Color(0xFF9B9FB0); // 中灰蓝（衍生色）

  /// 设置页可选主色候选。
  static const List<Color> primarySwatches = <Color>[
    Color(0xFF2F6BFF), // 蓝
    Color(0xFF7C4DFF), // 紫
    Color(0xFF00C2A8), // 青
    Color(0xFFFF6B35), // 橙
    Color(0xFFE5397B), // 玫红
    Color(0xFF16A34A), // 绿
  ];

  /// 设置页可选次色候选(用于霓虹辉光第二色)。
  static const List<Color> secondarySwatches = <Color>[
    Color(0xFF00E5C0), // 青
    Color(0xFFFF3D9A), // 霓虹粉
    Color(0xFF9D5CFF), // 霓虹紫
    Color(0xFF35D0FF), // 霓虹蓝
    Color(0xFFFFC145), // 霓虹金
  ];

  // ---- 内容层(L3)语义色。深色为主(总控台默认深色更贴霓虹调性) ----
  static const Color darkBackground = Color(0xFF0A0C10);
  static const Color darkSurface = Color(0xFF12161F);
  static const Color darkSurfaceVariant = Color(0xFF1A2029);
  static const Color darkBorder = Color(0xFF262E3A);
  static const Color darkTextPrimary = Color(0xFFE8EDF4);
  static const Color darkTextSecondary = Color(0xFF8A97A8);

  static const Color lightBackground = Color(0xFFF4F6FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEDF1F7);
  static const Color lightBorder = Color(0xFFDDE3EC);
  static const Color lightTextPrimary = Color(0xFF161B24);
  static const Color lightTextSecondary = Color(0xFF5A6676);

  // ---- 状态色 ----
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFF43F5E);
  static const Color info = Color(0xFF38BDF8);

  // ---- 工作台外壳配色(1:1 对齐 sgit-studio DESIGN.md / DESIGN.dark.md 令牌) ----
  // 命名沿用 studio 的 token 名,便于对照;左栏/外框用 Layout,卡/面板用 Container。
  static const Color layoutBgLight = Color(0xFFF8F8F8);
  static const Color layoutBgDark = Color(0xFF000000);
  static const Color containerBgLight = Color(0xFFFFFFFF);
  static const Color containerBgDark = Color(0xFF0D0D0D);
  static const Color containerBgSecondaryLight = Color(0xFFFBFBFB);
  static const Color containerBgSecondaryDark = Color(0xFF070707);
  static const Color borderLight = Color(0xFFE3E3E3);
  static const Color borderDark = Color(0xFF202020);
  static const Color borderSecondaryLight = Color(0xFFEEEEEE);
  static const Color borderSecondaryDark = Color(0xFF1A1A1A);
  static const Color textLight = Color(0xFF080808);
  static const Color textDark = Color(0xFFFFFFFF);
  static const Color textSecondaryLight = Color(0xFF666666);
  static const Color textSecondaryDark = Color(0xFFAAAAAA);
  static const Color textTertiaryLight = Color(0xFF999999);
  static const Color textTertiaryDark = Color(0xFF6F6F6F);

  /// 导航选中态底色:#0074DD @10%(明暗一致,studio NavItem 写死)。
  static const Color navItemActive = Color(0x1A0074DD);

  /// 技能标签(青绿),studio SkillChips 写死。
  static const Color skillChip = Color(0xFF009688);

  /// 输入框顶边内高光。studio 用 `inset 0 1px 0 rgba(255,255,255,.5)`(亮)
  /// / `rgba(255,255,255,.06)`(暗),见 `glassInputStyle.ts:12-14`。
  static const Color inputInsetHighlightLight = Color(0x80FFFFFF); // 白 @50%
  static const Color inputInsetHighlightDark = Color(0x0FFFFFFF); // 白 @6%

  // ---- 登录页专用(1:1 对齐 sgit-studio 登录页设计稿,不跟随动态主色) ----
  /// 登录按钮品牌蓝渐变(173deg #1677ff → #0958d9)。
  static const Color loginSubmitGradientStart = Color(0xFF1677FF);
  static const Color loginSubmitGradientEnd = Color(0xFF0958D9);

  /// 登录卡片蓝调阴影(rgba(22,119,255,.10))。
  static const Color loginCardShadow = Color(0x1A1677FF);

  /// 验证码图片框底色/描边(浅色稿固定值,明暗一致)。
  static const Color loginCaptchaBg = Color(0xFFF1F5F9);
  static const Color loginCaptchaBorder = Color(0xFFE2E8F0);

}
