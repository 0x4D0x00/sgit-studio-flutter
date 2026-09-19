import 'settings_repository_io.dart'
    if (dart.library.js_interop) 'settings_repository_web.dart' as impl;

/// 一项配置在本地/服务器上的存在状态。
class SettingsEntry {
  const SettingsEntry({
    required this.id,
    this.size = 0,
    this.sha256 = '',
    this.synced = true,
  });

  final String id;
  final int size;
  final String sha256;

  /// 是否已同步到服务器。`false` = 本地改了但还没上行成功（在脏队列里），
  /// 界面据此打「未同步」角标。
  ///
  /// Web 端恒为 true —— 它本身就跑在服务器上，不存在"本地"这一侧。
  final bool synced;
}

/// 一次同步的结果。
class SyncOutcome {
  const SyncOutcome({
    required this.ok,
    this.pushed = 0,
    this.pulled = 0,
    this.conflicts = const [],
    this.reason = '',
  });

  final bool ok;
  final int pushed;
  final int pulled;

  /// 两边都改过、服务器版本胜出的项。本地那份已另存备份，**没有被丢弃**。
  final List<SyncConflict> conflicts;

  /// ok=false 时的原因。
  final String reason;
}

class SyncConflict {
  const SyncConflict({required this.kind, required this.id, required this.backup});

  final String kind;
  final String id;

  /// 本地版本的备份文件名（`<id>.conflict.<ext>`）。
  final String backup;
}

/// 配置读写的**唯一入口** —— 上层只认这个接口，不认平台差异。
///
/// ## 两个实现，两条完全不同的路
///
/// ```text
/// 桌面/移动  dart:ffi → sgit_settings_* → 本地 per-cid 目录 + 打 Go 上行
/// Web       GatewayRepository → gateway → 服务器 per-cid 目录
/// ```
///
/// **Web 端不需要同步**：它本身跑在服务器上，读写的就是那份 per-cid 配置，
/// 没有"本地副本"这个概念。所以 Web 实现是对现有 gateway 端点的直通，
/// 行为与本次改动之前**一字不差**。
///
/// 桌面/移动才有两份（本地 + 服务器），于是才有 [sync]、[SettingsEntry.synced]
/// 和冲突处理。
/// 一次 SWR 刷新的结果。
class RefreshOutcome {
  const RefreshOutcome({this.ok = false, this.changed = false, this.reason = ''});

  final bool ok;

  /// 服务器侧有变化、已写入本地 —— 调用方应重读一次。
  final bool changed;

  /// ok=false 时的原因。**调用方不该据此弹错** —— 界面已有本地内容，
  /// 刷新失败只是"这次没刷到"，不是功能坏了。
  final String reason;
}

abstract interface class SettingsRepository {
  /// 列出某类别的配置项。桌面读本地（秒回），Web 走 gateway。
  Future<List<SettingsEntry>> list(String kind);

  /// 读某个 studio 页的原始数据（与对应 gateway 端点**同形**的 JSON）。
  ///
  /// 桌面/移动：FFI 直读本地（文件 + sqlite），**不碰网络**；
  /// Web：走 gateway 端点（它本身就在服务器上）。
  ///
  /// `page` 取值见 `StudioPageDef.key`：
  /// `scenes|subagent|skill|mcp|tools|memory|knowledge|llm-relay|api-key`。
  Future<Map<String, Object?>> readPage(String page);

  /// SWR 的后半段：打后端刷新本地数据。
  ///
  /// 桌面/移动：按页分派真源方向（用户配置走账本三态 + per-cid 对账、
  /// 平台下发服务器赢）；Web：no-op（没有本地副本，读的就是服务器）。
  ///
  /// [force] 为真表示这是用户**主动**点的刷新，必须真跑一次；为假是进页面
  /// 的自动刷新，桌面端会把短时间内的多次合并成一次（受管资源那条路一次
  /// 覆盖全部目录，切页时重复跑纯属白做）。
  ///
  /// **失败不抛异常** —— 返回 `ok:false` 让调用方静默忽略。
  Future<RefreshOutcome> refreshPage(String page, {bool force = false});

  /// 删除某页的一项。只有 scenes/subagent/skill 支持；其余抛异常。
  Future<void> removeFromPage(String page, String id);

  /// 改一个工具开关。[keyPath] 是 config.toml 的点分路径。
  ///
  /// 三类开关落在三个不同的键上（`features.<key>` / `web_search` /
  /// `tools.experimental_request_user_input.enabled`），所以这里收的是完整路径
  /// 而不是键名 —— 与 gateway `/sgcode-tools/set` 的 `keyPath` 同一套约定。
  ///
  /// 桌面/移动：Rust 侧先服务器后本地、失败入脏队列；Web：转发 gateway。
  /// **失败抛异常** —— 与只读的 refresh 不同，用户点了开关就得知道成没成。
  Future<void> setToolConfig(String keyPath, Object value);

  /// 中转站个人页的读写。[group]/[method]/[params] 与 gateway 的
  /// `/sgcode-models/manage` 同一套约定 —— 两条路线背后是同一份
  /// `relay_local_manage`（库里，见 sgit-services/src/http/relay_local.rs）。
  ///
  /// 平台行（`tag=builtin`）的写会被 Rust 侧 fail-closed 拒绝：这一页的写一律
  /// 落 `tag=custom`，改平台行只会造出同名影子行、删厂商更会级联删平台模型。
  ///
  /// **失败抛异常**。
  Future<Map<String, Object?>> relayManage(
      String group, String method, Map<String, Object?> params);

  /// 读一项正文。
  Future<String> read(String kind, String id);

  /// 写一项。
  ///
  /// 桌面语义是**先服务器后本地**：服务器不可达时仍然写本地并排队，
  /// 返回的 entry `synced=false`。所以调用方不该把它当成"失败"——
  /// 用户的改动已经保住了，只是还没上行。
  Future<SettingsEntry> write(String kind, String id, String content);

  Future<void> delete(String kind, String id);

  /// 全量同步（重放脏队列 + 与服务器对账）。Web 上是 no-op。
  Future<SyncOutcome> sync();

  /// 该平台是否存在"本地副本"这一侧。Web 为 false ——
  /// 界面据此决定要不要显示同步入口与未同步角标。
  bool get hasLocalCopy;
}

/// 按平台选实现。与 `kernel_client_factory.dart` 同一套条件导入范式。
SettingsRepository createSettingsRepository() => impl.createSettingsRepository();
