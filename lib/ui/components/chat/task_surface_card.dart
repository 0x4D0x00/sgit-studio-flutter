import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/chat/task_surface.dart';
import 'package:sgit_studio_flutter/services/chat/task_surface_controller.dart';
import 'package:sgit_studio_flutter/ui/components/common/data_uri_image.dart';

/// 一张后台任务卡片：第一行任务 prompt，下面一行步骤 + 缩略图。
///
/// - **鼠标悬停** → 上方弹出实时预览小窗（每秒拉一帧 `preview`）；移开即停。
/// - **点击** → `focus_surface`，把 agent 的标签/窗口带到前台（仅 focusable）。
///
/// 卡片本身只认 [TaskSurface] 这份数据，不关心背后是 CDP 扩展、兜底 Chrome 还是以后的
/// Playwright —— 它们产出同一份卡片。
class TaskSurfaceCard extends ConsumerStatefulWidget {
  const TaskSurfaceCard({super.key, required this.surface});

  final TaskSurface surface;

  @override
  ConsumerState<TaskSurfaceCard> createState() => _TaskSurfaceCardState();
}

class _TaskSurfaceCardState extends ConsumerState<TaskSurfaceCard> {
  final _link = LayerLink();
  OverlayEntry? _preview;
  Timer? _pollTimer;
  String? _previewFrame;
  bool _hovering = false;

  @override
  void dispose() {
    _stopPreview();
    super.dispose();
  }

  void _startPreview() {
    if (_preview != null) return;
    _hovering = true;
    _preview = OverlayEntry(builder: _buildPreview);
    Overlay.of(context).insert(_preview!);
    // 立刻拉一帧，然后每秒一帧（agent 跑长动作时也不卡，后端是并发取帧）。
    _pollOnce();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollOnce());
  }

  void _stopPreview() {
    _hovering = false;
    _pollTimer?.cancel();
    _pollTimer = null;
    _preview?.remove();
    _preview = null;
    _previewFrame = null;
  }

  Future<void> _pollOnce() async {
    try {
      final frame = await ref
          .read(taskSurfaceProvider.notifier)
          .preview(widget.surface);
      if (!_hovering) return;
      _previewFrame = frame;
      _preview?.markNeedsBuild();
    } catch (_) {
      // 预览失败不打扰用户：小窗显示占位即可。
    }
  }

  Widget _buildPreview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      width: 360,
      child: CompositedTransformFollower(
        link: _link,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        offset: const Offset(0, -8),
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: DataUriImage(
                bytes: _frameBytes(),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 悬停预览帧优先，没有就退回卡片缩略图（至少有画面，不是全空）。
  Uint8List? _frameBytes() {
    final frame = _previewFrame;
    if (frame != null) {
      final bytes = TaskSurface.decodeDataUri(frame);
      if (bytes != null) return bytes;
    }
    return widget.surface.thumbnailBytes;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.surface;
    final scheme = Theme.of(context).colorScheme;
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _startPreview(),
        onExit: (_) => _stopPreview(),
        cursor: s.focusable ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          onTap: s.focusable
              ? () => ref.read(taskSurfaceProvider.notifier).focus(s)
              : null,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _thumb(scheme),
                const SizedBox(width: 10),
                Expanded(child: _text(scheme)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumb(ColorScheme scheme) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 56,
          height: 44,
          child: DataUriImage(bytes: widget.surface.thumbnailBytes),
        ),
      );

  Widget _text(ColorScheme scheme) {
    final s = widget.surface;
    final theme = Theme.of(context).textTheme;
    final firstLine = s.prompt ?? s.title ?? _kindLabel(s.kind);
    final secondLine = s.step ?? s.title ?? s.url ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(_kindIcon(s.kind), size: 13, color: scheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                firstLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        if (secondLine.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            secondLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        if (s.focusable) ...[
          const SizedBox(height: 4),
          Text(
            '悬停预览 · 点击切过去看',
            style: theme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  static String _kindLabel(String kind) => switch (kind) {
        'browser' => '浏览器任务',
        'computer' => '桌面任务',
        'exec' => '命令执行',
        'agent' => '子代理',
        _ => '后台任务',
      };

  static IconData _kindIcon(String kind) => switch (kind) {
        'browser' => Icons.public,
        'computer' => Icons.desktop_windows_outlined,
        'exec' => Icons.terminal,
        'agent' => Icons.smart_toy_outlined,
        _ => Icons.auto_awesome,
      };
}
