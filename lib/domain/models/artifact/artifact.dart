import 'package:flutter/foundation.dart';

/// 输出产物（对话中生成的代码片段、文档等）。
///
/// ⚠️ 内核端点待接 —— 目前是空数据源，等 `/sgcode-artifact/list` 放开后
/// 再对接真实数据（见 `features/artifacts/application/artifacts_controller.dart`）。
@immutable
class Artifact {
  const Artifact({
    required this.id,
    required this.title,
    required this.preview,
    required this.language,
    required this.updatedAt,
  });

  /// 产物唯一标识（后端分配）。
  final String id;

  /// 标题（用户可编辑，或自动生成）。
  final String title;

  /// 预览文本（代码片段前几行 / 文档摘要）。
  final String preview;

  /// 语法高亮语言标识（dart / js / markdown / plain 等）。
  final String language;

  /// 最后编辑时间。
  final DateTime updatedAt;

  factory Artifact.fromJson(Map<String, dynamic> json) => Artifact(
        id: json['id'] as String,
        title: json['title'] as String,
        preview: json['preview'] as String,
        language: json['language'] as String? ?? 'plain',
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'preview': preview,
        'language': language,
        'updatedAt': updatedAt.toIso8601String(),
      };
}
