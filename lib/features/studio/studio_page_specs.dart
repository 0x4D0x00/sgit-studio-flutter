import 'package:flutter/foundation.dart';

/// 一个 studio 子页的数据契约。**8 页共用一套 UI，各页只是一份 spec。**
///
/// 这是「拒绝重」在这里的兑现：7 页纯配置（每页 ~20 行），只有大模型中转站因为是
/// L1/L2/L3 三级页 + 厂商 CRUD（见 memory `relay-l1l2l3-provider-crud`）才单独写。
///
/// 端点契约来自 gateway 的 `/sgcode-*` handler，字段名是**实测**的，不是猜的
/// （猜字段名的教训见 `docs/KERNEL_FFI.md` §2.1.0）。
@immutable
class ResourcePageSpec {
  const ResourcePageSpec({
    required this.key,
    required this.listPath,
    required this.listField,
    required this.idField,
    required this.nameField,
    this.descField = 'description',
    this.enabledField,
    this.removePath,
    this.refreshPath,
    this.extraFields = const [],
    this.detailKind = DetailKind.none,
  });

  /// 与 `StudioPageDef.key` 一致。**读数据用它**（`SettingsRepository.readPage`），
  /// 桌面按 key 走 FFI 本地读，Web 按 key 查 gateway 端点。
  final String key;

  /// 列表端点（GET）。
  ///
  /// ⚠️ **只剩 Web 那侧在用**（`settings_repository_web.dart` 的 `_pageEndpoints`
  /// 才是它的真源）。桌面/移动走 FFI 本地读，与这个路径无关。
  /// 新增页时留空串即可 —— 空串表示"没有对应的 gateway 端点"。
  final String listPath;

  /// 列表数组在响应里的字段名。**各端点不统一**，所以要配。
  final String listField;

  final String idField;
  final String nameField;
  final String descField;

  /// 开关字段（没有就是不可开关的资源）。
  final String? enabledField;

  /// 删除 / 刷新端点（POST）。为空表示该页不提供这个动作。
  final String? removePath;
  final String? refreshPath;

  /// 要一并带出的附加字段，供列表右侧显示。
  final List<String> extraFields;

  final DetailKind detailKind;
}

/// 详情区怎么渲染。
enum DetailKind {
  /// 不展开详情。
  none,

  /// Markdown 正文（技能）。
  markdown,

  /// 键值表（场景 / 子 Agent 的模型、特性、MCP 开关等）。
  keyValue,
}

/// 8 个子页的注册表。
///
/// ⚠️ **只做个人版（per-cid）**，不做管理版（母版）—— 见 memory
/// `flutter-studio-pages-personal-only`。所以这里不带 `scope` 参数。
abstract final class StudioPageSpecs {
  static const scenes = ResourcePageSpec(
    key: 'scenes',
    listPath: '/sgcode-scene/list',
    listField: 'scenes',
    idField: 'id',
    nameField: 'name',
    removePath: '/sgcode-scene/remove',
    refreshPath: '/sgcode-scene/refresh',
    extraFields: ['model', 'subagents', 'updatedAt'],
    detailKind: DetailKind.keyValue,
  );

  static const subagent = ResourcePageSpec(
    key: 'subagent',
    listPath: '/sgcode-subagent/list',
    listField: 'subagents',
    idField: 'id',
    nameField: 'name',
    removePath: '/sgcode-subagent/remove',
    refreshPath: '/sgcode-subagent/refresh',
    extraFields: ['model', 'reasoningEffort'],
    detailKind: DetailKind.keyValue,
  );

  static const skill = ResourcePageSpec(
    key: 'skill',
    listPath: '/sgcode-skill/list',
    listField: 'skills',
    idField: 'id',
    nameField: 'name',
    removePath: '/sgcode-skill/remove',
    refreshPath: '/sgcode-skill/refresh',
    detailKind: DetailKind.markdown,
  );

  static const mcp = ResourcePageSpec(
    key: 'mcp',
    listPath: '/sgcode-mcp/list',
    listField: 'servers',
    // ⚠️ MCP 用 name 当主键（没有独立 id 字段）。
    idField: 'name',
    nameField: 'name',
    descField: 'command',
    enabledField: 'enabled',
    removePath: '/sgcode-mcp/remove',
    extraFields: ['transport', 'toolCount', 'connected', 'builtin'],
  );

  static const knowledge = ResourcePageSpec(
    key: 'knowledge',
    listPath: '/sgcode-knowledge/list',
    listField: 'files',
    idField: 'id',
    nameField: 'name',
    descField: 'sceneName',
    removePath: '/sgcode-knowledge/remove',
    extraFields: ['scope', 'size', 'updatedAt'],
  );

  /// 记忆笔记。数据源是 `memories/**/*.md`（本地直读，已滤掉引擎管线文件）。
  ///
  /// 只读：笔记的增删由引擎与 `/memories` 工具管，studio 页不插手。
  static const memory = ResourcePageSpec(
    key: 'memory',
    listPath: '',
    listField: 'notes',
    idField: 'id',
    nameField: 'name',
    detailKind: DetailKind.markdown,
  );

  /// 平台密钥。数据源是 `ai_basic_platform.db`（本地直读）。
  ///
  /// ⚠️ 密钥明文**不出 Rust 层** —— `masked` 是脱敏后的尾 4 位
  /// （见 sgit-ffi/src/studio.rs 的 `mask_key`）。
  static const apiKey = ResourcePageSpec(
    key: 'api-key',
    listPath: '',
    listField: 'keys',
    idField: 'id',
    nameField: 'name',
    descField: 'masked',
    extraFields: ['createdAt'],
  );

  /// 按 key 取。
  ///
  /// `tools` 与 `llm-relay` 仍不在此表：前者是开关组（不是列表），
  /// 后者是 L1/L2/L3 三级页（`RelayPage`）—— 硬套通用列表只会更难懂。
  static ResourcePageSpec? of(String key) => switch (key) {
        'scenes' => scenes,
        'subagent' => subagent,
        'skill' => skill,
        'mcp' => mcp,
        'knowledge' => knowledge,
        'memory' => memory,
        'api-key' => apiKey,
        _ => null,
      };
}
