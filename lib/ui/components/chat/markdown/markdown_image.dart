import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/markdown_image_local_io.dart'
    if (dart.library.js_interop) 'package:sgit_studio_flutter/ui/components/chat/markdown/markdown_image_local_web.dart';

/// Markdown 里的 `![说明](地址)`。
///
/// 主要用途：agent 完成任务后在最终回复里附一张「完成后的样子」（浏览器 / 桌面软件的
/// `screenshot` 会把图存到本地，并告诉模型用这个写法引用）。所以**本地绝对路径**是
/// 一等公民；`file://`、`data:`、`http(s)://` 也认。
///
/// 尺寸：宽不超过 [maxWidth]、高不超过 [maxHeight]，按原比例缩；点一下全屏查看（可缩放）。
class MarkdownImage extends StatelessWidget {
  const MarkdownImage({
    super.key,
    required this.src,
    this.alt = '',
    this.maxWidth = 480,
    this.maxHeight = 360,
  });

  final String src;
  final String alt;
  final double maxWidth;
  final double maxHeight;

  /// 地址 → 图片来源。认不出或读不到返回 null。
  static ImageProvider? resolve(String src) {
    final s = src.trim();
    if (s.startsWith('data:')) {
      final comma = s.indexOf(',');
      if (comma < 0 || !s.substring(0, comma).contains(';base64')) return null;
      try {
        return MemoryImage(base64Decode(s.substring(comma + 1)));
      } on FormatException {
        return null;
      }
    }
    if (s.startsWith('http://') || s.startsWith('https://')) {
      return NetworkImage(s);
    }
    if (s.startsWith('file://')) {
      final path = Uri.tryParse(s)?.toFilePath(windows: _looksWindows(s));
      return path == null ? null : localImageProvider(path);
    }
    return localImageProvider(s);
  }

  static bool _looksWindows(String s) => RegExp(r'^file:///[A-Za-z]:').hasMatch(s);

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final provider = resolve(src);
    final radius = BorderRadius.circular(6);
    final Widget body = provider == null
        ? _broken(context)
        : Image(
            image: provider,
            fit: BoxFit.contain,
            semanticLabel: alt.isEmpty ? null : alt,
            errorBuilder: (_, _, _) => _broken(context),
          );

    final framed = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: skin.borderSecondary),
        ),
        child: ClipRRect(borderRadius: radius, child: body),
      ),
    );

    if (provider == null) return framed;
    return Tooltip(
      message: alt.isEmpty ? src : alt,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.zoomIn,
        child: GestureDetector(
          onTap: () => _openViewer(context, provider),
          child: framed,
        ),
      ),
    );
  }

  Widget _broken(BuildContext context) {
    final skin = AppSkin.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: skin.containerBgSecondary,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 16, color: skin.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              alt.isEmpty ? src : alt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: skin.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, ImageProvider provider) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: InteractiveViewer(
                  maxScale: 6,
                  child: Center(child: Image(image: provider, fit: BoxFit.contain)),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                tooltip: MaterialLocalizations.of(ctx).closeButtonTooltip,
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
