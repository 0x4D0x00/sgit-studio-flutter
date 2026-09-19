import 'package:flutter/foundation.dart';

/// 工具的开关归属 —— 决定它「读哪里、写哪里、能不能关」。
enum ToolKind {
  /// 常驻能力，没有任何开关。引擎无条件注册，关不掉。
  core,

  /// 由 `config.toml` 的 `[features].<featureKey>` 控制。
  feature,

  /// 由 `tools.experimental_request_user_input.enabled` 控制。
  requestUserInput,

  /// 由顶层 `web_search` 控制（`disabled` / `cached` / …）。
  webSearch,
}

/// 工具对模型的可见度 —— 本 fork 特有的机制。
enum ToolExposure {
  /// 首轮就摆在模型面前（`CORE_BUILTIN_TOOLS` 白名单）。
  direct,

  /// 已注册但首轮不可见，模型要先用 `tool_search` 搜出来才能调。
  ///
  /// 存在的理由是工具太多会撑爆每轮 body —— 实测 53 个工具时大模型开始选错。
  /// 对用户的意义：**这个工具是能用的，只是模型得先找到它**，
  /// 与"被关掉了"完全是两回事，界面上必须区分。
  deferred,
}

/// 一个内置工具。
@immutable
class ToolDef {
  const ToolDef({
    required this.id,
    required this.label,
    required this.desc,
    required this.kind,
    this.featureKey,
    this.defaultOn,
    this.exposure = ToolExposure.deferred,
  });

  /// 技术名 —— **模型看到的那个工具名**。界面上小字展示，
  /// 便于和日志、提示词里出现的名字对上。
  final String id;

  final String label;
  final String desc;
  final ToolKind kind;

  /// `feature` 类在 `[features]` 下的键名。**与 [id] 常常不同**
  /// （`spawn_agents_on_csv` 的键是 `enable_fanout`）。
  final String? featureKey;

  /// 配置里没写这一项时的引擎默认值（取自 `features/src/lib.rs` 的 FEATURES 表）。
  ///
  /// ⚠️ 不是可有可无的兜底：现网 config.toml 只写了 10 个键，而开关不止 10 个 ——
  /// 没写的那些**并非关闭**，而是走引擎默认。拿"键不存在就当 false"渲染，
  /// 界面会把开着的工具显示成关的。
  final bool? defaultOn;

  final ToolExposure exposure;
}

@immutable
class ToolCategory {
  const ToolCategory({required this.name, required this.tools});

  final String name;
  final List<ToolDef> tools;
}

