import 'package:flutter/foundation.dart';

/// 输入框能改的 sgcode 引擎设置 —— **取值一律用引擎原生的，不自造一套再翻译**。
///
/// 中间多一层映射就多一处会漂移的地方；`ApprovalDecision`
/// （`core/contracts/kernel_client.dart:144`）已经立过这个规矩，这里照办。
///
/// 真源（`D:/Projects/sgit-code/sgcode-rs`）：
/// - [ApprovalPolicy] ← `protocol/src/protocol.rs` 的 `AskForApproval`
/// - [SandboxMode]    ← `protocol/src/config_types.rs` 的 `SandboxMode`
/// - [ReasoningEffort]← `protocol/src/sgai_models.rs` 的 `ReasoningEffort`
///
/// 三者都是 `config.toml` 的**顶层键**（`config/src/config_toml.rs` 的
/// `approval_policy` / `sandbox_mode` / `model_reasoning_effort`），所以读写都走
/// `SettingsRepository`：桌面直落本机文件，Web 才转 gateway。
///
/// `test/sgcode_settings_test.dart` 钉住下面每一个线值。

// ============================================================================
// 审批策略
// ============================================================================

/// sgcode 原生审批策略。**四档，不多不少** —— studio 面板就是这四个，
/// 引擎的 `AskForApproval` 也是这四个变体。
///
/// 用 sealed 而不是 enum：`granular` 档带 5 个子开关，enum 装不下。
/// 分支处理一律 switch 表达式，加档位时所有消费点编译报错。
@immutable
sealed class ApprovalPolicy {
  const ApprovalPolicy();

  /// 引擎默认档（`AskForApproval` 的 `#[default]` 是 `OnRequest`）。
  static const ApprovalPolicy defaults = OnRequestApproval();

  /// 写进 `config.toml` 的值。字符串档是裸字符串，granular 档是一张表 ——
  /// 两种形态都合法，所以返回 `Object` 而不是 `String`。
  Object toWire() => switch (this) {
        UntrustedApproval() => 'untrusted',
        OnRequestApproval() => 'on-request',
        NeverApproval() => 'never',
        GranularApproval(:final config) => {'granular': config.toWire()},
      };

  /// 从 `config.toml` 读回。认不出来就回默认档 —— 引擎加了新档位时
  /// 界面显示成默认值，总好过崩掉或显示空白。
  static ApprovalPolicy fromWire(Object? v) => switch (v) {
        'untrusted' => const UntrustedApproval(),
        'on-request' => const OnRequestApproval(),
        // 引擎侧 `#[serde(alias = "on-failure")]`，老配置文件里可能是这个。
        'on-failure' => const OnRequestApproval(),
        'never' => const NeverApproval(),
        final Map<String, Object?> m when m['granular'] != null =>
          GranularApproval(
            GranularApprovalConfig.fromWire(m['granular'] as Map<String, Object?>),
          ),
        _ => defaults,
      };
}

/// 只自动批准「已知安全的只读命令」，其余都问。
class UntrustedApproval extends ApprovalPolicy {
  const UntrustedApproval();
}

/// 模型自己决定何时请求审批（引擎默认）。
class OnRequestApproval extends ApprovalPolicy {
  const OnRequestApproval();
}

/// 从不询问，失败直接返回给模型。
class NeverApproval extends ApprovalPolicy {
  const NeverApproval();
}

/// 细粒度：逐类控制。
class GranularApproval extends ApprovalPolicy {
  const GranularApproval(this.config);

  final GranularApprovalConfig config;
}

/// [GranularApproval] 的 5 个子开关。
///
/// 字段名与引擎 `GranularApprovalConfig` 一一对应（线上是 snake_case，
/// 因为它落在 `config.toml` 里而不是走 camelCase 的 app-server JSON）。
@immutable
class GranularApprovalConfig {
  const GranularApprovalConfig({
    this.sandboxApproval = true,
    this.rules = true,
    this.skillApproval = true,
    this.requestPermissions = true,
    this.mcpElicitations = true,
  });

  /// shell 命令审批（含 `with_additional_permissions` / `require_escalated`）。
  final bool sandboxApproval;

  /// 规则类审批。
  final bool rules;

  /// 技能调用审批。
  final bool skillApproval;

  /// 权限申请。
  final bool requestPermissions;

  /// MCP 的 elicitation 请求。
  final bool mcpElicitations;

