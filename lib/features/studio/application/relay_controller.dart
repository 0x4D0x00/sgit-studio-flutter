import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/settings_repository.dart';
import 'package:sgit_studio_flutter/domain/models/studio/relay_models.dart';
import 'package:sgit_studio_flutter/features/studio/application/settings_repository_provider.dart';

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
    this.selectedIsCustom = false,
    this.selectedModel,
    this.loading = true,
    this.stale = false,
    this.error,
  });

  final List<RelayProvider> providers;
  final List<RelayModel> models;
  final List<RelayApiKey> keys;
  /// 下钻中的厂商 `model_code`。
  ///
  /// ⚠️ **code 不唯一** —— 同一个 `model_code` 的平台行与自建行并存是现网常态
  /// （Qwen 既有平台的 Alibaba、也有用户自建的 Alibaba（个人））。所以定位一行
  /// 要 `(code, tag)` 两个字段，只按 code 查会拿到排在前面那条，
  /// 后续请求就带错 scope、读到另一批数据。
  final String? selectedProvider;

  /// 下钻中的厂商是不是自建行。与 [selectedProvider] 一起才是完整身份。
  final bool selectedIsCustom;

  final String? selectedModel;
  final bool loading;
  final bool stale;
  final String? error;

  RelayState copyWith({
    List<RelayProvider>? providers,
    List<RelayModel>? models,
    List<RelayApiKey>? keys,
    String? selectedProvider,
    bool? selectedIsCustom,
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
        selectedIsCustom: clearSelection
            ? false
            : (selectedIsCustom ?? this.selectedIsCustom),
        selectedModel:
            clearSelection ? null : (selectedModel ?? this.selectedModel),
        loading: loading ?? this.loading,
        stale: stale ?? this.stale,
        error: clearError ? null : (error ?? this.error),
      );
}

/// 中转站控制器 —— **只做个人页**（照 React studio 的 personal 视图）。
///
/// ## 个人页展示什么
///
/// 两类，缺一不可（照 `LlmRelayPanel.tsx::keepProvidersByScope`）：
///
/// | | 来源 | 可改吗 |
/// |---|---|---|
/// | **平台开放的厂商** `tag=builtin` 且 `status=1` | 管理侧下发 | **只读** |
/// | **自己配的** `tag=custom` | 用户自建，落本地 per-cid silicoid.db | 可增删改 |
///
/// 用户在这一页要回答的是"我这个账号实际能用哪些模型" —— 平台开放给他的那些
/// 当然算。**停用的平台厂商（status=0）不展示**：那是管理面的事，摆在个人页只是噪音
/// （现网 19 个平台厂商里 17 个是停用的，全列出来这页就没法看了）。
///
/// ⚠️ 早先这里写的是"个人版只留 `tag=custom`"，那会把平台开放的厂商全滤掉 ——
/// 用户明明能用的模型一个都看不见。
///
/// ## 平台行必须挡住写
///
/// 这一页的写**一律落 `tag=custom`**。所以改一个平台行不是"改"，而是新建一条
/// 同名 custom 影子行 —— 同名双行，上下文窗口与密钥就此串味；删厂商更会级联
/// 删掉该品牌的平台模型。界面禁用按钮只是体验层，[_write] 里还有一道 fail-closed。
///
/// ## 密钥不按 tag 过滤
///
/// `relay_api_keys` 表**没有 tag 字段**，一过滤就永远是空列表
/// （React studio 有这个 bug，我们不跟）。密钥按 `model_code` 归属厂商。
class RelayController extends Notifier<RelayState> {
  late final SettingsRepository _settings =
      ref.read(settingsRepositoryProvider);

  @override
  RelayState build() {
    Future.microtask(loadProviders);
    return const RelayState();
  }

  /// SWR：先读本地缓存秒回，再打后端拿 fresh。
  ///
  /// [force] 目前只影响是否显示"正在刷新"，两趟都会跑 —— 中转站的刷新是
  /// 按厂商粒度的请求，没有受管资源那种全量对账，不需要合并窗口。
  Future<void> loadProviders({bool force = false}) async {
    state = state.copyWith(loading: true, clearError: true);

    // ---- ① cache：纯本地，秒回 ----
    try {
      final cached = await _fetchProviders('cache');
      if (cached.isNotEmpty) {
        state = state.copyWith(providers: cached, loading: false, stale: true);
      }
    } catch (_) {
      // 本地没缓存是常态（首次登录），交给下面的 sync。
    }

    // ---- ② sync：平台那路打后端拿 fresh 并写回本地 ----
    try {
      final fresh = await _fetchProviders('sync');
      state = state.copyWith(providers: fresh, loading: false, stale: false);
    } catch (e) {
      // 已有缓存内容时不退化成错误态 —— 断网只是"数据稍旧"。
      state = state.providers.isEmpty
          ? state.copyWith(loading: false, error: _msg(e))
          : state.copyWith(loading: false, stale: true);
    }
  }

