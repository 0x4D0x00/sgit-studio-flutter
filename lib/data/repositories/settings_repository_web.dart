import 'package:sgit_studio_flutter/core/result/api_exception.dart';
import 'package:sgit_studio_flutter/data/repositories/gateway_repository.dart';
import 'package:sgit_studio_flutter/data/repositories/settings_repository.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_factory.dart';

/// Web 的配置仓储 —— 直通现有 gateway 端点。
///
/// ## Web 不需要同步
///
/// Web 本身就跑在服务器上，它读写的**就是**那份 per-cid 配置，不存在"本地副本"。
/// 所以：
/// - [hasLocalCopy] 为 false，界面不显示同步入口与未同步角标；
/// - [sync] 是 no-op（返回 ok，计数为 0）；
/// - 每一项恒为 `synced: true`。
///
/// ⚠️ **本实现不改变 Web 的任何既有行为** —— 走的是原来那批
/// `/sgcode-*` 端点，与这次桌面同步改动之前一字不差。
final class WebSettingsRepository implements SettingsRepository {
  WebSettingsRepository() : _repo = GatewayRepository(createKernelClient());

  final GatewayRepository _repo;

  @override
  bool get hasLocalCopy => false;

  /// kind → (列表端点, 列表字段, id 字段)。
  ///
  /// 与 `studio_page_specs.dart` 的登记保持一致；`config` 不是列表型资源，
  /// Web 上由各自的设置页直接读写，不走这个接口。
  static const _listing = <String, (String, String, String)>{
    'scenes': ('/sgcode-scene/list', 'scenes', 'id'),
    'agents': ('/sgcode-subagent/list', 'subagents', 'id'),
    'skills': ('/sgcode-skill/list', 'skills', 'id'),
  };

  @override
  Future<List<SettingsEntry>> list(String kind) async {
    final spec = _listing[kind];
    if (spec == null) return const [];
    final (path, field, idField) = spec;

    final data = await _repo.fetch(path);
    final raw = data[field];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => SettingsEntry(
              id: m.cast<String, Object?>()[idField]?.toString() ?? '',
              // Web 侧就是服务器，永远"已同步"。
              synced: true,
            ))
        .toList(growable: false);
  }

  @override
  Future<String> read(String kind, String id) async {
    if (kind != 'skills') {
      // 场景/子 Agent 的正文在 Web 上由各自页面按结构化字段编辑，
      // 没有"取整份 toml 正文"的端点。硬造一个会与那些页面产生第二份真源。
      throw ApiException('Web 端不支持直接读取 $kind 正文');
    }
    final data = await _repo.post('/sgcode-skill/read', {'id': id});
    return data['content']?.toString() ?? '';
  }

  @override
  Future<SettingsEntry> write(String kind, String id, String content) async {
    if (kind != 'skills') {
      throw ApiException('Web 端不支持直接写入 $kind 正文');
    }
    await _repo.post('/sgcode-skill/update', {'id': id, 'content': content});
    return SettingsEntry(id: id, synced: true);
  }

  @override
  Future<void> delete(String kind, String id) async {
    final path = switch (kind) {
      'scenes' => '/sgcode-scene/remove',
      'agents' => '/sgcode-subagent/remove',
      'skills' => '/sgcode-skill/remove',
      _ => null,
    };
    if (path == null) throw ApiException('Web 端不支持删除 $kind');
    await _repo.post(path, {'id': id});
  }

  /// no-op：Web 没有本地副本，无从同步。
  @override
  Future<SyncOutcome> sync() async => const SyncOutcome(ok: true);

  // ---- studio 各页 ----

  /// 页 key → gateway 端点。**与本次改动之前各页用的完全相同**，
  /// 所以 Web 行为一字未变（只是入口从 controller 直连 GatewayRepository
  /// 改成经这里转发）。
  static const _pageEndpoints = <String, String>{
    'scenes': '/sgcode-scene/list',
    'subagent': '/sgcode-subagent/list',
    'skill': '/sgcode-skill/list',
    'mcp': '/sgcode-mcp/list',
    'tools': '/sgcode-tools/config',
    'knowledge': '/sgcode-knowledge/list',
  };

  @override
  Future<Map<String, Object?>> readPage(String page) async {
    final path = _pageEndpoints[page];
    if (path == null) {
      // memory / llm-relay / api-key 在 Web 上各有专门页面与端点
      // （中转站是三级页、密钥走 aiBasicPlatform），不经这个通用入口。
      throw ApiException('Web 端 $page 页不走通用入口');
    }
    return _repo.fetch(path);
  }

  /// Web 就在服务器上，没有"刷新本地"这件事。返回 ok 且 changed=false ——
  /// 调用方据此不会做多余的重读。
  @override
  Future<RefreshOutcome> refreshPage(String page, {bool force = false}) async =>
      const RefreshOutcome(ok: true);

  @override
  Future<void> removeFromPage(String page, String id) async {
    final kind = switch (page) {
      'scenes' => 'scenes',
      'subagent' => 'agents',
      'skill' => 'skills',
      _ => null,
    };
    if (kind == null) throw ApiException('Web 端 $page 页不支持删除');
    return delete(kind, id);
  }

  /// Web：走 gateway 的 `/sgcode-models/manage`，个人作用域是它的缺省。
  @override
  Future<Map<String, Object?>> relayManage(
      String group, String method, Map<String, Object?> params) async {
    final r = await _repo.post('/sgcode-models/manage',
        {'group': group, 'method': method, ...params});
    if (r['status'] != 'success') {
      throw ApiException(r['message']?.toString() ?? '操作失败');
    }
    return r;
  }

  /// Web：转发 gateway 的 `/sgcode-tools/set` —— 它走 app-server 的
  /// ConfigBatchWrite，写完还会热加载引擎配置。
  @override
  Future<void> setToolConfig(String keyPath, Object value) async {
    final r = await _repo.post(
        '/sgcode-tools/set', {'keyPath': keyPath, 'value': value});
    if (r['ok'] != true) {
      throw ApiException(r['error']?.toString() ?? '设置失败');
    }
  }
}

SettingsRepository createSettingsRepository() => WebSettingsRepository();