/// sgcode 引擎的内置工具目录。
///
/// ## 依据：引擎实际注册的那批，不是 React studio 那份
///
/// 逐条核对 `core/src/tools/spec_plan.rs` 的 `add_*_tools` 系列
/// （`add_core_utility_tools:773`、`add_shell_tools:716`、
/// `add_collaboration_tools:878`、`add_extension_tools:1045`）
/// 与白名单 `CORE_BUILTIN_TOOLS:235`。
///
/// **没有照抄 React 的 `ToolLibrary.tsx::CATALOG`** —— 那份已经和本 fork 对不上：
///
/// | React 列的 | 本 fork 实际 |
/// |---|---|
/// | `apply_patch` | **不暴露给模型**（`spec_plan.rs:845`：文件改动统一走 Edit/Write，引擎只保留给 Bash 内联 patch 拦截） |
/// | `exec_command` / `shell` | **只暴露 `Bash`**（`spec_plan.rs:737`） |
/// | `update_plan` | 实际叫 `TodoWrite` |
/// | 记忆工具 | 本 fork 已移除（`ext/memories/src/extension.rs:107` 返回空列表） |
/// | — | 漏了 `Read`/`Edit`/`Write`/`Grep`/`Glob`/`render_svg`/`render_mermaid`/`tool_search` |
///
/// 照抄会让用户看到一批根本不存在的工具，同时看不到天天在用的那几个。
///
/// ## 为什么是手写目录而不是把 `[features]` 摊平
///
/// `[features]` 是**引擎能力开关**，不是工具清单：
///
/// - 多数核心工具没有开关（`Read`/`Write`/`Bash`/`TodoWrite` 无条件注册）；
/// - 有开关不产生工具（`default_mode_request_user_input` 只是给
///   `AskUserQuestion` 的参数加取值，`code_mode` 改的是整个工具面形态）；
/// - 名字对不上（键 `enable_fanout` → 工具 `spawn_agents_on_csv`）；
/// - 开关散在三处（`[features]`、顶层 `web_search`、
///   `tools.experimental_request_user_input.enabled`）。
///
/// 代价是引擎加工具要来这里补一条 —— 这个代价是对的：类别、说明、开关归属
/// 本来就要人来决定。
const toolCatalog = <ToolCategory>[
  ToolCategory(name: '文件与检索', tools: [
    ToolDef(
      id: 'Read',
      label: '读文件',
      desc: '读取文件内容（也能读图片与 PDF）',
      kind: ToolKind.core,
      exposure: ToolExposure.direct,
    ),
    ToolDef(
      id: 'Edit',
      label: '改文件',
      desc: '按精确匹配替换文件内容',
      kind: ToolKind.core,
      exposure: ToolExposure.direct,
    ),
    ToolDef(
      id: 'Write',
      label: '写文件',
      desc: '新建或整体覆盖一个文件',
      kind: ToolKind.core,
      exposure: ToolExposure.direct,
    ),
    ToolDef(
      id: 'Grep',
      label: '内容搜索',
      desc: '按正则搜文件内容（ripgrep）',
      kind: ToolKind.core,
      exposure: ToolExposure.direct,
    ),
    ToolDef(
      id: 'Glob',
      label: '文件名匹配',
      desc: '按通配符找文件路径',
      kind: ToolKind.core,
      exposure: ToolExposure.direct,
    ),
    ToolDef(
      id: 'view_image',
      label: '查看图片',
      desc: '把本地图片加入上下文',
      kind: ToolKind.core,
    ),
  ]),
  ToolCategory(name: '终端', tools: [
    ToolDef(
      id: 'Bash',
      label: '命令执行',
      desc: '执行 shell 命令',
      kind: ToolKind.core,
      exposure: ToolExposure.direct,
    ),
  ]),
  ToolCategory(name: '任务规划', tools: [
    ToolDef(
      id: 'TodoWrite',
      label: '待办清单',
      desc: '维护任务列表与进度',
      kind: ToolKind.core,
      exposure: ToolExposure.direct,
    ),
  ]),
  ToolCategory(name: '绘图', tools: [
    ToolDef(
      id: 'render_svg',
      label: 'SVG 渲染',
      desc: '把 SVG 光栅化成 PNG',
      kind: ToolKind.core,
      exposure: ToolExposure.direct,
    ),
    ToolDef(
      id: 'render_mermaid',
      label: 'Mermaid 渲染',
      desc: '把 mermaid 图渲染成 PNG（需沙箱镜像带 mermaid-cli）',
      kind: ToolKind.core,
      exposure: ToolExposure.direct,
    ),
  ]),
  ToolCategory(name: '联网与图像', tools: [
    ToolDef(
      id: 'web_search',
      label: '网页搜索',
      desc: '联网搜索（服务端执行）',
      kind: ToolKind.webSearch,
    ),
    ToolDef(
      id: 'web.run',
      label: '独立搜索扩展',
      desc: '用扩展版 web.run 替代服务端搜索',
      kind: ToolKind.feature,
      featureKey: 'standalone_web_search',
      defaultOn: false,
    ),
    ToolDef(
      id: 'image_gen.imagegen',
      label: '图像生成',
      desc: '生成图片（还需模型与厂商支持）',
      kind: ToolKind.feature,
      featureKey: 'image_generation',
      defaultOn: true,
    ),
  ]),
  ToolCategory(name: '多 Agent 协作', tools: [
    ToolDef(
      id: 'spawn_agent / wait_agent',
      label: '子 Agent',
      desc: '派生子 agent 并等待结果。开关切换 v1 / v2 两套，不是开关闭',
      kind: ToolKind.feature,
      featureKey: 'multi_agent_v2',
      defaultOn: false,
    ),
    ToolDef(
      id: 'spawn_agents_on_csv',
      label: '批量 Agent',
      desc: '按 CSV 批量派生 agent',
      kind: ToolKind.feature,
      featureKey: 'enable_fanout',
      defaultOn: false,
    ),
  ]),
  ToolCategory(name: '上下文与交互', tools: [
    ToolDef(
      id: 'AskUserQuestion',
      label: '向用户提问',
      desc: '执行中途向用户确认',
      kind: ToolKind.requestUserInput,
      exposure: ToolExposure.direct,
    ),
    ToolDef(
      id: 'new_context / get_context_remaining',
      label: '上下文预算',
      desc: '查询剩余上下文、开新窗口。同时影响压缩策略',
      kind: ToolKind.feature,
      featureKey: 'token_budget',
      defaultOn: false,
    ),
    ToolDef(
      id: 'request_permissions',
      label: '权限请求',
      desc: '运行中申请更高权限（沙箱提权）',
      kind: ToolKind.feature,
      featureKey: 'request_permissions_tool',
      defaultOn: false,
      exposure: ToolExposure.direct,
    ),
    ToolDef(
      id: 'clock.curr_time / clock.sleep',
      label: '时间',
      desc: '获取当前时间、等待。同时在上下文注入时间提示',
      kind: ToolKind.feature,
      featureKey: 'current_time_reminder',
      defaultOn: false,
    ),
    ToolDef(
      id: 'restore_output',
      label: '取回折叠内容',
      desc: '读回被折叠的工具输出原文',
      kind: ToolKind.core,
    ),
  ]),
  ToolCategory(name: '内置实用', tools: [
    ToolDef(
      id: 'math.calc',
      label: '计算器',
      desc: '本地表达式求值',
      kind: ToolKind.core,
    ),
    ToolDef(
      id: 'tool_search',
      label: '工具检索',
      desc: '搜索未直接可见的工具 —— 下面标「按需」的都靠它发现',
      kind: ToolKind.core,
      exposure: ToolExposure.direct,
    ),
  ]),
  ToolCategory(name: 'MCP 与扩展', tools: [
    ToolDef(
      id: 'list_mcp_resources / read_mcp_resource',
      label: 'MCP 资源',
      desc: '列出与读取 MCP 服务器提供的资源',
      kind: ToolKind.core,
    ),
    ToolDef(
      id: 'skills.list / skills.read',
      label: '技能',
      desc: '列出与读取技能库',
      kind: ToolKind.core,
    ),
    ToolDef(
      id: 'exec / wait',
      label: '代码模式',
      desc: '改用 JS 沙箱调用工具 —— 开启后整个工具面换形态，不是加一个工具',
      kind: ToolKind.feature,
      featureKey: 'code_mode',
      defaultOn: false,
    ),
  ]),
];

