import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/domain/models/studio/studio_group.dart';

/// 分组的视觉映射：图标与色相取值。
///
/// domain 里的 [StudioGroup] / [StudioHue] 只有 key 与枚举（纯 Dart），
/// 图标和颜色属于展示，放在这里。调用点写法不变：`group.icon`、`group.hue.of(context)`。
///
/// 色相深浅两套值**照抄 React 的 `HUE`**（`sgcodeGlass.ts:31`）—— 那边已经按
/// 可读性调过，不重新配色。
extension StudioGroupStyle on StudioGroup {
  /// 头像资源到位前用 Material 图标（见 [StudioGroup] 的说明）。未知 key 用兜底图标。
  IconData get icon => _icons[key] ?? Icons.category_outlined;
}

extension StudioHueStyle on StudioHue {
  /// 按当前主题取色。与 React 的 `hue(key, isDark)` 同语义。
  Color of(BuildContext context) {
    final c = _colors[this]!;
    return Theme.of(context).brightness == Brightness.dark ? c.dark : c.light;
  }
}

const _icons = <String, IconData>{
  'redteam-ops': Icons.gps_fixed_rounded,
  'blueteam-defense': Icons.shield_outlined,
  'ctf-team': Icons.flag_outlined,
  'sgitai_lan': Icons.laptop_mac_rounded,
  'web-offense': Icons.bug_report_outlined,
  'design': Icons.palette_outlined,
  'dev': Icons.terminal_rounded,
};

const _colors = <StudioHue, ({Color dark, Color light})>{
  StudioHue.blue: (dark: Color(0xFF5E93F0), light: Color(0xFF0A3161)),
  StudioHue.gold: (dark: Color(0xFFE0B341), light: Color(0xFF9C7515)),
  StudioHue.green: (dark: Color(0xFF2FBE77), light: Color(0xFF00814A)),
  StudioHue.indigo: (dark: Color(0xFF8E86EE), light: Color(0xFF3B357E)),
  StudioHue.red: (dark: Color(0xFFEA5B78), light: Color(0xFFB01B3F)),
  StudioHue.slate: (dark: Color(0xFF93A1B3), light: Color(0xFF5B6675)),
};