  /// 面板里的固定展示顺序。与 studio 的 `GRANULAR_FIELDS`
  /// （`ApprovalPolicy/index.tsx:46-52`）同序 —— 顺序不同会让两端看起来不是一个功能。
  static const List<GranularField> fields = GranularField.values;

  bool valueOf(GranularField f) => switch (f) {
        GranularField.sandboxApproval => sandboxApproval,
        GranularField.rules => rules,
        GranularField.skillApproval => skillApproval,
        GranularField.requestPermissions => requestPermissions,
        GranularField.mcpElicitations => mcpElicitations,
      };

  GranularApprovalConfig withField(GranularField f, bool v) => switch (f) {
        GranularField.sandboxApproval => copyWith(sandboxApproval: v),
        GranularField.rules => copyWith(rules: v),
        GranularField.skillApproval => copyWith(skillApproval: v),
        GranularField.requestPermissions => copyWith(requestPermissions: v),
        GranularField.mcpElicitations => copyWith(mcpElicitations: v),
      };

  GranularApprovalConfig copyWith({
    bool? sandboxApproval,
    bool? rules,
    bool? skillApproval,
    bool? requestPermissions,
    bool? mcpElicitations,
  }) =>
      GranularApprovalConfig(
        sandboxApproval: sandboxApproval ?? this.sandboxApproval,
        rules: rules ?? this.rules,
        skillApproval: skillApproval ?? this.skillApproval,
        requestPermissions: requestPermissions ?? this.requestPermissions,
        mcpElicitations: mcpElicitations ?? this.mcpElicitations,
      );

  Map<String, Object?> toWire() => {
        for (final f in fields) f.wire: valueOf(f),
      };

  static GranularApprovalConfig fromWire(Map<String, Object?> m) {
    bool read(GranularField f) => m[f.wire] as bool? ?? true;
    return GranularApprovalConfig(
      sandboxApproval: read(GranularField.sandboxApproval),
      rules: read(GranularField.rules),
      skillApproval: read(GranularField.skillApproval),
      requestPermissions: read(GranularField.requestPermissions),
      mcpElicitations: read(GranularField.mcpElicitations),
    );
  }
}

/// granular 的 5 个字段。枚举化是为了让面板能 `for (final f in values)` 摊开，
/// 而不是手写五行几乎一样的开关行。
enum GranularField {
  sandboxApproval('sandbox_approval'),
  rules('rules'),
  skillApproval('skill_approval'),
  requestPermissions('request_permissions'),
  mcpElicitations('mcp_elicitations');

  const GranularField(this.wire);

  /// `config.toml` 里的键名。
  final String wire;
}

// ============================================================================
// 沙箱档位
// ============================================================================

/// sgcode 原生沙箱档位 —— 引擎**真正**的"能动多少东西"开关。
///
/// ⚠️ studio 输入框上那个「对话 / 智能」切换是 lobe 自己的产品概念（存在
/// 它的 agent config 里），**不是这个**，我们不抄。要表达"这轮能做多狠"，
/// sgcode 的答案就是 sandbox_mode。
enum SandboxMode {
  /// 只读。引擎默认。
  readOnly('read-only'),

  /// 可写工作区。
  workspaceWrite('workspace-write'),

  /// 完全放开（危险）。
  dangerFullAccess('danger-full-access');

  const SandboxMode(this.wire);

  final String wire;

  static const SandboxMode defaults = SandboxMode.readOnly;

  static SandboxMode fromWire(Object? v) => values.firstWhere(
        (m) => m.wire == v,
        orElse: () => defaults,
      );
}

// ============================================================================
// 推理强度
// ============================================================================

/// sgcode 原生推理强度。
///
/// 引擎那边还有一个 `Custom(String)` 变体兜住"模型报了个我们还不认识的档位"。
/// 这里不建对应变体：界面是个固定档位选择器，遇到不认识的值显示成默认档即可，
/// 硬造一个 custom 档会在选择器里多出一个点不了的幽灵项。
enum ReasoningEffort {
  none('none'),
  minimal('minimal'),
  low('low'),
  medium('medium'),
  high('high'),
  xhigh('xhigh'),
  max('max'),
  ultra('ultra');

  const ReasoningEffort(this.wire);

  final String wire;

  /// 引擎 `#[default]` 是 Medium。
  static const ReasoningEffort defaults = ReasoningEffort.medium;

  static ReasoningEffort fromWire(Object? v) => values.firstWhere(
        (e) => e.wire == v,
        orElse: () => defaults,
      );
}

// ============================================================================
// 引擎模式（本地 / 云端）
// ============================================================================

