import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:sgit_studio_flutter/services/brand/brand_assets.dart';
import 'brand_source_io.dart' if (dart.library.html) 'brand_source_web.dart';

/// 品牌**文本**配置（产品名/版权等），来源与图片同一套：
/// 外置 `/opt/sgit/bin/brand/brand.json`（Web 为同源 `/_brand/brand.json`）优先，
/// 回落随包 `assets/brand/brand.json`。
///
/// ⚠️ **任何界面上的产品名一律读这里，禁止在代码/arb/index.html 里写死**
/// （任何具体品牌名都不许出现在源码里）——客户换品牌只改
/// brand.json 一处，不用改代码、不用重新构建。
///
/// 字段与 studio 的 `store/brand` 对齐（brand.json 由同一份文件供两端读）。
class BrandConfig {
  const BrandConfig({
    required this.name,
    required this.fullName,
    required this.chatName,
    required this.codeName,
    required this.orgName,
    required this.slogan,
    required this.copyright,
  });

  final String name;
  final String fullName;
  final String chatName;
  final String codeName;
  final String orgName;
  final String slogan;
  final String copyright;

  /// 兜底值：brand.json 缺失/损坏时用。**刻意留空**——宁可界面上没有名字，
  /// 也不要把某个品牌名写死进代码，否则就绕过了单一事实源。
  static const BrandConfig fallback = BrandConfig(
    name: '',
    fullName: '',
    chatName: '',
    codeName: '',
    orgName: '',
    slogan: '',
    copyright: '',
  );

  static BrandConfig _instance = fallback;

  /// 全局品牌配置。[load] 之前读到的是 [fallback]。
  static BrandConfig get instance => _instance;

  /// 启动时加载一次（`main()` 里 `runApp` 之前 await）。
  static Future<void> load() async {
    await initBrandSource();
    String? raw = await readBrandText(BrandAssets.brandConfig);
    raw ??= await _tryAsset();
    if (raw == null) return;
    try {
      final json = jsonDecode(raw);
      if (json is Map) _instance = BrandConfig._fromJson(json);
    } catch (_) {
      // 坏 JSON 不该让应用起不来，保持 fallback。
    }
  }

  static Future<String?> _tryAsset() async {
    try {
      return await rootBundle
          .loadString('${BrandAssets.assetRoot}${BrandAssets.brandConfig}');
    } catch (_) {
      return null;
    }
  }

  factory BrandConfig._fromJson(Map<dynamic, dynamic> j) {
    String s(String k) => (j[k] ?? '').toString();
    return BrandConfig(
      name: s('name'),
      fullName: s('fullName'),
      chatName: s('chatName'),
      codeName: s('codeName'),
      orgName: s('orgName'),
      slogan: s('slogan'),
      copyright: s('copyright'),
    );
  }

  /// 窗口标题 / 浏览器标签用：优先 fullName，退到 name。
  String get title => fullName.isNotEmpty ? fullName : name;
}
