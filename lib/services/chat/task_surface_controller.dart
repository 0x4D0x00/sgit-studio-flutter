import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/chat/task_surface.dart';
import 'package:sgit_studio_flutter/app/app_providers.dart';

/// 后台任务卡片的状态容器。
///
/// 与聊天条目（追加型 `_items`）语义不同：这里是**按 surfaceId 去重的集合**，同 id
/// 覆盖、`ended` 删除。所以单独一个 Notifier，不塞进 ChatController 的列表。
///
/// 只持数据与「怎么调工具」；怎么画由 widget 决定。
class TaskSurfaceController extends Notifier<List<TaskSurface>> {
  @override
  List<TaskSurface> build() => const [];

  /// 收到一帧卡片更新。`ended` 的卡从列表移除，其余按 surfaceId 覆盖/追加。
  void apply(TaskSurface surface) {
    final next = [...state];
    final i = next.indexWhere((s) => s.surfaceId == surface.surfaceId);
    if (surface.ended) {
      if (i >= 0) {
        next.removeAt(i);
        state = next;
      }
      return;
    }
    if (i >= 0) {
      next[i] = surface;
    } else {
      next.add(surface);
    }
    state = next;
  }

  /// 切换会话时清空（卡片是 per-thread 的）。
  void clear() => state = const [];

  /// 点卡片「切过去看」：把 agent 的标签/窗口带到前台。只对 `focusable` 的卡有意义。
  Future<void> focus(TaskSurface surface) async {
    if (!surface.focusable) return;
    await ref.read(kernelClientProvider).toolCall(
      _server(surface.kind),
      'focus_surface',
      arguments: {'surfaceId': surface.surfaceId},
      threadId: surface.threadId ?? '',
    );
  }

  /// 悬停预览：取一帧当前画面（data URL），没有就返回 null。
  Future<String?> preview(TaskSurface surface) async {
    final res = await ref.read(kernelClientProvider).toolCall(
      _server(surface.kind),
      'preview',
      threadId: surface.threadId ?? '',
    );
    // 工具把帧放在 structuredContent.frame。
    final structured = res['structuredContent'];
    if (structured is Map<String, Object?>) {
      final frame = structured['frame'];
      if (frame is String && frame.isNotEmpty) return frame;
    }
    return null;
  }

  /// 哪个 MCP server 提供这类卡片的工具。
  static String _server(String kind) =>
      kind == 'computer' ? 'sgit_computer' : 'sgit_browser';
}

final taskSurfaceProvider =
    NotifierProvider<TaskSurfaceController, List<TaskSurface>>(
  TaskSurfaceController.new,
);
