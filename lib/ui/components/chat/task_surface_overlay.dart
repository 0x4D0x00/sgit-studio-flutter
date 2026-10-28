import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/services/chat/task_surface_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/task_surface_card.dart';

/// 常驻右下角的后台任务卡片层。挂在全局 builder 里，跨页面都在。
///
/// 没有卡片时完全不占位（`IgnorePointer` + 空），有卡片才浮出来。多张卡竖排。
class TaskSurfaceOverlay extends ConsumerWidget {
  const TaskSurfaceOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final surfaces = ref.watch(taskSurfaceProvider);
    if (surfaces.isEmpty) return const SizedBox.shrink();

    // ⚠️ 必须自带一个 Overlay。本组件挂在 app.dart 的全局 Stack 里、和路由内容平级，
    // 不在任何 Navigator/Overlay 子树内；而卡片的悬停预览用 `Overlay.of(context)` 插浮窗，
    // 没有这层 Overlay 就会抛 "No Overlay widget found"，被卡片里的 catch 吞掉 ——
    // 表现正是"悬停没有任何反应、预览弹不出来"（实测过的 bug）。
    // 用 Overlay 的 initialEntries 把卡片列表本身作为第 0 层，悬停浮窗插在其上。
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final s in surfaces) ...[
                  TaskSurfaceCard(key: ValueKey(s.surfaceId), surface: s),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
