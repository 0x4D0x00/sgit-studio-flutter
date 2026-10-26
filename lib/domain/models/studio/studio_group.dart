import 'package:flutter/foundation.dart';

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
/// 所以展示层用 Material 图标 + 同一套色相 —— 视觉语言一致，但不假装有头像。
/// 资源到位后把图标映射换成 `Image.asset` 即可，分组结构不用动。
@immutable
class StudioGroup {
  const StudioGroup({
    required this.key,
    required this.label,
    required this.hue,
  });

  /// = id 首段（目录名）。`__general__` 是未归类的兜底。
  final String key;
  final String label;

  /// 色相 key。取色与图标是展示层的事，见 `features/studio/presentation/studio_group_style.dart`。
  final StudioHue hue;
}

/// 分组色相。具体深浅色值在展示层（`studio_group_style.dart`）。
enum StudioHue { blue, gold, green, indigo, red, slate }

/// 通用（未归类）分组。id 首段不在已知分组里的条目落这儿。
const studioGeneralGroup = StudioGroup(
  key: '__general__',
  label: '通用',
  hue: StudioHue.slate,
);

/// 团队分组 —— 场景 / 子 Agent 用。顺序即展示顺序。
const studioTeamGroups = <StudioGroup>[
  StudioGroup(
    key: 'redteam-ops',
    label: '渗透助理',
    hue: StudioHue.red,
  ),
  StudioGroup(
    key: 'blueteam-defense',
    label: '防护助理',
    hue: StudioHue.blue,
  ),
  StudioGroup(
    key: 'ctf-team',
    label: '竞赛助理',
    hue: StudioHue.indigo,
  ),
  StudioGroup(
    key: 'sgitai_lan',
    label: '办公助理',
    hue: StudioHue.green,
  ),
];

/// 技能分组 —— 在团队之外多三类（照 React 的 `SKILL_TEAM_META`）。
const studioSkillGroups = <StudioGroup>[
  ...studioTeamGroups,
  StudioGroup(
    key: 'web-offense',
    label: 'Web / 漏洞',
    hue: StudioHue.slate,
  ),
  StudioGroup(
    key: 'design',
    label: '设计',
    hue: StudioHue.gold,
  ),
  StudioGroup(
    key: 'dev',
    label: '研发 / 流程',
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
