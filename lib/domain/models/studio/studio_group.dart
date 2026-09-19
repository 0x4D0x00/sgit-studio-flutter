import 'package:flutter/material.dart';

/// studio 各页的**分组元数据** —— key 就是 sgcode 真源的 id 首段（目录名）。
///
/// ## 与 React studio 逐字对齐
///
/// 照 `sgit-studio/src/routes/(main)/settings/features/sgcodeGlass.ts` 的
/// `TEAM_META` / `SKILL_TEAM_META` / `GENERAL_META`。**key 与色相不能自己发明** ——
/// 它们对应后端目录名与两端一致的视觉语言，改一处就两边不一样了。
///
/// 实测本地 per-cid 目录正是这四个分组：
/// `scenes/{redteam-ops,blueteam-defense,ctf-team,sgitai_lan}/`。
///
/// ## 头像的缺口
///
/// React 那边组头用品牌头像（`AGENT_AVATAR('shentou')` 等）。Flutter 的
/// `assets/brand/images/` 下目前只有 `login/`，**没有 agents 头像**。
/// 所以这里用 Material 图标 + 同一套色相 —— 视觉语言一致，但不假装有头像。
/// 资源到位后把 [icon] 换成 `Image.asset` 即可，分组结构不用动。
@immutable
class StudioGroup {
  const StudioGroup({
    required this.key,
    required this.label,
    required this.icon,
    required this.hue,
  });

  /// = id 首段（目录名）。`__general__` 是未归类的兜底。
  final String key;
  final String label;
  final IconData icon;

  /// 色相 key，取色见 [hueColor]。
  final StudioHue hue;
}

/// 分组色相。**深浅两套值照抄 React 的 `HUE`**（`sgcodeGlass.ts:31`）——
/// 那边已经按可读性调过，不重新配色。
enum StudioHue {
  blue(dark: Color(0xFF5E93F0), light: Color(0xFF0A3161)),
  gold(dark: Color(0xFFE0B341), light: Color(0xFF9C7515)),
  green(dark: Color(0xFF2FBE77), light: Color(0xFF00814A)),
  indigo(dark: Color(0xFF8E86EE), light: Color(0xFF3B357E)),
  red(dark: Color(0xFFEA5B78), light: Color(0xFFB01B3F)),
  slate(dark: Color(0xFF93A1B3), light: Color(0xFF5B6675));

  const StudioHue({required this.dark, required this.light});

  final Color dark;
  final Color light;

  /// 按当前主题取色。与 React 的 `hue(key, isDark)` 同语义。
  Color of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// 通用（未归类）分组。id 首段不在已知分组里的条目落这儿。
const studioGeneralGroup = StudioGroup(
  key: '__general__',
  label: '通用',
  icon: Icons.category_outlined,
  hue: StudioHue.slate,
);

/// 团队分组 —— 场景 / 子 Agent 用。顺序即展示顺序。
const studioTeamGroups = <StudioGroup>[
  StudioGroup(
    key: 'redteam-ops',
    label: '渗透助理',
    icon: Icons.gps_fixed_rounded,
    hue: StudioHue.red,
  ),
  StudioGroup(
    key: 'blueteam-defense',
    label: '防护助理',
    icon: Icons.shield_outlined,
    hue: StudioHue.blue,
  ),
  StudioGroup(
    key: 'ctf-team',
    label: '竞赛助理',
    icon: Icons.flag_outlined,
    hue: StudioHue.indigo,
  ),
  StudioGroup(
    key: 'sgitai_lan',
    label: '办公助理',
    icon: Icons.laptop_mac_rounded,
    hue: StudioHue.green,
  ),
];

/// 技能分组 —— 在团队之外多三类（照 React 的 `SKILL_TEAM_META`）。
const studioSkillGroups = <StudioGroup>[
  ...studioTeamGroups,
  StudioGroup(
    key: 'web-offense',
    label: 'Web / 漏洞',
    icon: Icons.bug_report_outlined,
    hue: StudioHue.slate,
  ),
  StudioGroup(
    key: 'design',
    label: '设计',
    icon: Icons.palette_outlined,
    hue: StudioHue.gold,
  ),
  StudioGroup(
    key: 'dev',
    label: '研发 / 流程',
    icon: Icons.terminal_rounded,
    hue: StudioHue.slate,
  ),
];

/// 按页 key 选分组表。技能页的分类更多，其余用团队分组。
List<StudioGroup> studioGroupsFor(String pageKey) =>
    pageKey == 'skill' ? studioSkillGroups : studioTeamGroups;

/// 一个分组及其条目。
@immutable
class StudioGroupBucket<T> {
  const StudioGroupBucket({required this.group, required this.items});

  final StudioGroup group;
  final List<T> items;
}

/// 按 id 首段把条目归入分组。
///
/// 与 React 的 `groupById`（`sgcodeGlass.ts:105`）同语义：
/// - 顺序 follow [groups]，未匹配的进 [studioGeneralGroup]；
/// - **空组跳过** —— 否则页面上会挂一串「渗透助理 · 0」的空标题；
/// - id 形如 `redteam-ops/incident-response` → 归 `redteam-ops`。
List<StudioGroupBucket<T>> groupByIdPrefix<T>(
  List<T> items,
  List<StudioGroup> groups,
  String Function(T) idOf,
) {
  final buckets = <String, List<T>>{};
  final known = {for (final g in groups) g.key};

  for (final item in items) {
    final id = idOf(item);
    final seg = id.contains('/') ? id.split('/').first : id;
    // id 没有斜杠时它整体不是分组名，归「通用」——
    // 顶层文件（如 scenes/top.toml）就是这种情况。
    final key = known.contains(seg) ? seg : studioGeneralGroup.key;
    buckets.putIfAbsent(key, () => <T>[]).add(item);
  }

  return [
    for (final g in [...groups, studioGeneralGroup])
      if (buckets[g.key]?.isNotEmpty ?? false)
        StudioGroupBucket(group: g, items: buckets[g.key]!),
  ];
}
