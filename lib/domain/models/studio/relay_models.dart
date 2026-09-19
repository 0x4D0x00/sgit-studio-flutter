import 'package:flutter/foundation.dart';

/// 大模型中转站的领域模型。
///
/// 三级结构（对齐 memory `relay-l1l2l3-provider-crud`）：
/// **L1 厂商卡片墙 → L2 该厂商的模型 → L3 密钥池**。
///
/// ⚠️ **L3 是「品牌级」的，不是「模型级」** —— 一个厂商下所有模型共用一池密钥，
/// 按厂商的 `model_code` 归集（`apikey/listByModel` 的 `model_code` 参数收的是
/// 厂商代码，不是模型名，这个命名很误导）。早先按模型名取，永远查不到。
///
/// 字段名来自 `silicoid.db` 的 `relay_providers` / `relay_models` / `relay_api_keys`
/// 三张表（实测，不是猜的）。
///
/// ## tag 与作用域
/// `tag=builtin` 是管理版（母版）的行，`tag=custom` 是个人版的行，**同一个
/// model_code 两行并存是正常的**，靠 tag 区分。缺 tag 的历史行按 builtin 处理。
/// 不按 tag 过滤会同时拿到两行 → 改了一行读了另一行，表现为"开关不生效"。

/// L1：厂商。
@immutable
class RelayProvider {
  const RelayProvider({
    required this.code,
    required this.name,
    required this.enabled,
    this.provider = '',
    this.baseUrl = '',
    this.endpoint = '',
    this.modelsEndpoint = '',
    this.uploadBaseUrl = '',
    this.modelType = 'external',
    this.priority = 0,
    this.tag = 'builtin',
  });

  /// `model_code` —— 厂商唯一标识（主键），下钻与密钥池都按它取。
  final String code;

  /// 显示名（`display_name`，缺则回落 `provider`）。
  final String name;

  /// `status`：1 启用 / 0 停用。
  ///
  /// ⚠️ 停用的厂商会挡住同步等管理动作（见 memory
  /// `relay-sync-blocked-by-provider-status`），所以界面上必须**明确显示**停用态，
  /// 不能只是灰一下 —— 否则用户只会看到"同步失败"却不知道为什么。
  final bool enabled;

  /// `provider` —— logo / 分组标签（`openai` / `deepseek` …），与 [code] 不同。
  final String provider;

  final String baseUrl;

  /// 聊天端点，如 `/v1/chat/completions`。
  final String endpoint;

  /// 模型列表端点，如 `/v1/models`。同步模型时用。
  final String modelsEndpoint;

  final String uploadBaseUrl;

  /// `external` / `internal`。
  final String modelType;

  final int priority;

  /// `builtin` = 管理版，`custom` = 个人版。
  final String tag;

  bool get isCustom => tag == 'custom';

  /// 表单显示用：显示名优先，回落厂商代码。
  String get label => name.isNotEmpty ? name : code;

  static RelayProvider fromRow(Map<String, Object?> r) => RelayProvider(
        code: _s(r, 'model_code'),
        name: _s(r, 'display_name').isNotEmpty
            ? _s(r, 'display_name')
            : _s(r, 'provider'),
        enabled: _i(r, 'status') == 1,
        provider: _s(r, 'provider'),
        baseUrl: _s(r, 'base_url'),
        endpoint: _s(r, 'endpoint'),
        modelsEndpoint: _s(r, 'models_endpoint'),
        uploadBaseUrl: _s(r, 'upload_base_url'),
        modelType: _s(r, 'model_type', 'external'),
        priority: _i(r, 'priority'),
        tag: _s(r, 'tag', 'builtin'),
      );

  /// 新增时的整对象 payload（`createProvider` 收 `provider: {...}`）。
  Map<String, Object?> toCreateRow() => {
        'model_code': code,
        // 空则回落厂商代码，与 React studio 的 `provider || model_code` 一致。
        'provider': provider.isNotEmpty ? provider : code,
        'display_name': name,
        'base_url': baseUrl,
        'endpoint': endpoint,
        'models_endpoint': modelsEndpoint,
        'upload_base_url': uploadBaseUrl,
        'model_type': modelType,
        'priority': priority,
        'status': enabled ? 1 : 0,
      };

  /// 编辑时的局部 updates。
  ///
  /// ⚠️ **不含 `model_code`（主键不可改）也不含 `status`** —— 启停是卡片开关的
  /// 独立动作，混进来会让"编辑表单一保存就把开关状态覆盖回去"。
  Map<String, Object?> toUpdates() => {
        'provider': provider.isNotEmpty ? provider : code,
        'display_name': name,
        'base_url': baseUrl,
        'endpoint': endpoint,
        'models_endpoint': modelsEndpoint,
        'upload_base_url': uploadBaseUrl,
        'model_type': modelType,
        'priority': priority,
      };

