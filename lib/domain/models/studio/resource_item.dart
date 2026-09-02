import 'package:flutter/foundation.dart';

/// studio 子页的资源条目 —— 8 个页面共用的**同一个**形状。
///
/// 各端点返回的字段名不一致（`scenes`/`skills`/`subagents`/`servers`/`files`），
/// 但结构高度相似：都是「有个 id、有个显示名、有段描述、可能带开关和若干附加信息」。
/// 所以收敛成这一个类型，8 页共用一套列表/详情 UI，不写 8 遍。
///
/// [extras] 放各页专属字段（MCP 的 `toolCount`、知识库的 `size` 等），
/// 由各自的 spec 决定怎么显示。
@immutable
class ResourceItem {
  const ResourceItem({
    required this.id,
    required this.name,
    this.description = '',
    this.enabled,
    this.extras = const {},
  });

  final String id;
  final String name;
  final String description;

  /// 有开关的资源（MCP / 工具）才非空。
  final bool? enabled;

  final Map<String, Object?> extras;

  String extra(String key, [String fallback = '']) =>
      extras[key]?.toString() ?? fallback;

  int? extraInt(String key) => switch (extras[key]) {
        final num n => n.toInt(),
        final String s => int.tryParse(s),
        _ => null,
      };
}
