import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/gateway_repository.dart';
import 'package:sgit_studio_flutter/data/repositories/settings_repository.dart';
import 'package:sgit_studio_flutter/domain/models/studio/resource_item.dart';
import 'package:sgit_studio_flutter/features/studio/application/kernel_client_provider.dart';
import 'package:sgit_studio_flutter/features/studio/application/settings_repository_provider.dart';
import 'package:sgit_studio_flutter/features/studio/studio_page_specs.dart';

/// 一个 studio 页面的数据状态。**三态齐全**（加载中 / 出错 / 数据），
/// 而且 [stale] 让界面能标出"这是缓存，正在刷新"。
@immutable
class ResourceListState {
  const ResourceListState({
    this.items = const [],
    this.loading = true,
    this.stale = false,
    this.error,
    this.unsyncedIds = const {},
    this.syncing = false,
  });

  final List<ResourceItem> items;
  final bool loading;

  /// 当前显示的是本地缓存，后端还在路上。
  final bool stale;

  final String? error;

  /// 本地已改、尚未上行到服务器的项。仅桌面/移动有值 —— Web 本身就在服务器上。
  final Set<String> unsyncedIds;

  /// 正在跑一次全量同步。
  final bool syncing;

  ResourceListState copyWith({
    List<ResourceItem>? items,
    bool? loading,
    bool? stale,
    String? error,
    bool clearError = false,
    Set<String>? unsyncedIds,
    bool? syncing,
  }) =>
      ResourceListState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        stale: stale ?? this.stale,
        error: clearError ? null : (error ?? this.error),
        unsyncedIds: unsyncedIds ?? this.unsyncedIds,
        syncing: syncing ?? this.syncing,
      );
}

