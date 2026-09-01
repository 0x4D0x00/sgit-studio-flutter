import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

/// Web 端品牌资源解析:同源 `/_brand/` 优先,回落随包 asset。
///
/// 与 studio 完全同一套约定 —— nginx `location /_brand/` alias 到宿主
/// `/opt/sgit/bin/brand/public`,换图/换 brand.json 即时生效、无需重新构建。
/// 没配这个 location 时探测失败,自动回落随包资源。
///
/// ⚠️ **探测不能只看 HTTP 200**:SPA 站点的 nginx 通常带
/// `try_files $uri $uri/ /index.html` 回退,未配 `/_brand/` 时请求它会**返回
/// index.html 且状态码 200**。只判状态码/"是否含花括号"会误判成外置可用,
/// 接着拿 HTML 去 jsonDecode 失败 → 品牌名变空、图片全变 404 的 NetworkImage。
/// 所以这里**必须真的把 brand.json 解析成对象并校验关键字段**才认。
///
/// 图片走 [NetworkImage] 没有"404 自动回落"机制,故一次性探测决定整体走哪条路,
/// 而不是每张图各自碰运气。

const String _brandBase = '/_brand/';
const String _brandConfigRel = 'brand.json';

final Dio _dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 5),
  receiveTimeout: const Duration(seconds: 5),
));

bool _external = false;

/// 探测阶段已经把 brand.json 取到手,别再请求第二次。
String? _brandConfigText;

Future<void> initBrandSource() async {
  try {
    final text = await _fetchText(_brandConfigRel);
    if (text == null) return;
    final obj = jsonDecode(text);
    // 必须是对象且带品牌字段 —— 拿到 index.html 时 jsonDecode 直接抛，走 catch。
    if (obj is Map && (obj.containsKey('fullName') || obj.containsKey('name'))) {
      _brandConfigText = text;
      _external = true;
    }
  } catch (_) {
    _external = false;
  }
}

Future<String?> _fetchText(String rel) async {
  final res = await _dio.get<dynamic>(
    '$_brandBase$rel',
    options: Options(responseType: ResponseType.plain),
  );
  return res.statusCode == 200 ? '${res.data}' : null;
}

ImageProvider resolveBrandImage(String rel, String assetKey) =>
    _external ? NetworkImage('$_brandBase$rel') : AssetImage(assetKey);

Future<String?> readBrandText(String rel) async {
  if (!_external) return null;
  if (rel == _brandConfigRel) return _brandConfigText;
  try {
    return await _fetchText(rel);
  } catch (_) {
    return null;
  }
}