  RelayProvider copyWith({
    String? code,
    String? name,
    bool? enabled,
    String? provider,
    String? baseUrl,
    String? endpoint,
    String? modelsEndpoint,
    String? uploadBaseUrl,
    String? modelType,
    int? priority,
    String? tag,
  }) =>
      RelayProvider(
        code: code ?? this.code,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        provider: provider ?? this.provider,
        baseUrl: baseUrl ?? this.baseUrl,
        endpoint: endpoint ?? this.endpoint,
        modelsEndpoint: modelsEndpoint ?? this.modelsEndpoint,
        uploadBaseUrl: uploadBaseUrl ?? this.uploadBaseUrl,
        modelType: modelType ?? this.modelType,
        priority: priority ?? this.priority,
        tag: tag ?? this.tag,
      );

  /// 新增表单的空草稿。
  static const empty = RelayProvider(code: '', name: '', enabled: true);
}

/// L2：模型。
@immutable
class RelayModel {
  const RelayModel({
    required this.name,
    required this.displayName,
    required this.providerCode,
    required this.available,
    this.contextWindow,
    this.maxOutputTokens,
    this.tag = 'builtin',
  });

  /// `model_name` —— 发请求时用的真名，也是这一行的业务主键。
  final String name;

  final String displayName;

  /// 所属厂商的 `model_code`。
  final String providerCode;

  /// `is_available`。
  final bool available;

  final int? contextWindow;
  final int? maxOutputTokens;

  /// `builtin` = 平台同步，`custom` = 个人直连（只落本地库、不上服务器）。
  final String tag;

  bool get isCustom => tag == 'custom';

  static RelayModel fromRow(Map<String, Object?> r) => RelayModel(
        name: _s(r, 'model_name'),
        displayName: _s(r, 'model_display_name').isNotEmpty
            ? _s(r, 'model_display_name')
            : _s(r, 'model_name'),
        providerCode: _s(r, 'model_code'),
        available: _i(r, 'is_available') == 1,
        contextWindow:
            r['context_window'] == null ? null : _i(r, 'context_window'),
        maxOutputTokens:
            r['max_output_tokens'] == null ? null : _i(r, 'max_output_tokens'),
        tag: _s(r, 'tag', 'builtin'),
      );

  Map<String, Object?> toRow() => {
        'model_name': name,
        'model_display_name': displayName,
        'model_code': providerCode,
        'is_available': available ? 1 : 0,
        if (contextWindow != null) 'context_window': contextWindow,
        if (maxOutputTokens != null) 'max_output_tokens': maxOutputTokens,
      };

  RelayModel copyWith({
    String? name,
    String? displayName,
    String? providerCode,
    bool? available,
    int? contextWindow,
    int? maxOutputTokens,
    String? tag,
  }) =>
      RelayModel(
        name: name ?? this.name,
        displayName: displayName ?? this.displayName,
        providerCode: providerCode ?? this.providerCode,
        available: available ?? this.available,
        contextWindow: contextWindow ?? this.contextWindow,
        maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
        tag: tag ?? this.tag,
      );

  /// 新增表单的空草稿（挂在某厂商下）。
  static RelayModel emptyFor(String providerCode) => RelayModel(
        name: '',
        displayName: '',
        providerCode: providerCode,
        available: true,
      );
}

/// L3：密钥。
///
/// ⚠️ **两条路都不给明文**：本地 FFI 那边 `relay_local_apikeys_to_json`
/// 解密后只回尾 6 位，gateway 那边服务端同样下发脱敏串。界面永远显示后 6 位
/// （memory `relay-three-tables-tag-status-mask` 的约定）。
/// React studio 那边直接把明文渲染到页面上了，我们不跟。
@immutable
class RelayApiKey {
  const RelayApiKey({
    required this.id,
    required this.raw,
    required this.enabled,
    this.name = '',
    this.modelCode = '',
  });

  final String id;

  /// 后端给的 `api_key` 字段。**不渲染原文**，只用来算 [masked]。
  ///
  /// 两种模式下拿到的都**不是明文**：
  /// - 本地 FFI：`relay_local_apikeys_to_json` 已解密并脱敏成 `***...尾6位`；
  /// - gateway：服务端同样下发脱敏串。
  ///
  /// 两者的尾 6 位一致，所以下面按尾 6 位重新排版后呈现完全相同。
  final String raw;

  /// 备注名（`key_name`）。
  final String name;

  final bool enabled;

  /// 所属厂商代码。
  final String modelCode;

  /// 界面显示用：只留后 6 位。两种模式下呈现一致。
  String get masked {
    if (raw.length <= 6) return raw.isEmpty ? '' : '••••••';
    return '••••••${raw.substring(raw.length - 6)}';
  }

  /// 带备注名的显示串。
  String get label => name.isEmpty ? masked : '$name: $masked';

  static RelayApiKey fromRow(Map<String, Object?> r) => RelayApiKey(
        id: _s(r, 'id'),
        raw: _s(r, 'api_key'),
        name: _s(r, 'key_name'),
        enabled: _i(r, 'status') == 1,
        modelCode: _s(r, 'model_code'),
      );
}

String _s(Map<String, Object?> r, String k, [String fallback = '']) =>
    r[k]?.toString() ?? fallback;

int _i(Map<String, Object?> r, String k) => switch (r[k]) {
      final num n => n.toInt(),
      final String s => int.tryParse(s) ?? 0,
      final bool b => b ? 1 : 0,
      _ => 0,
    };
