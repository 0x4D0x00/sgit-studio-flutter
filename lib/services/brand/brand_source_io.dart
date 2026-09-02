import 'dart:io';

import 'package:flutter/widgets.dart';

/// 桌面/移动端品牌资源解析:外置目录优先,回落随包 asset。
///
/// 外置目录 = `$SGIT_BRAND_DIR`,未设则用现网约定的 `/opt/sgit/bin/brand`
/// (studio 的 nginx `location /_brand/` alias 的正是这个目录,两端同一份文件)。
/// 注意宿主 brand 目录下图片实体在 `public/` 子目录,故这里两处都探一遍。

const String _defaultExternalDir = '/opt/sgit/bin/brand';

/// 解析结果缓存:避免每帧 rebuild 都做一次同步 `existsSync`。
final Map<String, ImageProvider> _cache = <String, ImageProvider>{};

String _root() =>
    Platform.environment['SGIT_BRAND_DIR'] ?? _defaultExternalDir;

/// brand.json 在 brand 根,图片实体在 public/ 下 —— 两处都探。
File? _externalFile(String rel) {
  for (final path in <String>['${_root()}/$rel', '${_root()}/public/$rel']) {
    final file = File(path);
    if (file.existsSync()) return file;
  }
  return null;
}

/// 桌面端无需预探测(直接查文件系统)。
Future<void> initBrandSource() async {}

ImageProvider resolveBrandImage(String rel, String assetKey) {
  return _cache.putIfAbsent(rel, () {
    final file = _externalFile(rel);
    return file != null ? FileImage(file) : AssetImage(assetKey);
  });
}

/// 读外置文本资源(如 brand.json)。外置不存在返回 null,由调用方回落随包 asset。
Future<String?> readBrandText(String rel) async =>
    _externalFile(rel)?.readAsString();
