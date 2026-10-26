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

    return Positioned(
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
    );
  }
}
