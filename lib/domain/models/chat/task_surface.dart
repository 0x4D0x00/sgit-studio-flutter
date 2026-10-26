import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 后台任务卡片的一条数据。对应 sgit-code 的 `_meta["sgcode/toolSurface"]`，
/// 契约见 `sgit-kernel/docs/tool-surface.md`。
///
/// 这是**纯数据 + 解析**，不含任何业务逻辑：同一个 [surfaceId] 后到的覆盖先到的，
/// [ended] 为真表示该收卡。
@immutable
class TaskSurface {
  const TaskSurface({
    required this.surfaceId,
    required this.kind,
    this.threadId,
    this.prompt,
    this.title,
    this.url,
    this.app,
    this.step,
    this.status,
    this.thumbnail,
    this.tabs = const [],
    this.activeTabId,
    this.focusable = false,
    this.ended = false,
  });

  /// 卡片身份。`tab:123` / `exec:...` / `agent:...`。
  final String surfaceId;

  /// `browser` / `computer` / `exec` / `agent`。
  final String kind;

  final String? threadId;

  /// 卡片第一行：用户交给 agent 的任务（内核补的）。
  final String? prompt;

  /// 副标题：页面标题 / 窗口标题 / 命令 / 子代理任务。
  final String? title;

  final String? url;
  final String? app;

  /// 刚做完的一步，一行。
  final String? step;

  /// 子代理状态（kind=agent 时）。
  final String? status;

  /// 缩略图 data URL（`data:image/jpeg;base64,...`）。
  final String? thumbnail;

  final List<TaskSurfaceTab> tabs;
  final String? activeTabId;

  /// 能否「切过去看」。false 时不显示展开入口（云端沙箱、headless 等）。
  final bool focusable;

  final bool ended;

  /// 从帧 JSON 解析。缺 `surfaceId` 返回 null（没法当卡片用）。
  static TaskSurface? fromJson(Map<String, Object?> j) {
    final id = j['surfaceId']?.toString();
    if (id == null || id.isEmpty) return null;
    final tabsRaw = j['tabs'];
    final tabs = tabsRaw is List
        ? tabsRaw
              .whereType<Map<String, Object?>>()
              .map(TaskSurfaceTab.fromJson)
              .toList(growable: false)
        : const <TaskSurfaceTab>[];
    return TaskSurface(
      surfaceId: id,
      kind: j['kind']?.toString() ?? 'browser',
      threadId: j['threadId']?.toString(),
      prompt: _str(j['prompt']),
      title: _str(j['title']),
      url: _str(j['url']),
      app: _str(j['app']),
      step: _str(j['step']),
      status: _str(j['status']),
      thumbnail: _str(j['thumbnail']),
      tabs: tabs,
      activeTabId: _str(j['activeTabId']),
      focusable: j['focusable'] == true,
      ended: j['ended'] == true,
    );
  }

  /// 缩略图解码成字节，供 `Image.memory` 用。非 data URL 或解析失败返回 null。
  /// 套路同 `user_profile_controller` 的头像解析。
  Uint8List? get thumbnailBytes => decodeDataUri(thumbnail);

  /// 把任意 `data:...;base64,...` 解成字节。悬停预览帧也用它。
  static Uint8List? decodeDataUri(String? dataUri) {
    if (dataUri == null) return null;
    final comma = dataUri.indexOf(',');
    if (comma < 0 || !dataUri.startsWith('data:')) return null;
    try {
      return base64Decode(dataUri.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }

  static String? _str(Object? v) {
    final s = v?.toString();
    return (s == null || s.isEmpty) ? null : s;
  }
}

/// 卡片里一个标签页的概要。
@immutable
class TaskSurfaceTab {
  const TaskSurfaceTab({required this.id, this.title, this.url});

  final String id;
  final String? title;
  final String? url;

  static TaskSurfaceTab fromJson(Map<String, Object?> j) => TaskSurfaceTab(
    id: j['id']?.toString() ?? '',
    title: j['title']?.toString(),
    url: j['url']?.toString(),
  );
}
