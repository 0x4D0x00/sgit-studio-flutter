import 'package:flutter/material.dart';

/// 颜色令牌(单一真源)。
///
/// 三层页面结构的底色约定:
/// - **L1** 全透明(不在这里出现颜色，就是 `Colors.transparent`)
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
}