/// 内核连接模式 —— 决定调用 `sgit_kernel_open` 还是 `sgit_kernel_open_local`。
///
/// ⚠️ **这不是 config.toml 里的键**，是 Flutter 侧运行时决定的连接方式。
/// 本地模式用进程内引擎，云端模式经 gateway 连 docker 沙箱。
enum EngineMode {
  /// 本地引擎（进程内）
  local('local'),

  /// 云端引擎（经 gateway）
  remote('remote');

  const EngineMode(this.wire);

  final String wire;

  /// 默认本地模式
  static const EngineMode defaults = EngineMode.local;

  static EngineMode fromWire(String? v) => values.firstWhere(
        (m) => m.wire == v,
        orElse: () => defaults,
      );
}

// ============================================================================
// 联网搜索
// ============================================================================

/// `config.toml` 的 `web_search` 键。
///
/// 引擎侧是 `WebSearchMode`（`config/src/config_toml.rs:433`）。输入框只需要
/// 开/关两态，但**读回来可能是引擎的任意一档** —— 所以保留原值，
/// [enabled] 只回答"是不是关着"。这样用户在 CLI 里设的 `cached` 不会被
/// 界面一开一关之间悄悄改成 `enabled`。
@immutable
class WebSearchSetting {
  const WebSearchSetting(this.raw);

  /// 原始档位字符串。`null` = 配置文件里没这个键（跟随引擎默认）。
  final String? raw;

  static const String disabledWire = 'disabled';

  /// 「开」写回哪一档。
  ///
  /// ⚠️ **必须是引擎 `WebSearchMode` 里真实存在的值**，这里是它的
  /// `#[default]`（`protocol/src/config_types.rs`：disabled / cached /
  /// indexed / live）。
  ///
  /// 原先写的是 `'enabled'` —— 那个档位**根本不存在**。后果不是"设置没生效"，
  /// 而是**本地引擎从此起不来**：config.toml 整个解析失败，报
  /// `unknown variant enabled`，而错误里完全看不出跟这个开关有关。
  /// 用户点一下就中招，且只能手工改文件恢复。实测有人中招。
  static const String enabledWire = 'cached';

  /// 是不是开着。
  ///
  /// ⚠️ **键缺失（`raw == null`）算「开」**，不是「关」。
  ///
  /// 引擎侧 `WebSearchMode` 的 `#[default]` 是 `Cached` —— 配置文件里没写过
  /// 这个键就是跟随默认档，也就是开着。
  ///
  /// 这里原先写的是 `raw != null && raw != disabledWire`，把「没配置」当成关，
  /// 与 `tool_catalog.dart` 的 `toolEnabled`（那边判的是
  /// `webSearch == null ? true : ...`）**恰好相反**。同一个键两处判断相反，
  /// 之前因为这个开关整个是空转的（工具压根没下发）所以看不出来；现在它真正
  /// 生效了，分歧会直接表现成「智能体面板显示开、输入框显示关」。
  bool get enabled => raw != disabledWire;

  /// 切换。关 → 恢复成 [enabledWire]；开 → [disabledWire]。
  ///
  /// 注意从"开"切到"关"会丢掉原来的具体档位（比如 `cached`）—— 这是开关控件
  /// 的固有信息损失，无法避免；真要精细控制得去设置页。
  WebSearchSetting toggled() =>
      WebSearchSetting(enabled ? disabledWire : enabledWire);
}

// ============================================================================
// 聚合：一次读回的全部输入框设置
// ============================================================================

/// `SettingsRepository.readPage('tools')` 的解析结果。
///
/// 形状与 Rust 两侧的 `read_tools()` / `sgcode_tools_config()` 对应
/// （`sgit-ffi/src/studio.rs`、`sgit-services/src/bin/gateway.rs`）。
/// 那两个函数**必须同形**，这里只解析一次。
@immutable
class ComposerSettings {
  const ComposerSettings({
    this.approvalPolicy = ApprovalPolicy.defaults,
    this.sandboxMode = SandboxMode.defaults,
    this.reasoningEffort = ReasoningEffort.defaults,
    this.webSearch = const WebSearchSetting(null),
    this.memoryEnabled = true,
    this.engineMode = EngineMode.defaults,
    this.selectedModel,
  });

  final ApprovalPolicy approvalPolicy;
  final SandboxMode sandboxMode;
  final ReasoningEffort reasoningEffort;
  final WebSearchSetting webSearch;