/// 工具当前是否启用。
///
/// [features] 是 `config.toml` 的 `[features]` 段；[webSearch] 是顶层
/// `web_search` 字符串；[requestUserInput] 是
/// `tools.experimental_request_user_input.enabled`。
bool toolEnabled(
  ToolDef tool, {
  required Map<String, Object?> features,
  String? webSearch,
  bool? requestUserInput,
}) =>
    switch (tool.kind) {
      // 配置里没写 → 走引擎默认，不是关闭。
      ToolKind.feature =>
        (features[tool.featureKey] as bool?) ?? tool.defaultOn ?? false,
      ToolKind.requestUserInput => requestUserInput ?? true,
      // 只有显式 `disabled` 才算关；没配置时引擎默认是开的。
      ToolKind.webSearch => webSearch == null ? true : webSearch != 'disabled',
      ToolKind.core => true,
    };

/// 改这个工具要写的 config 键路径（点分）与值。核心工具返回 null（关不掉）。
///
/// 与 gateway `/sgcode-tools/set` 的 `keyPath` 约定一致 —— 三类开关落在三个
/// 不同的键上，这也是"不能只改 `[features]`"的原因。
(String path, Object value)? toolWritePath(ToolDef tool, bool next) =>
    switch (tool.kind) {
      ToolKind.feature => ('features.${tool.featureKey}', next),
      ToolKind.webSearch => ('web_search', next ? 'cached' : 'disabled'),
      ToolKind.requestUserInput => (
          'tools.experimental_request_user_input.enabled',
          next
        ),
      ToolKind.core => null,
    };
