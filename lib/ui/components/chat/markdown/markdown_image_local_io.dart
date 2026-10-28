import 'dart:io';

import 'package:flutter/painting.dart';

/// 本地图片文件（桌面端）。文件不存在返回 null，由调用方画占位。
ImageProvider? localImageProvider(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  return FileImage(file);
}
