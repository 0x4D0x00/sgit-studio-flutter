import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/settings_repository.dart';
import 'package:sgit_studio_flutter/domain/models/studio/relay_models.dart';
import 'package:sgit_studio_flutter/features/studio/application/settings_repository_provider.dart';

/// 输入框「可用 chat 模型」的数据源 —— 与中转站页**读同一份数据、走同一条路**。
///
/// ## ⚠️ 必须走 [SettingsRepository]，不是 `GatewayRepository`
///
/// 这里踩过一次很难发现的坑：中转站页（[RelayController]）已经改成
/// `SettingsRepository.relayManage`（桌面 FFI 直读本机 silicoid.db），而本控制器
/// 还留在 `GatewayRepository.post('/sgcode-models/manage')`。于是**同一批模型、
/// 同一个账号**：
///
/// ```text
/// 中转站页   → FFI 直读本地   → 模型都在
/// 输入框     → 打 gateway     → 本地模式下打不通 → 「暂无可用模型」
/// ```
///
/// 而 [_scope] 的 catch 会把失败咽掉回空列表，所以没有任何报错 —— 用户看到的
/// 只是"我明明有模型，输入框说没有"。两个入口读同一份数据就必须共用同一条路，
/// 否则本地/云端两种模式里总有一个是坏的。
///
/// `relayManage` 两个实现同形：桌面 `sgit_relay_manage`（本地），Web 转发
/// gateway 的同一端点 —— 所以换过来不影响 Web。
///
/// ## 取法（照 React studio 的 `useEnabledChatModels`，四个细节都不能省）
/// 1. **先取厂商、再逐个取模型** —— `method:'list'` 不带 `provider` 时后端拿到空 code，
///    什么都查不到（我第一版就是这么写的，结果选择器永远是空、静默隐藏）；
/// 2. **`scope='master'`** —— 否则网关按 personal 短路直读 per-cid、**永不 sync**，
///    导致「管理页改了厂商启停，输入框看不到」；
/// 3. **只留启用厂商**（`status==1`），停用厂商整组不出现；
/// 4. **客户端再滤一遍** `is_available` / `deprecated` —— cache 模式返回的是全部模型
///    （含停用），不滤就会在秒回时闪一下已停用的模型。
///
/// 个人模型（`scope='personal'`, tag=custom）另取一份并入：它只落本 cid 的
/// silicoid.db、不上服务器，发消息时由沙箱内 sgcode **直连厂商**。
/// id 带 [personalModelPrefix] 前缀与平台同名模型区分，网关在 `thread/start` 时剥掉。
const String personalModelPrefix = 'personal:';

/// 一个厂商 + 它下面的可用模型。
@immutable
class ModelGroup {
  const ModelGroup({
    required this.id,
    required this.name,
    required this.models,
    required this.isPersonal,
  });

  final String id;
  final String name;
  final List<ModelChoice> models;
  final bool isPersonal;
}

/// 下拉里的一个模型。
@immutable
class ModelChoice {
  const ModelChoice({
    required this.id,
    required this.displayName,
    this.contextWindow,
  });

  /// 发消息时用的路由标识。个人模型带 `personal:` 前缀。
  final String id;
  final String displayName;
  final int? contextWindow;
}

@immutable
class ModelListState {
  const ModelListState({
    this.groups = const [],
    this.loading = true,
    this.stale = false,
  });

  final List<ModelGroup> groups;
  final bool loading;

  /// 显示的是本地缓存，后台正在 sync。
  final bool stale;

  bool get isEmpty => groups.every((g) => g.models.isEmpty);

  /// 按 id 找。找不到返回 null（模型被停用/删除后要能优雅回落到默认）。
  ModelChoice? find(String? id) {
    if (id == null) return null;
    for (final g in groups) {
      for (final m in g.models) {
        if (m.id == id) return m;
      }
    }
    return null;
  }

  /// 列表里的第一个可用模型 —— **没选过时实际会用的那个**。
  ///
  /// 顺序即优先级：`_build` 先放平台（master）后放个人（personal），平台侧由
  /// silicoid 的 priority 排出，与网关 `resolve_default_model` 同口径。
  ModelChoice? get first {
    for (final g in groups) {
      if (g.models.isNotEmpty) return g.models.first;
    }
    return null;
  }

  /// 界面该显示哪个模型。
  ///
  /// 规则：用户选的，否则列表第一个；列表为空返回 null（调用方据此拒绝发送）。
  /// **不存在「默认模型」这个概念**，发送与显示都用这一个结果。
  /// React studio 的 ModelLabel 同样如此（`hasStored ? stored : firstModel?.id`）。
  ModelChoice? effective(String? selected) => find(selected) ?? first;
}

/// 可用模型列表。SWR：先 cache 秒回，再 sync 刷新。
class ModelListController extends Notifier<ModelListState> {
  late final SettingsRepository _settings =
      ref.read(settingsRepositoryProvider);

  @override
  ModelListState build() {
    Future.microtask(load);
    return const ModelListState();
  }

