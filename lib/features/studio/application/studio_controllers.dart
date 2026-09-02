import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/gateway_repository.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_factory.dart';
import 'package:sgit_studio_flutter/domain/models/studio/relay_models.dart';
import 'package:sgit_studio_flutter/domain/models/studio/resource_item.dart';
import 'package:sgit_studio_flutter/features/studio/application/studio_scope.dart';
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
  });

  final List<ResourceItem> items;
  final bool loading;

  /// 当前显示的是本地缓存，后端还在路上。
  final bool stale;

  final String? error;

  ResourceListState copyWith({
    List<ResourceItem>? items,
    bool? loading,
    bool? stale,
    String? error,
    bool clearError = false,
  }) =>
      ResourceListState(
        items: items ?? this.items,
        loading: loading ?? this.loading,
        stale: stale ?? this.stale,
        error: clearError ? null : (error ?? this.error),
      );
}

/// 通用资源页控制器。**7 个页面共用这一个**，各页只是一份 [ResourcePageSpec]。
class ResourceListController
    extends FamilyNotifier<ResourceListState, ResourcePageSpec> {
  late final GatewayRepository _repo =
      GatewayRepository(ref.read(kernelClientProvider));

  @override
  ResourceListState build(ResourcePageSpec arg) {
    // 首次进页面就拉。刷新按钮走 reload()。
    Future.microtask(reload);
    return const ResourceListState();
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      // 这些列表端点是 GET，没有 cache/sync 两态（数据本来就在本地 .sgitai 目录，
      // 读的就是"本地"）。真正需要 SWR 的是中转站那种要打后端的，见 RelayController。
      final data = await _repo.fetch(arg.listPath);
      state = ResourceListState(
        items: _parse(data),
        loading: false,
        stale: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: _msg(e));
    }
  }

  Future<void> remove(String id) async {
    final path = arg.removePath;
    if (path == null) return;
    try {
      await _repo.post(path, {'id': id});
      await reload();
    } catch (e) {
      state = state.copyWith(error: _msg(e));
    }
  }

  Future<void> refreshOne(String id) async {
    final path = arg.refreshPath;
    if (path == null) return;
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

/// 内核通道 provider。让各仓储共用同一条连接（wasm 侧本来也只有一条）。
final kernelClientProvider = Provider((ref) => createKernelClient());

// ============================================================================
// 大模型中转站（L1 厂商 → L2 模型 → L3 密钥）
// ============================================================================

@immutable
class RelayState {
  const RelayState({
    this.providers = const [],
    this.models = const [],
    this.keys = const [],
    this.selectedProvider,
    this.selectedModel,
    this.loading = true,
    this.stale = false,
    this.error,
  });

  final List<RelayProvider> providers;
  final List<RelayModel> models;
  final List<RelayApiKey> keys;
  final String? selectedProvider;
  final String? selectedModel;
  final bool loading;
  final bool stale;
  final String? error;

  RelayState copyWith({
    List<RelayProvider>? providers,
    List<RelayModel>? models,
    List<RelayApiKey>? keys,
    String? selectedProvider,
    String? selectedModel,
    bool? loading,
    bool? stale,
    String? error,
    bool clearError = false,
    bool clearSelection = false,
  }) =>
      RelayState(
        providers: providers ?? this.providers,
        models: models ?? this.models,
        keys: keys ?? this.keys,
        selectedProvider:
            clearSelection ? null : (selectedProvider ?? this.selectedProvider),
        selectedModel:
            clearSelection ? null : (selectedModel ?? this.selectedModel),
        loading: loading ?? this.loading,
        stale: stale ?? this.stale,
        error: clearError ? null : (error ?? this.error),
      );
}

/// 中转站控制器。**这是唯一走 SWR 两态的页面** —— 它的数据在后端 SeekDB，
/// 本地 silicoid.db 只是缓存（见 memory `relay-silicoiddb-swr-cache`）。
///
/// ## 两个必须守住的约定
///
/// 1. **每个请求都带 `scope`**，读写都要。
/// 2. **读回来要按 `tag` 过滤**：管理版留 `builtin`，个人版留 `custom`。
///    同一个 `model_code` 两个 tag 各一行是**正常的**，不按 tag 过滤就会同时拿到
///    两行 → 改了一行读回另一行，表现为"开关点了不生效"（真踩过，还误判成脏数据）。
///
/// ⚠️ 但 **密钥不按 tag 过滤** —— `relay_api_keys` 表**没有 tag 字段**，
/// 一过滤个人版就永远是空列表（React studio 就有这个 bug，我们不跟）。
/// 密钥的作用域由请求里的 `scope` 在后端决定，前端不再筛。
class RelayController extends Notifier<RelayState> {
  static const _path = '/sgcode-models/manage';

  late final GatewayRepository _repo =
      GatewayRepository(ref.read(kernelClientProvider));

  StudioScope get _scope => ref.read(studioScopeProvider);

  @override
  RelayState build() {
    // 作用域一变，整页数据都得换（管理版和个人版是两套数据）。
    ref.listen(studioScopeProvider, (_, _) => _onScopeChanged());
    Future.microtask(loadProviders);
    return const RelayState();
  }

  /// 切作用域 = 回到 L1 并重拉。留在 L2/L3 没意义：另一个作用域下这个厂商
  /// 可能压根不存在。
  void _onScopeChanged() {
    state = const RelayState();
    loadProviders();
  }

  /// 按当前作用域的 tag 过滤。缺 tag 的历史行按 `builtin`（归管理侧）。
  bool _inScope(String tag) => tag == _scope.tag;

  /// 所有中转站请求的公共字段。
  Map<String, Object?> _base(String group, String method) => {
        'group': group,
        'method': method,
        'scope': _scope.wire,
      };

  Future<void> loadProviders() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      await _repo.swr(
        _path,
        {..._base('model', 'providers')},
        // 个人版数据只在本地 per-cid 库，打后端拿不到也没必要
        // （照 React studio：personal 只读 cache）。
        syncAfterCache: _scope.isMaster,
        onData: (data, {required fresh}) {
          final list = _rows(data['providers'])
              .map(RelayProvider.fromRow)
              .where((p) => _inScope(p.tag))
              .toList()
            // 按显示名排序，和 React studio 的 localeCompare 一致。
            ..sort((a, b) => a.label.compareTo(b.label));
          state = state.copyWith(providers: list, loading: false, stale: !fresh);
        },
        onError: (e) => state = state.copyWith(error: _msg(e), stale: true),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: _msg(e));
    }
  }

  /// 下钻到某厂商的模型（L2）。
  Future<void> openProvider(String code) async {
    state = state.copyWith(
        selectedProvider: code, models: const [], keys: const [], loading: true);
    try {
      await _repo.swr(
        _path,
        {
          ..._base('model', 'list'),
          'provider': code,
          // ⚠️ **必须为 true**。管理页要能看见停用的模型才能把它重新启用；
          // 漏了这个参数停用的模型直接不显示，等于单向操作。
          'include_disabled': true,
        },
        syncAfterCache: _scope.isMaster,
        onData: (data, {required fresh}) {
          state = state.copyWith(
            models: _rows(data['models'])
                .map(RelayModel.fromRow)
                .where((m) => _inScope(m.tag))
                .toList(),
            loading: false,
            stale: !fresh,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: _msg(e));
    }
  }

  /// 打开密钥池（L3）。
  ///
  /// ⚠️ 参数是**厂商代码**，不是模型名 —— 一个厂商下所有模型共用一池密钥。
  /// `apikey/listByModel` 的 `model_code` 收的就是厂商代码（命名很误导）。
  Future<void> openKeyPool(String providerCode) async {
    state = state.copyWith(
        selectedModel: providerCode, keys: const [], loading: true);
    try {
      await _repo.swr(
        _path,
        {..._base('apikey', 'listByModel'), 'model_code': providerCode},
        syncAfterCache: _scope.isMaster,
        onData: (data, {required fresh}) {
          final list = switch (data['data']) {
            final Map<String, Object?> d => d['list'],
            _ => null,
          };
          // 密钥**不按 tag 过滤**（表里没这个字段），见类注释。
          state = state.copyWith(
            keys: _rows(list).map(RelayApiKey.fromRow).toList(),
            loading: false,
            stale: !fresh,
          );
        },
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: _msg(e));
    }
  }

  // ---- 厂商写操作 ----

  /// 切换厂商启用/停用。**乐观更新**，失败回滚重拉。
  Future<void> toggleProvider(RelayProvider p) async {
    _patchProvider(p.code, (x) => x.copyWith(enabled: !p.enabled));
    final ok = await _write('model', 'updateProvider', {
      'model_code': p.code,
      'updates': {'status': p.enabled ? 0 : 1},
    });
    if (!ok) {
      _patchProvider(p.code, (x) => x.copyWith(enabled: p.enabled));
      await loadProviders();
    }
  }

  Future<bool> createProvider(RelayProvider p) async {
    final ok = await _write(
        'model', 'createProvider', {'provider': p.toCreateRow()});
    if (ok) await loadProviders();
    return ok;
  }

  Future<bool> updateProvider(RelayProvider p) async {
    final ok = await _write('model', 'updateProvider',
        {'model_code': p.code, 'updates': p.toUpdates()});
    if (ok) await loadProviders();
    return ok;
  }

  /// 删除厂商。后端在其下仍有模型/密钥时会拒 —— 错误原样显示给用户。
  Future<bool> deleteProvider(String code) async {
    final ok = await _write('model', 'deleteProvider', {'model_code': code});
    if (ok) await loadProviders();
    return ok;
  }

  // ---- 模型写操作 ----

  Future<void> toggleModel(RelayModel m) async {
    _patchModel(m.name, (x) => x.copyWith(available: !m.available));
    final ok = await _write('model', 'update', {
      'provider': m.providerCode,
      // ⚠️ 键名叫 `model_code`，但后端这里收的是**模型名**（React studio 亦然）。
      'model_code': m.name,
      'model': m.copyWith(available: !m.available).toRow(),
    });
    if (!ok) {
      _patchModel(m.name, (x) => x.copyWith(available: m.available));
      final code = state.selectedProvider;
      if (code != null) await openProvider(code);
    }
  }

  Future<bool> createModel(RelayModel m) async {
    final ok = await _write(
        'model', 'create', {'provider': m.providerCode, 'model': m.toRow()});
    if (ok) await openProvider(m.providerCode);
    return ok;
  }

  Future<bool> updateModel(RelayModel m) async {
    final ok = await _write('model', 'update', {
      'provider': m.providerCode,
      'model_code': m.name,
      'model': m.toRow(),
    });
    if (ok) await openProvider(m.providerCode);
    return ok;
  }

  Future<bool> deleteModel(RelayModel m) async {
    // 接口收数组（支持批量），这里一次删一个。
    final ok = await _write('model', 'delete',
        {'provider': m.providerCode, 'model_names': [m.name]});
    if (ok) await openProvider(m.providerCode);
    return ok;
  }

  // ---- 密钥写操作 ----

  Future<bool> createKey(String providerCode, String apiKey,
      {String name = ''}) async {
    final ok = await _write('apikey', 'create', {
      'model_code': providerCode,
      'api_key': apiKey,
      if (name.isNotEmpty) 'key_name': name,
    });
    if (ok) await openKeyPool(providerCode);
    return ok;
  }

  Future<bool> deleteKey(String providerCode, String id) async {
    final ok = await _write('apikey', 'hardDelete', {
      // 后端要 number 型 id。
      'id': int.tryParse(id) ?? id,
      'model_code': providerCode,
    });
    if (ok) await openKeyPool(providerCode);
    return ok;
  }

  /// 同步某厂商的模型列表（从上游拉最新）。
  ///
  /// ⚠️ 厂商停用时后端会拒 —— 这是"同步模型失败"最常见的原因
  /// （memory `relay-sync-blocked-by-provider-status`），所以按钮在停用时要禁用
  /// 并说明原因，别让用户对着"同步失败"猜。
  Future<void> syncProvider(String code) async {
    state = state.copyWith(loading: true, clearError: true);
    if (await _write('model', 'sync', {'provider': code})) {
      await openProvider(code);
    } else {
      state = state.copyWith(loading: false);
    }
  }

  /// 所有写操作的唯一出口。返回是否成功；失败时错误已进 [state]。
  Future<bool> _write(
      String group, String method, Map<String, Object?> params) async {
    try {
      final r = await _repo.post(_path, {..._base(group, method), ...params});
      if (r['status'] != 'success') {
        throw Exception(r['message'] ?? '操作失败');
      }
      state = state.copyWith(clearError: true);
      return true;
    } catch (e) {
      state = state.copyWith(error: _msg(e), loading: false);
      return false;
    }
  }

  void _patchProvider(
      String code, RelayProvider Function(RelayProvider) f) {
    state = state.copyWith(providers: [
      for (final x in state.providers)
        if (x.code == code) f(x) else x,
    ]);
  }

  void _patchModel(String name, RelayModel Function(RelayModel) f) {
    state = state.copyWith(models: [
      for (final x in state.models)
        if (x.name == name) f(x) else x,
    ]);
  }

  /// 返回上一级。
  void back() {
    if (state.selectedModel != null) {
      state = RelayState(
        providers: state.providers,
        models: state.models,
        selectedProvider: state.selectedProvider,
        loading: false,
      );
    } else {
      state = RelayState(providers: state.providers, loading: false);
    }
  }

  static List<Map<String, Object?>> _rows(Object? v) => switch (v) {
        final List<Object?> l =>
          l.whereType<Map>().map((m) => m.cast<String, Object?>()).toList(),
        _ => const [],
      };
}

final relayProvider =
    NotifierProvider<RelayController, RelayState>(RelayController.new);

String _msg(Object e) =>
    e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