  /// 两路合并取厂商：平台（`scope=master`）∪ 自建（`scope=personal`）。
  ///
  /// **这是和 React / 模型选择器同一套机制**（`useEnabledChatModels` 与
  /// `model_list_controller._build`）。平台行只能靠显式 `scope='master'` 拿到 ——
  /// 缺了它，网关/FFI 按 personal 短路直读 per-cid，而本地那几张表一开始是空的，
  /// 页面就永远空白。
  ///
  /// 个人那路固定 `cache`：个人行只落本地、没有远端真源，打后端也拿不到。
  Future<List<RelayProvider>> _fetchProviders(String mode) async {
    final results = await Future.wait([
      _providersOf(mode, 'master'),
      _providersOf('cache', 'personal'),
    ]);
    return [...results[0], ...results[1]]
      // 按显示名排序，和 React studio 的 localeCompare 一致。
      ..sort((a, b) => a.label.compareTo(b.label));
  }

  Future<List<RelayProvider>> _providersOf(String mode, String scope) async {
    final isPersonal = scope == 'personal';
    try {
      final r = await _settings.relayManage('model', 'providers',
          {'mode': mode, 'scope': scope});
      return _rows(r['providers'])
          .map(RelayProvider.fromRow)
          // 按 tag 分到各自的 scope（两 scope 读的是同一张表）。
          // 平台那路只留**已启用**的：停用厂商是管理面的事，摆在个人页只是噪音
          // （现网 19 个平台厂商里 17 个停用）。自建的不论启停都显示 ——
          // 用户自己关的，得能看见才能再打开。
          .where((p) => p.isCustom == isPersonal && (isPersonal || p.enabled))
          .toList();
    } catch (_) {
      // 任一 scope 失败不拖累另一侧（个人库没数据是常态）。
      return const [];
    }
  }

  /// 下钻到某厂商的模型（L2）。
  ///
  /// [refetch] 为真表示这不是下钻、是用户在 L2 点了刷新。
  Future<void> openProvider(String code,
      {bool? isCustom, bool refetch = false}) async {
    // 下钻时由调用方给出被点那一行的 tag（同 code 双行时只有它能区分）；
    // 刷新等后续调用不传，沿用 state 里记着的那个。
    final custom = isCustom ?? state.selectedIsCustom;
    final scope = custom ? 'personal' : 'master';
    state = state.copyWith(
        selectedProvider: code,
        selectedIsCustom: custom,
        models: const [],
        keys: const [],
        loading: true);
    try {
      state = state.copyWith(
        models: await _modelsOf(code, refetch ? 'sync' : 'cache', scope),
        loading: false,
      );
      // cache 拿到后再 sync 一次（平台行才有远端真源）。
      if (!refetch && scope == 'master') {
        final fresh = await _modelsOf(code, 'sync', scope);
        if (state.selectedProvider == code) {
          state = state.copyWith(models: fresh, stale: false);
        }
      }
    } catch (e) {
      state = state.copyWith(loading: false, error: _msg(e));
    }
  }

  Future<List<RelayModel>> _modelsOf(
      String code, String mode, String scope) async {
    final r = await _settings.relayManage('model', 'list', {
      'provider': code,
      // ⚠️ **必须为 true**：要能看见停用的模型才能把它重新启用，
      // 漏了这个参数等于单向操作。
      'include_disabled': true,
      'mode': mode,
      'scope': scope,
    });
    final isPersonal = scope == 'personal';
    return _rows(r['models'])
        .map(RelayModel.fromRow)
        // 两 scope 读同一张表，各自筛掉对方的行。
        .where((m) => m.isCustom == isPersonal)
        .toList();
  }

  /// 打开密钥池（L3）。
  ///
  /// ⚠️ 参数是**厂商代码**，不是模型名 —— 一个厂商下所有模型共用一池密钥。
  /// `apikey/listByModel` 的 `model_code` 收的就是厂商代码（命名很误导）。
  Future<void> openKeyPool(String providerCode) async {
    // 密钥池永远挂在当前下钻的那个厂商上，沿用它的 scope。
    final scope = state.selectedIsCustom ? 'personal' : 'master';
    state = state.copyWith(
        selectedModel: providerCode, keys: const [], loading: true);
    try {
      final r = await _settings.relayManage('apikey', 'listByModel', {
        'model_code': providerCode,
        'mode': scope == 'master' ? 'sync' : 'cache',
        'scope': scope,
      });
      final list = switch (r['data']) {
        final Map<String, Object?> d => d['list'],
        _ => null,
      };
      // 密钥**不按 tag 过滤**（relay_api_keys 表没这个字段，一过滤个人版
      // 就永远空 —— React studio 有这个 bug，我们不跟）。
      state = state.copyWith(
        keys: _rows(list).map(RelayApiKey.fromRow).toList(),
        loading: false,
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
  ///
  /// 走 [SettingsRepository.relayManage] —— 桌面是 FFI 直连本地
  /// `silicoid.db`（**零 gateway**），Web 转发 gateway，两边背后是库里同一份
  /// `relay_manage`。
  ///
  /// 写**一律落 `tag=custom`**，所以带 `scope=personal`。平台行的拦截在
  /// Rust 侧 fail-closed —— 界面禁用按钮只是体验层，直接打接口仍会进来。
  Future<bool> _write(
      String group, String method, Map<String, Object?> params) async {
    try {
      await _settings.relayManage(group, method, {
        ...params,
        // 个人页的写永远是个人的。不传的话会走到 sync 分支打到服务器，
        // 那是管理面的语义（改的是全平台）。
        'scope': 'personal',
      });
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
