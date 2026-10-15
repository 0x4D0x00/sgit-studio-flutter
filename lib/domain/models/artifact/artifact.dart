import 'package:flutter/foundation.dart';

import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';

/// 输出产物（对话中生成的、在聊天里以文件卡呈现的代码 / 文档 / 图表）。
///
/// 数据来源是会话本身：`ChatController` 在会话载入 / 一轮结束后扫描助手回复里的
/// 长围栏（即 [ChatArtifact.fromBlocks] 的结果），登记到 `ArtifactsController`。
/// 所以输出物页里的每一项都能回溯到 [threadId] 里的某一处围栏。
@immutable
class Artifact {
  const Artifact({
    required this.id,
    required this.title,
    required this.preview,
    required this.language,
    required this.updatedAt,
    this.threadId,
    this.content = '',
    this.kind = ArtifactKind.code,
    this.sourceStart = -1,
  });

  /// 从会话里的 [ChatArtifact] 登记一条。
  ///
  /// id 由 `会话 + 内容指纹 + 围栏偏移` 组成：同一会话每次重新载入都得到同一个 id，
  /// 才能在「载入后整体替换」时保住原有的 [updatedAt]，而不是每次打开都变成"刚刚"。
  factory Artifact.fromChat(
    String threadId,
    ChatArtifact a,
    DateTime updatedAt,
  ) =>
      Artifact(
        id: '$threadId:${_fingerprint(a.content)}:${a.sourceStart}',
        title: a.title,
        preview: _previewOf(a.content),
        language: a.language,
        updatedAt: updatedAt,
        threadId: threadId,
        content: a.content,
        kind: a.kind,
        sourceStart: a.sourceStart,
      );

  /// 产物唯一标识。
  final String id;

  /// 标题（取自代码首行注释 / 围栏上一行描述 / 语言名，见 `ChatArtifact`）。
  final String title;

  /// 预览文本（代码片段前几行）。
  final String preview;

  /// 围栏 info string（dart / yaml / mermaid …）。
  final String language;

  /// 最后编辑时间。
  final DateTime updatedAt;

  /// 产生它的会话。null = 不属于任何会话（不可跳转）。
  final String? threadId;

  /// 完整内容。点击跳转时**先用它直接打开右侧面板**，不必等会话载完。
  final String content;

  final ArtifactKind kind;

  /// 围栏在会话那条消息（规范化后）原文里的偏移，定位用。
  final int sourceStart;

  /// 还原成右侧面板吃的 [ChatArtifact]。
  ChatArtifact toChatArtifact() => ChatArtifact(
        title: title,
        language: language,
        content: content,
        kind: kind,
        sourceStart: sourceStart,
      );

  factory Artifact.fromJson(Map<String, dynamic> json) => Artifact(
        id: json['id'] as String,
        title: json['title'] as String,
        preview: json['preview'] as String? ?? '',
        language: json['language'] as String? ?? 'plain',
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        threadId: json['threadId'] as String?,
        content: json['content'] as String? ?? '',
        kind: ArtifactKind.values.asNameMap()[json['kind']] ?? ArtifactKind.code,
        sourceStart: json['sourceStart'] as int? ?? -1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'preview': preview,
        'language': language,
        'updatedAt': updatedAt.toIso8601String(),
        'threadId': threadId,
        'content': content,
        'kind': kind.name,
        'sourceStart': sourceStart,
      };

  /// 前 8 行、至多 400 字符 —— 卡片预览区只画 6 行，多留的给省略号。
  static String _previewOf(String content) {
    final lines = content.trimLeft().split('\n');
    final head = lines.take(8).join('\n');
    return head.length > 400 ? head.substring(0, 400) : head;
  }

  /// FNV-1a 32 位。**不用 `String.hashCode`**：它不保证跨版本 / 跨进程稳定，
  /// 而 id 要落盘、下次启动还得对得上。
  static String _fingerprint(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16);
  }
}
