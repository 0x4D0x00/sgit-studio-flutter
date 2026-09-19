import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/data/repositories/settings_repository.dart';

import 'fakes/fake_settings_repository.dart';

/// 配置同步的契约测试。
///
/// 这里测的是 **Dart 侧对语义的理解**，不是 Rust 的实现 —— 后者有自己的单测
/// （`sgit-ffi/src/settings.rs`）。重点在那几条容易写反的约定。
void main() {
  group('SettingsEntry 的 synced 语义', () {
    test('默认已同步 —— 缺字段时不该给每一项都打角标', () {
      const e = SettingsEntry(id: 'a');
      expect(e.synced, isTrue);
    });

    test('未同步不等于失败：内容与 sha 照常有值', () {
      const e = SettingsEntry(id: 'a', sha256: 'deadbeef', synced: false);
      // 本地已写入、已排队。界面该打角标，但不该报错。
      expect(e.synced, isFalse);
      expect(e.sha256, isNotEmpty);
    });
  });

  group('SyncOutcome', () {
    test('无冲突时 conflicts 为空', () {
      const o = SyncOutcome(ok: true, pushed: 2, pulled: 1);
      expect(o.conflicts, isEmpty);
      expect(o.pushed, 2);
      expect(o.pulled, 1);
    });

    test('冲突项带备份文件名 —— 用户能捞回自己那份', () {
      const o = SyncOutcome(
        ok: true,
        conflicts: [
          SyncConflict(kind: 'scenes', id: 'a', backup: 'a.conflict.toml'),
        ],
      );
      expect(o.conflicts.single.backup, 'a.conflict.toml');
      // 冲突**不是**失败：服务器版本已生效，同步本身成功了。
      expect(o.ok, isTrue);
    });

    test('失败时带原因', () {
      const o = SyncOutcome(ok: false, reason: '服务器不可达');
      expect(o.ok, isFalse);
      expect(o.reason, isNotEmpty);
    });
  });

  group('Web 实现的边界', () {
    test('无本地副本时 sync 是 no-op 且恒成功', () async {
      final repo = FakeSettingsRepository(hasLocalCopy: false);
      final out = await repo.sync();
      expect(out.ok, isTrue);
      expect(out.pushed, 0);
      expect(out.pulled, 0);
    });
  });

  group('未同步项的筛选', () {
    test('只有 synced=false 的项进角标集合', () async {
      final repo = FakeSettingsRepository(entries: {
        'scenes': const [
          SettingsEntry(id: 'clean'),
          SettingsEntry(id: 'dirty', synced: false),
          SettingsEntry(id: 'also-dirty', synced: false),
        ],
      });

      final entries = await repo.list('scenes');
      final unsynced =
          entries.where((e) => !e.synced).map((e) => e.id).toSet();

      expect(unsynced, {'dirty', 'also-dirty'});
      expect(unsynced, isNot(contains('clean')));
    });

    test('类别没有条目时是空集，不是 null', () async {
      final repo = FakeSettingsRepository();
      expect(await repo.list('scenes'), isEmpty);
    });
  });

  group('refreshPage 的 force 语义', () {
    test('默认不 force —— 进页面的自动刷新可以被合并窗口吞掉', () async {
      final repo = FakeSettingsRepository();
      await repo.refreshPage('scenes');
      expect(repo.calls, ['refreshPage:scenes']);
    });

    test('force 会带上去 —— 用户点的刷新按钮必须真跑', () async {
      final repo = FakeSettingsRepository();
      await repo.refreshPage('scenes', force: true);
      // 桌面端受管资源那条路一次覆盖全部目录，自动刷 15 秒内合并成一次；
      // 按钮若也被合并，点了就没反应，像坏了 —— 所以这个标志必须传到底。
      expect(repo.calls, ['refreshPage:scenes:force']);
    });
  });
}