/// 通用资源页控制器。**7 个页面共用这一个**，各页只是一份 [ResourcePageSpec]。
///
/// ## 两个数据源，各管一半
///
/// - [_repo]（gateway）：**展示数据** —— 名称、描述、开关、各页专属字段。
///   spec 驱动的字段映射都在这条路上。
/// - [_settings]（FFI / gateway）：**同步状态** —— 哪些项本地改了还没上行。
///
/// 为什么不合成一条：gateway 的列表端点回的是结构化资源（含 spec 要的全部字段），
/// 而 settings 接口按文件粒度只知道 id 与 sha。两者粒度不同，硬并会丢字段。
/// 所以展示照旧、同步状态叠加上去。
class ResourceListController
    extends FamilyNotifier<ResourceListState, ResourcePageSpec> {
  late final GatewayRepository _repo =
      GatewayRepository(ref.read(kernelClientProvider));
  late final SettingsRepository _settings =
      ref.read(settingsRepositoryProvider);

  /// 本页资源在 settings 接口里的类别名。null = 该页不参与配置同步
  /// （MCP 在 config.toml 里、知识库是文件不是配置）。
  String? get _kind => switch (arg.key) {
        'scenes' => 'scenes',
        'subagent' => 'agents',
        'skill' => 'skills',
        _ => null,
      };

  @override
  ResourceListState build(ResourcePageSpec arg) {
    ref.onDispose(() => _disposed = true);
    // 首次进页面：自动刷（不 force，允许与刚才那次合并）。
    Future.microtask(reload);
    return const ResourceListState();
  }

  /// SWR：先本地秒回，再后台刷新。
  ///
  /// ```text
  /// ① readPage()     本地读（桌面是 FFI 直读文件+sqlite，零网络）→ 立刻出数据
  /// ② refreshPage()  后台打 Go → changed 为真则重读一次
  /// ```
  ///
  /// **第 ② 步失败不报错**：界面已有内容，断网时弹错比"数据稍旧"糟得多。
  /// 仓储层已经把异常吞成 `ok:false`，这里只需不去理它。
  ///
  /// [force] 为真表示用户主动点了刷新按钮 —— 桌面端会跳过合并窗口真跑一次。
  Future<void> reload({bool force = false}) async {
    state = state.copyWith(loading: true, clearError: true);

    // ---- ① 本地 ----
    try {
      final data = await _settings.readPage(arg.key);
      // ⚠️ **立刻出数据，不等同步角标。**
      //
      // 原先这里 `unsyncedIds: await _loadUnsynced()` —— 那是第二次 FFI
      // （`sgit_settings_list`，技能页 1276 项），把"秒回"硬生生拖成两次
      // 往返之后。角标只是卡片右上角一个小点，让整页内容等它毫无道理。
      state = ResourceListState(items: _parse(data), loading: false);
    } catch (e) {
      // 本地读失败是真错误（未登录、目录坏了）—— 必须报出来，
      // 否则用户只看到一个空页面、不知道为什么。
      state = state.copyWith(loading: false, error: _msg(e));
      return;
    }

    // 角标单独补，不挡主内容。
    unawaited(_refreshBadges());

    // ---- ② 后台刷新 ----
    final out = await _settings.refreshPage(arg.key, force: force);
    if (!out.ok || !out.changed) return;

    // 服务器侧有变化，重读一次本地。这次不动 loading ——
    // 界面已有内容，转圈会闪。
    try {
      final data = await _settings.readPage(arg.key);
      state = state.copyWith(items: _parse(data));
      unawaited(_refreshBadges());
    } catch (_) {
      // 重读失败就留着第 ① 步的数据，不退化成错误态。
    }
  }

  /// 补同步角标。失败/过期都静默丢弃 —— 它不值得打断任何东西。
  Future<void> _refreshBadges() async {
    final ids = await _loadUnsynced();
    // 角标是"事后补"的，回来时页面可能已经关了 —— notifier 被 dispose 后
    // 再写 state 会抛。这条异步链没人 await，抛出去就是一条无人接的错误。
    if (_disposed) return;
    state = state.copyWith(unsyncedIds: ids);
  }

  bool _disposed = false;

  /// 取本页未同步项的 id 集合。
  ///
  /// best-effort：**失败一律当"全部已同步"**，不把错误冒泡到列表 ——
  /// 同步状态只是个角标，为它让整页报错不划算。
  Future<Set<String>> _loadUnsynced() async {
    final kind = _kind;
    if (kind == null || !_settings.hasLocalCopy) return const {};
    try {
      final entries = await _settings.list(kind);
      return entries.where((e) => !e.synced).map((e) => e.id).toSet();
    } catch (_) {
      return const {};
    }
  }

  /// 写一项配置：先服务器、后本地（语义在 Rust 侧，见 settings.rs）。
  ///
  /// 服务器不可达时**不算失败** —— 本地已保存并排队，这里只把它标成未同步。
  Future<void> write(String id, String content) async {
    final kind = _kind;
    if (kind == null) {
      state = state.copyWith(error: '该页不支持编辑');
      return;
    }
    try {
      final entry = await _settings.write(kind, id, content);
      final next = {...state.unsyncedIds};
      if (entry.synced) {
        next.remove(id);
      } else {
        next.add(id);
      }
      state = state.copyWith(unsyncedIds: next, clearError: true);
      await reload();
    } catch (e) {
      state = state.copyWith(error: _msg(e));
    }
  }

  /// 全量同步：重放脏队列 + 与服务器对账。返回结果供界面提示。
  Future<SyncOutcome> sync() async {
    if (!_settings.hasLocalCopy) return const SyncOutcome(ok: true);
    state = state.copyWith(syncing: true, clearError: true);
    try {
      final out = await _settings.sync();
      state = state.copyWith(syncing: false);
      // 同步后列表可能变了（拉下来新项、冲突覆盖），重取。
      await reload();
      return out;
    } catch (e) {
      state = state.copyWith(syncing: false, error: _msg(e));
      return SyncOutcome(ok: false, reason: _msg(e));
    }
  }

  /// 删一项。走 [SettingsRepository] —— 桌面是「先服务器后本地」，
  /// **不打 gateway**（那条路只服务云上沙箱）。
  Future<void> remove(String id) async {
    if (arg.removePath == null) return;
    try {
      await _settings.removeFromPage(arg.key, id);
      await reload();
    } catch (e) {
      state = state.copyWith(error: _msg(e));
    }
  }

  /// 批量删除（历史对话「全选删除」用）。逐个删 —— 没有批量接口，
  /// 串行是唯一安全的做法；结束后统一 reload 一次，不必每删一条就刷一次列表。
  Future<void> removeMany(Iterable<String> ids) async {
    if (arg.removePath == null) return;
    try {
      for (final id in ids) {
        await _settings.removeFromPage(arg.key, id);
      }
      await reload();
    } catch (e) {
      state = state.copyWith(error: _msg(e));
    }
  }

  /// 「从母版重置」单项。
  ///
  /// ⚠️ 桌面端**暂不支持** —— 母版只在服务器上，重置需要一个新的 Go 接口
  /// （见计划里"不在本轮"）。所以这里只在 Web 上走原有 gateway 端点；
  /// 桌面按钮由 `spec.refreshPath == null` 之外的条件隐藏，见 resource_list_page。
  Future<void> refreshOne(String id) async {
    final path = arg.refreshPath;
    if (path == null || _settings.hasLocalCopy) return;
    try {
      await _repo.post(path, {'id': id});
      await reload();
    } catch (e) {
      state = state.copyWith(error: _msg(e));
    }
  }

  List<ResourceItem> _parse(Map<String, Object?> data) {
    final raw = data[arg.listField];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((m) {
      final r = m.cast<String, Object?>();
      return ResourceItem(
        id: r[arg.idField]?.toString() ?? '',
        name: r[arg.nameField]?.toString() ?? '',
        description: r[arg.descField]?.toString() ?? '',
        enabled: switch (arg.enabledField) {
          final String f => r[f] == true || r[f] == 1,
          null => null,
        },
        extras: {for (final f in arg.extraFields) f: r[f]},
      );
    }).toList(growable: false);
  }
}

final resourceListProvider = NotifierProvider.family<ResourceListController,
    ResourceListState, ResourcePageSpec>(ResourceListController.new);

String _msg(Object e) =>
    e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
