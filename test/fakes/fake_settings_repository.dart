import 'package:sgit_studio_flutter/core/result/api_exception.dart';
import 'package:sgit_studio_flutter/data/repositories/settings_repository.dart';

/// 测试用的配置仓储。
///
/// ⚠️ 必须注入它，**不能让测试跑到生产工厂**：桌面工厂返回的
/// `IoSettingsRepository` 会去 `DynamicLibrary.open('sgit_ffi.dll')`，
/// 测试环境里必然失败。那个失败恰好会被控制器的 `_loadUnsynced` catch 掉，
/// 于是测试"照样绿" —— 但绿得毫无意义，且掩盖了真实的加载问题。
///
/// （同类教训见 `layout_test.dart` 里 kernelClientProvider 那条注释。）
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({
    this.hasLocalCopy = true,
    Map<String, List<SettingsEntry>>? entries,
    this.syncOutcome = const SyncOutcome(ok: true),
    Map<String, Map<String, Object?>>? pages,
    this.refreshOutcome = const RefreshOutcome(ok: true),
    this.failToolWrites = false,
    this.failRelayWrites = false,
    this.failSync = false,
  })  : _entries = entries ?? const {},
        _pages = pages ?? const {};

  /// 让 `mode=sync` 的 [relayManage] 抛异常 —— 复现**本地模式 / 断网**：
  /// sync 要打后端做加密握手，那条路在本地必然不通，只有 cache 能出数据。
  final bool failSync;

  final Map<String, List<SettingsEntry>> _entries;

  /// 各页的假数据，key 是 `StudioPageDef.key`。
  final Map<String, Map<String, Object?>> _pages;

  /// 工具页快照，形状照 `sgit_studio_read('tools')`。
  ///
  /// 取自实测的现网 config.toml `[features]`，**刻意只有 10 个键** ——
  /// 而目录里的开关不止 10 个。没写的那些（如 `plugins`、`shell_tool`）
  /// 并非关闭，而是走引擎默认；拿"键不存在就当 false"渲染，界面会把开着的
  /// 工具显示成关的。这份快照就是用来抓那个错的。
  ///
  /// `webSearch` / `requestUserInput` 为 null 同理：它们的引擎默认都是**开**。
  static const toolsSnapshot = <String, Object?>{
    'features': {
      'default_mode_request_user_input': true,
      'code_mode': true,
      'current_time_reminder': true,
      'enable_fanout': true,
      'image_generation': true,
      'memories': true,
      'multi_agent_v2': true,
      'request_permissions_tool': true,
      'standalone_web_search': true,
      'token_budget': true,
    },
    'requestUserInput': null,
    'webSearch': null,
  };

  /// 中转站在本地模式下的三层快照，形状照 `sgit_studio_read('llm-relay')`。
  ///
  /// 与 `kernel_client_mock.dart` 的 gateway fixture **同一批数据**，这样
  /// 两种模式的断言可以共用一套期望值 —— 数据不同的话，本地模式的回归就成了
  /// 另一个故事，测不出"两条路呈现一致"这个真正要守的约定。
  ///
  /// 三点刻意保留：同一 `model_code` 的 builtin/custom 两行（现网常态）、
  /// 一个**停用的平台厂商**（个人页不该显示它），以及密钥的 `api_key` 是
  /// 已脱敏串（Rust 侧 `relay_local_apikeys_to_json` 解密后留尾 6 位，
  /// 明文不出 DLL）。
  static const relaySnapshot = <String, Object?>{
    'providers': [
      {
        'model_code': 'Qwen',
        'provider': 'Alibaba',
        'display_name': 'Alibaba',
        'status': 1,
        'tag': 'builtin',
        'base_url': 'http://10.100.0.66:11434/v1',
      },
      {
        'model_code': 'DeepSeek',
        'provider': 'DeepSeek',
        'display_name': 'DeepSeek',
        'status': 0,
        'tag': 'builtin',
        'base_url': '',
      },
      {
        'model_code': 'Qwen',
        'provider': 'Alibaba',
        'display_name': 'Alibaba（个人）',
        'status': 1,
        'tag': 'custom',
        'base_url': 'http://127.0.0.1:11434/v1',
      },
      {
        'model_code': 'MyVendor',
        'provider': 'custom',
        'display_name': '自建厂商',
        'status': 1,
        'tag': 'custom',
        'base_url': 'http://127.0.0.1:8000/v1',
      },
    ],
    'models': [
      {
        'model_name': 'glm4:latest',
        'model_display_name': 'GLM-4',
        'model_code': 'Qwen',
        'is_available': 1,
        'context_window': 128000,
        'tag': 'builtin',
      },
      {
        'model_name':
            'joe-speedboat/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive:Q4_K_M',
        'model_display_name': '',
        'model_code': 'Qwen',
        'is_available': 1,
        'tag': 'builtin',
      },
      {
        'model_name': 'glm4:personal',
        'model_display_name': 'GLM-4（个人·已停用）',
        'model_code': 'Qwen',
        'is_available': 0,
        'context_window': 32000,
        'tag': 'custom',
      },
    ],
    'keys': [
      // 已脱敏串，不是明文 —— Rust 侧解密后只留尾 6 位。
      {'id': '1', 'api_key': '******123456', 'status': 1, 'model_code': 'Qwen'},
    ],
  };

  final SyncOutcome syncOutcome;
  final RefreshOutcome refreshOutcome;

  @override
  final bool hasLocalCopy;

  /// 记录调用，供断言「先服务器后本地」之类的顺序。
  final List<String> calls = [];

  @override
  Future<List<SettingsEntry>> list(String kind) async {
    calls.add('list:$kind');
    return _entries[kind] ?? const [];
  }

  @override
  Future<String> read(String kind, String id) async {
    calls.add('read:$kind/$id');
    return '';
  }

  @override
  Future<SettingsEntry> write(String kind, String id, String content) async {
    calls.add('write:$kind/$id');
    return SettingsEntry(id: id, synced: true);
  }

  @override
  Future<void> delete(String kind, String id) async {
    calls.add('delete:$kind/$id');
  }

  @override
  Future<SyncOutcome> sync() async {
    calls.add('sync');
    return syncOutcome;
  }

  // ---- studio 各页（SWR）----

  @override
  Future<Map<String, Object?>> readPage(String page) async {
    calls.add('readPage:$page');
    return _pages[page] ?? const {};
  }

  @override
  Future<RefreshOutcome> refreshPage(String page, {bool force = false}) async {
    // force 记进调用串：测试要能断言「进页面是自动刷、按钮是强制刷」。
    calls.add('refreshPage:$page${force ? ':force' : ''}');
    return refreshOutcome;
  }

  /// 模拟库里 `relay_manage` 的分派：按 group/method 回对应形状，
  /// 并按 `scope` 筛 tag —— 真实实现里两 scope 读的是同一张表，
  /// 各自筛掉对方的行，测试必须复现这一点，否则筛错了也测不出来。
  @override
  Future<Map<String, Object?>> relayManage(
      String group, String method, Map<String, Object?> params) async {
    final scope = params['scope']?.toString() ?? 'master';
    final mode = params['mode']?.toString() ?? 'cache';
    calls.add('relayManage:$group/$method:$scope');

    // 本地模式 / 断网：`mode=sync` 要打后端做加密握手，必然失败。
    // 实测报的就是 `Failed to get nonce`，这里照搬那句话。
    if (failSync && mode == 'sync') {
      throw const ApiException('Request failed: Failed to get nonce');
    }

    bool inScope(Object? row) {
      final tag = (row as Map)['tag']?.toString() ?? 'builtin';
      return (tag == 'custom') == (scope == 'personal');
    }

    switch ((group, method)) {
      case ('model', 'providers'):
        final all = relaySnapshot['providers']! as List;
        return {'status': 'success', 'providers': all.where(inScope).toList()};
      case ('model', 'list'):
        final code = params['provider'];
        final all = relaySnapshot['models']! as List;
        return {
          'status': 'success',
          'provider': code,
          'models': all
              .where((m) => (m as Map)['model_code'] == code && inScope(m))
              .toList(),
        };
      case ('apikey', 'listByModel'):
        final code = params['model_code'];
        // 密钥不按 tag 筛（表里没这个字段）。
        final all = (relaySnapshot['keys']! as List)
            .where((k) => (k as Map)['model_code'] == code)
            .toList();
        return {
          'status': 'success',
          'data': {'list': all, 'count': all.length},
        };
      default:
        // 写操作。
        if (failRelayWrites) {
          throw const ApiException('这是平台开放的厂商/模型，个人页只读');
        }
        return const {'status': 'success'};
    }
  }

  /// 让 [relayManage] 抛异常 —— 测平台行被拒时界面的表现。
  final bool failRelayWrites;

  @override
  Future<void> setToolConfig(String keyPath, Object value) async {
    calls.add('setToolConfig:$keyPath=$value');
    if (failToolWrites) throw const ApiException('服务器不可达');
  }

  /// 让 [setToolConfig] 抛异常 —— 测乐观更新的回滚。
  final bool failToolWrites;

  @override
  Future<void> removeFromPage(String page, String id) async {
    calls.add('removeFromPage:$page/$id');
  }
}
