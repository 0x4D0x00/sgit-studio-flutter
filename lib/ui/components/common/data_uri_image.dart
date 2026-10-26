import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 画一张 `data:image/...;base64,...` 的图。解析失败显示占位，不抛异常。
///
/// 卡片缩略图和悬停预览都用它 —— data URL 的解析套路（剥前缀 + base64Decode）集中一处。
class DataUriImage extends StatelessWidget {
  const DataUriImage({
    super.key,
    required this.bytes,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  /// 已经解好的字节（调用方用 `TaskSurface.thumbnailBytes` 之类拿到）。
  final Uint8List? bytes;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final data = bytes;
    if (data == null || data.isEmpty) {
      return _placeholder(context);
    }
    return Image.memory(
      data,
      fit: fit,
      width: width,
      height: height,
      gaplessPlayback: true, // 换帧时不闪白
      errorBuilder: (_, _, _) => _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: scheme.onSurfaceVariant, size: 20),
    );
  }
}
