/// gateway 端点的**动词表** —— 与 `sgcode-rs/sgit-services/src/bin/gateway.rs`
/// 的 `.route(...)` 注册表一一对应。
///
/// ## 为什么要这张表
///
/// 各页原先都用 `_repo.get(spec.listPath)` 取列表，但 gateway 里 list 端点的动词
/// **并不统一**：scene/skill/subagent/knowledge 的 list 是 GET，而 `mcp/list`
/// 是 POST。结果 MCP 页直接 `405 Method Not Allowed`，页面空白 —— 而这种错
/// 只有真跑起来点到那一页才会发现。
///
/// 现在动词由路径**查表**决定，调用方不再自己选，也就不可能选错；
/// 新增端点忘了登记会在契约测试里红掉，而不是等用户报 405。
enum HttpVerb { get, post }

/// 已登记的端点。**新增端点必须同时登记在这里**。
///
/// ⚠️ 改动前先去 gateway.rs 确认真实动词，别照着别的端点猜 —— 上面那个 405
/// 就是猜出来的。
const gatewayVerbs = <String, HttpVerb>{
  // ---- 场景 ----
  '/sgcode-scene/list': HttpVerb.get,
  '/sgcode-scene/commands': HttpVerb.get,
  '/sgcode-scene/outputs': HttpVerb.get,
  '/sgcode-scene/preview': HttpVerb.get,
  '/sgcode-scene/workdir': HttpVerb.get,
  '/sgcode-scene/upsert': HttpVerb.post,
  '/sgcode-scene/remove': HttpVerb.post,
  '/sgcode-scene/removeAll': HttpVerb.post,
  '/sgcode-scene/refresh': HttpVerb.post,
  '/sgcode-scene/refreshAll': HttpVerb.post,
  '/sgcode-scene/import': HttpVerb.post,

  // ---- 子 Agent ----
  '/sgcode-subagent/list': HttpVerb.get,
  '/sgcode-subagent/skills': HttpVerb.get,
  '/sgcode-subagent/upsert': HttpVerb.post,
  '/sgcode-subagent/remove': HttpVerb.post,
  '/sgcode-subagent/removeAll': HttpVerb.post,
  '/sgcode-subagent/refresh': HttpVerb.post,
  '/sgcode-subagent/refreshAll': HttpVerb.post,
  '/sgcode-subagent/import': HttpVerb.post,

  // ---- 技能 ----
  '/sgcode-skill/list': HttpVerb.get,
  '/sgcode-skill/read': HttpVerb.post,
  '/sgcode-skill/update': HttpVerb.post,
  '/sgcode-skill/remove': HttpVerb.post,
  '/sgcode-skill/removeAll': HttpVerb.post,
  '/sgcode-skill/refresh': HttpVerb.post,
  '/sgcode-skill/refreshAll': HttpVerb.post,
  '/sgcode-skill/import': HttpVerb.post,

  // ---- MCP ----
  // ⚠️ list 是 **POST**，与其它页不同。就是它造成过 405。
  '/sgcode-mcp/list': HttpVerb.post,
  '/sgcode-mcp/upsert': HttpVerb.post,
  '/sgcode-mcp/remove': HttpVerb.post,
  '/sgcode-mcp/toggle': HttpVerb.post,
  '/sgcode-mcp/import': HttpVerb.post,

  // ---- 知识库 ----
  '/sgcode-knowledge/list': HttpVerb.get,
  '/sgcode-knowledge/file': HttpVerb.get,
  '/sgcode-knowledge/remove': HttpVerb.post,

  // ---- 工具 ----
  '/sgcode-tools/config': HttpVerb.get,
  '/sgcode-tools/set': HttpVerb.post,

  // ---- 其它 ----
  '/sgcode-models/manage': HttpVerb.post,
  '/sgcode-menu/list': HttpVerb.get,
  '/sgcode-resource/list': HttpVerb.get,
  '/sgcode-agent/run': HttpVerb.post,
  '/sgcode-approval/policy': HttpVerb.get,
  '/sgcode-approval/decide': HttpVerb.post,
  '/sgcode-thread-settings/update': HttpVerb.post,
  '/sgcode-server-request/respond': HttpVerb.post,
};

/// 查某端点的动词。未登记直接抛 —— **不猜**。
///
/// 猜错的代价是 405 + 空白页面，而且只有点到那一页才暴露；抛异常至少会在
/// 开发和测试里立刻炸出来。
HttpVerb verbFor(String path) {
  final v = gatewayVerbs[path];
  if (v == null) {
    throw ArgumentError(
        '端点 $path 未登记动词。去 gateway.rs 确认它是 get 还是 post，'
        '然后登记到 gateway_endpoints.dart —— 别猜。');
  }
  return v;
}
