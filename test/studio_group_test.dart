import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/domain/models/studio/studio_group.dart';

/// 分组逻辑的契约测试。
///
/// 这套 key 与 React studio 的 `TEAM_META`（`sgcodeGlass.ts:58`）必须一致 ——
/// 它们同时也是后端 per-cid 目录的目录名（`scenes/blueteam-defense/…`）。
/// 对不上的后果是静默的：条目全落进「通用」，页面看着像没分组。
void main() {
  group('分组表', () {
    test('团队分组 key 与后端目录名一致', () {
      expect(
        studioTeamGroups.map((g) => g.key).toList(),
        ['redteam-ops', 'blueteam-defense', 'ctf-team', 'sgitai_lan'],
      );
    });

    test('技能分组 = 团队分组 + 三类', () {
      expect(
        studioSkillGroups.map((g) => g.key).toList(),
        [
          'redteam-ops',
          'blueteam-defense',
          'ctf-team',
          'sgitai_lan',
          'web-offense',
          'design',
          'dev',
        ],
      );
    });

    test('只有技能页用扩展分组', () {
      expect(studioGroupsFor('skill'), studioSkillGroups);
      for (final p in ['scenes', 'subagent', 'mcp', 'memory']) {
        expect(studioGroupsFor(p), studioTeamGroups, reason: '$p 应用团队分组');
      }
    });
  });

  group('groupByIdPrefix', () {
    List<String> ids(List<StudioGroupBucket<String>> bs) =>
        bs.map((b) => b.group.key).toList();

    test('按 id 首段归组，顺序 follow 分组表', () {
      // 刻意打乱输入顺序 —— 输出该按分组表排，不是按输入排。
      final items = [
        'sgitai_lan/office',
        'redteam-ops/recon',
        'blueteam-defense/audit',
      ];
      final buckets = groupByIdPrefix(items, studioTeamGroups, (s) => s);
      expect(ids(buckets), ['redteam-ops', 'blueteam-defense', 'sgitai_lan']);
    });

    test('空组跳过 —— 否则页面挂一串「渗透助理 · 0」的空标题', () {
      final buckets = groupByIdPrefix(
        ['blueteam-defense/a'],
        studioTeamGroups,
        (s) => s,
      );
      expect(buckets.length, 1);
      expect(buckets.single.group.key, 'blueteam-defense');
    });

    test('未知首段进「通用」，且通用排最后', () {
      final buckets = groupByIdPrefix(
        ['unknown-team/x', 'redteam-ops/y'],
        studioTeamGroups,
        (s) => s,
      );
      expect(ids(buckets), ['redteam-ops', '__general__']);
    });

    test('没有斜杠的 id 进「通用」', () {
      // scenes/top.toml 这种顶层文件，id 就是 `top` —— 它不是分组名。
      final buckets = groupByIdPrefix(['top'], studioTeamGroups, (s) => s);
      expect(buckets.single.group.key, '__general__');
    });

    /// 尾斜杠语义：`redteam-ops-pro/x` 的首段是 `redteam-ops-pro`，
    /// 不该被 `redteam-ops` 吃掉。（Rust/Go 侧的授权匹配也有同一个坑。）
    test('同前缀的不同分组不串', () {
      final buckets = groupByIdPrefix(
        ['redteam-ops-pro/x', 'redteam-ops/y'],
        studioTeamGroups,
        (s) => s,
      );
      expect(ids(buckets), ['redteam-ops', '__general__']);
      expect(
        buckets.firstWhere((b) => b.group.key == 'redteam-ops').items,
        ['redteam-ops/y'],
        reason: 'redteam-ops-pro 不该混进 redteam-ops',
      );
    });

    test('多层 id 只看首段', () {
      final buckets = groupByIdPrefix(
        ['blueteam-defense/sub/deep/item'],
        studioTeamGroups,
        (s) => s,
      );
      expect(buckets.single.group.key, 'blueteam-defense');
    });

    test('空输入回空列表', () {
      expect(groupByIdPrefix(<String>[], studioTeamGroups, (s) => s), isEmpty);
    });

    test('同组多条保持输入内的相对顺序', () {
      final buckets = groupByIdPrefix(
        ['redteam-ops/b', 'redteam-ops/a', 'redteam-ops/c'],
        studioTeamGroups,
        (s) => s,
      );
      // 排序由数据源负责（Rust 侧已按 id 排），分组不该再打乱。
      expect(buckets.single.items,
          ['redteam-ops/b', 'redteam-ops/a', 'redteam-ops/c']);
    });
  });
}