  /// 记忆开关 = `config.toml` 的 `[memories] use_memories`
  /// （"要不要把记忆注入 developer prompt"）。
  ///
  /// ⚠️ **不是 `memories.enabled`** —— 引擎的 `MemoriesTool`
  /// （`config/src/types.rs:283-312`）里没有那个键。写不存在的键不会报错，
  /// 只会静默不生效。
  final bool memoryEnabled;

  /// 引擎模式：本地（进程内）还是云端（gateway）。
  /// ⚠️ 这不是 config.toml 的键，是 Flutter 运行时选项。
  final EngineMode engineMode;

  /// 用户选中的模型 id。`null` = 没选过（用列表第一个，见
  /// `ModelListState.effective`）。
  ///
  /// ⚠️ **必须放在这里，不能放 `ChatComposer` 的 State 里。**
  /// 空态与会话态是 `workspace_page.dart` 里三元切换出来的**两棵不同子树**，
  /// 发第一条消息时旧 widget 销毁、新 widget 挂载 —— 私有字段跟着没了，
  /// 表现就是"L1 选好的模型，进 L2 变回默认"。
  /// 选中的模型是**会话级**状态，本就不该活在某一个 widget 里。
  ///
  /// 也不是 config.toml 的键：它是"这次对话用哪个"，不是引擎的持久配置。
  final String? selectedModel;

  ComposerSettings copyWith({
    ApprovalPolicy? approvalPolicy,
    SandboxMode? sandboxMode,
    ReasoningEffort? reasoningEffort,
    WebSearchSetting? webSearch,
    bool? memoryEnabled,
    EngineMode? engineMode,
    String? selectedModel,
    /// 把 [selectedModel] 显式清成 null（= 选回"默认模型"）。
    ///
    /// ⚠️ 光传 `selectedModel: null` 没用 —— 下面是 `?? this.selectedModel`，
    /// null 会被当成"没传"而保留旧值，用户点了"默认模型"却切不回去。
    bool clearSelectedModel = false,
  }) =>
      ComposerSettings(
        approvalPolicy: approvalPolicy ?? this.approvalPolicy,
        sandboxMode: sandboxMode ?? this.sandboxMode,
        reasoningEffort: reasoningEffort ?? this.reasoningEffort,
        webSearch: webSearch ?? this.webSearch,
        memoryEnabled: memoryEnabled ?? this.memoryEnabled,
        engineMode: engineMode ?? this.engineMode,
        selectedModel:
            clearSelectedModel ? null : (selectedModel ?? this.selectedModel),
      );

  /// 解析 tools 页。缺字段一律回默认 —— 配置文件里没写过的键本来就该是默认值。
  ///
  /// 形状来自两侧同形的 `read_tools()` / `sgcode_tools_config()`。
  /// [keep] 是当前的运行时状态。`engineMode` / `selectedModel` **不在 config.toml 里**，
  /// 每次读盘后必须把它们原样带回来 —— 否则用户选的模型和引擎模式会在
  /// 「改任意一个设置 → 重读配置」之后被悄悄重置。
  static ComposerSettings fromToolsPage(
    Map<String, Object?> json, {
    ComposerSettings? keep,
  }) =>
      ComposerSettings(
        approvalPolicy: ApprovalPolicy.fromWire(json['approvalPolicy']),
        sandboxMode: SandboxMode.fromWire(json['sandboxMode']),
        reasoningEffort: ReasoningEffort.fromWire(json['reasoningEffort']),
        webSearch: WebSearchSetting(json['webSearch'] as String?),
        // 键缺失 = 用户没设过 = 引擎默认开。
        memoryEnabled: json['memoryEnabled'] as bool? ?? true,
        // 这两个是运行时状态，不落配置文件 —— 保留调用方给的当前值。
        engineMode: keep?.engineMode ?? EngineMode.defaults,
        selectedModel: keep?.selectedModel,
      );

  /// `config.toml` 的点分路径 —— 与 `/sgcode-tools/set` 的 `keyPath` 同一套约定。
  ///
  /// 收在这里而不是散在 controller 里：写错一个键名**不会报错**
  /// （config 写入不校验未知键），只会静默不生效 —— 那是最难查的一类 bug。
  static const String approvalPolicyKey = 'approval_policy';
  static const String sandboxModeKey = 'sandbox_mode';
  static const String reasoningEffortKey = 'model_reasoning_effort';
  static const String webSearchKey = 'web_search';
  static const String memoryEnabledKey = 'memories.use_memories';
}
