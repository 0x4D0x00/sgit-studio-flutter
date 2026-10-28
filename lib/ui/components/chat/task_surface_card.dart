import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/chat/task_surface.dart';
import 'package:sgit_studio_flutter/services/chat/task_surface_controller.dart';
import 'package:sgit_studio_flutter/ui/components/common/data_uri_image.dart';

/// 一张后台任务卡片。
///
/// - **鼠标悬停** → 就在卡片里展开一块实时画面区（每秒拉一帧 `preview`），看 agent
///   当前在操作什么；移开即收起。不弹独立浮窗。
/// - **点击** → `focus_surface`，把 agent 正在操作的那个**真实**浏览器标签/窗口带到前台
///   （仅 `focusable` 的卡有效）。
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
  bool _hovering = false;
  Timer? _pollTimer;
  String? _frame;

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  void _onEnter() {
    setState(() => _hovering = true);
    _startPolling();
  }

  void _onExit() {
    setState(() => _hovering = false);
    _stopPolling();
  }

  /// 点击 = 打开 agent 操作的真实浏览器/应用（切到前台）。只对 `focusable` 的卡有意义。
  void _onTap() {
    ref.read(taskSurfaceProvider.notifier).focus(widget.surface);
  }

  void _startPolling() {
    _pollOnce();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pollOnce());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _frame = null;
  }

  Future<void> _pollOnce() async {
    try {
      final frame = await ref
          .read(taskSurfaceProvider.notifier)
          .preview(widget.surface);
      if (!mounted || !_hovering) return;
      setState(() => _frame = frame);
    } catch (_) {
      // 取帧失败不打扰：预览区退回缩略图。
    }
  }

  Uint8List? _frameBytes() {
    final frame = _frame;
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
    return MouseRegion(
      onEnter: (_) => _onEnter(),
      onExit: (_) => _onExit(),
      cursor: s.focusable ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: s.focusable ? _onTap : null,
        child: Container(
          width: _hovering ? 360 : 300,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovering ? scheme.primary : scheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _thumb(scheme),
                  const SizedBox(width: 10),
                  Expanded(child: _text(scheme)),
                ],
              ),
              if (_hovering) ...[
                const SizedBox(height: 10),
                _livePreview(scheme),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 悬停时展开的实时画面区（持续刷新）。
  Widget _livePreview(ColorScheme scheme) => ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: DataUriImage(bytes: _frameBytes(), fit: BoxFit.cover),
          ),
        ),
      );

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
            if (s.focusable)
              Icon(Icons.open_in_new, size: 14, color: scheme.onSurfaceVariant),
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
            _hovering ? '实时画面 · 点击打开浏览器' : '悬停预览 · 点击打开',
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