  Future<void> load() async {
    // 先 cache 秒回。这一路是**纯本地** FFI 读，断网也能出数据。
    try {
      final cached = await _build('cache');
      if (cached.isNotEmpty) {
        state = ModelListState(groups: cached, loading: false, stale: true);
      }
    } catch (_) {
      // 本地没缓存是常态，交给下面的 sync。
    }

    // 再 sync 刷新。这一路**要打后端**（浏览器加密握手 → nonce），本地模式 /
    // 断网时必然失败。
    try {
      final fresh = await _build('sync');

      // ⚠️ **sync 的结果不能无条件盖掉 cache。**
      //
      // 这里踩过一次：原本直接 `state = ModelListState(groups: await _build('sync'))`。
      // 看着像"有异常会被下面的 catch 接住"，但 `_scope()` 的 catch 把失败**咽掉
      // 回空列表**（那是对的：一个 scope 挂了不该拖累另一个），所以 sync 失败时
      // 根本不抛异常 —— 而是拿一个空列表**盖掉 cache 刚读出来的好数据**。
      //
      // 实测表现：中转站页和输入框同时「暂无可用模型」，而 DLL 探针单独调
      // `sgit_relay_manage` 一切正常：
      //   cache/master  len=6597  ✅
      //   sync/master   {"error":"Request failed: Failed to get nonce"}  ❌
      //
      // 本地模式下 sync 永远打不通，所以这个 bug 在本地模式里是**必现**的。
      //
      // 而且不能只判"合并后是否为空"：`_build` 是两路合并，**personal 固定走 cache**
      // （个人模型只落本地），master 挂掉时合并结果仍然非空 —— 只是平台模型全没了。
      // 所以按**平台组（非 personal）有没有丢**来判断。
      final hadPlatform = state.groups.any((g) => !g.isPersonal);
      final freshHasPlatform = fresh.any((g) => !g.isPersonal);

      if (freshHasPlatform || !hadPlatform) {
        state = ModelListState(groups: fresh, loading: false);
      } else {
        // 平台模型丢了 = sync 没成。保留 cache 的结果，只把 loading 收掉。
        debugPrint('[models] sync 未取到平台模型（本地模式/断网属正常），沿用本地缓存');
        state = ModelListState(
          groups: state.groups,
          loading: false,
          stale: true,
        );
      }
    } catch (e) {
      // 取不到模型**不该挡住对话** —— 不选模型时内核用默认的。
      debugPrint('[models] 取模型列表失败：$e');
      state = ModelListState(
        groups: state.groups,
        loading: false,
        stale: state.groups.isNotEmpty,
      );
    }
  }

  Future<List<ModelGroup>> _build(String mode) async {
    // 个人模型永远只读本地 per-cid 库（网关对 scope=personal 短路，不打后端），
    // 故 personal 侧固定 cache。两侧互不影响：个人库没数据是常态。
    final results = await Future.wait([
      _scope(mode, 'master'),
      _scope('cache', 'personal'),
    ]);
    return [...results[0], ...results[1]];
  }

  Future<List<ModelGroup>> _scope(String mode, String scope) async {
    final isPersonal = scope == 'personal';
    try {
      final pr = await _settings
          .relayManage('model', 'providers', {'mode': mode, 'scope': scope});

      final providers = _rows(pr['providers'])
          .map(RelayProvider.fromRow)
          // 只留启用厂商；并按 tag 分到各自的 scope（两 scope 读同一张表）。
          .where((p) => p.enabled && p.isCustom == isPersonal)
          .toList();

      // 各厂商的模型并发取 —— 串行会让厂商多时首屏很慢。
      final groups = await Future.wait(providers.map((p) async {
        final mr = await _settings.relayManage('model', 'list', {
          'provider': p.code,
          'mode': mode,
          'scope': scope,
        });
        final models = _rows(mr['models'])
            .map(RelayModel.fromRow)
            // cache 模式返回全部（含停用），客户端补一刀与 sync 对齐。
            .where((m) => m.available && m.isCustom == isPersonal)
            .map((m) => ModelChoice(
                  id: isPersonal ? '$personalModelPrefix${m.name}' : m.name,
                  displayName: m.displayName,
                  contextWindow: m.contextWindow,
                ))
            .toList();
        if (models.isEmpty) return null; // 无可用模型的厂商不显示空组
        return ModelGroup(
          id: isPersonal ? '$personalModelPrefix${p.code}' : p.code,
          name: isPersonal ? '${p.name} · 个人直连' : p.name,
          models: models,
          isPersonal: isPersonal,
        );
      }));

      return groups.whereType<ModelGroup>().toList();
    } catch (e) {
      // 任一 scope 失败不拖累另一侧 —— 个人库没数据是常态，不该让平台那路也空掉。
      //
      // ⚠️ **但一定要留下日志。** 这里原先是 `catch (_) { return const []; }`，
      // 一个字都不打。于是「登录着、模型也在本地、输入框却说暂无可用模型」这个故障
      // 在日志里**完全不可见** —— 排查时只能靠猜，实测花了很久才定位到是
      // Rust 侧 `session()` 的并发竞态（见 sgit-ffi/src/lib.rs 那段注释）。
      // 静默回落是对的，静默到没有任何痕迹不是。
      debugPrint('[models] 取 $scope/$mode 失败（该组按空处理）：$e');
      return const [];
    }
  }

  static List<Map<String, Object?>> _rows(Object? v) => switch (v) {
        final List<Object?> l =>
          l.whereType<Map>().map((m) => m.cast<String, Object?>()).toList(),
        _ => const [],
      };
}

final modelListProvider =
    NotifierProvider<ModelListController, ModelListState>(ModelListController.new);
