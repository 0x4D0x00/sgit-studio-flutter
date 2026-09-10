import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/gateway_repository.dart';
import 'package:sgit_studio_flutter/domain/models/studio/relay_models.dart';
import 'package:sgit_studio_flutter/features/studio/application/kernel_client_provider.dart';

/// 输入框「可用 chat 模型」的数据源 —— 与 React studio 的 `useEnabledChatModels`
/// **同一套取法**（两端读同一份 relay 三表，取法不一致就会两边显示不同）。
///
/// ## 取法（照 studio，四个细节都不能省）
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
}

/// 可用模型列表。SWR：先 cache 秒回，再 sync 刷新。
class ModelListController extends Notifier<ModelListState> {
  static const _path = '/sgcode-models/manage';

  late final GatewayRepository _repo =
      GatewayRepository(ref.read(kernelClientProvider));

  @override
  ModelListState build() {
    Future.microtask(load);
    return const ModelListState();
  }

  Future<void> load() async {
    // 先 cache 秒回。
    try {
      final cached = await _build('cache');
      if (cached.isNotEmpty) {
        state = ModelListState(groups: cached, loading: false, stale: true);
      }
    } catch (_) {
      // 本地没缓存是常态，交给下面的 sync。
    }

    try {
      state = ModelListState(groups: await _build('sync'), loading: false);
    } catch (e) {
      // 取不到模型**不该挡住对话** —— 不选模型时内核用默认的。
      debugPrint('[models] 取模型列表失败：$e');
      state = ModelListState(groups: state.groups, loading: false);
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
      final pr = await _repo.post(_path,
          {'group': 'model', 'method': 'providers', 'mode': mode, 'scope': scope});

      final providers = _rows(pr['providers'])
          .map(RelayProvider.fromRow)
          // 只留启用厂商；并按 tag 分到各自的 scope（两 scope 读同一张表）。
          .where((p) => p.enabled && p.isCustom == isPersonal)
          .toList();

      // 各厂商的模型并发取 —— 串行会让厂商多时首屏很慢。
      final groups = await Future.wait(providers.map((p) async {
        final mr = await _repo.post(_path, {
          'group': 'model',
          'method': 'list',
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
    } catch (_) {
      // 任一 scope 失败不拖累另一侧。
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
