import 'package:flutter/widgets.dart';

import 'brand_source_io.dart' if (dart.library.html) 'brand_source_web.dart';

// ============================================================================
// 品牌资源「单一事实源」——对齐 sgit-studio 的 `src/utils/brandUrl.ts`。
//
// 组件一律引用下方 [BrandAssets] 的命名常量,**禁止任何地方再硬编码资源路径**。
//
// 资源实体「放在外面」还是「打包进去」,studio 端由 nginx `location /_brand/` 的 alias
// 决定;桌面端没有 nginx,由 [BrandAssets.image] 做同样的两段式解析:
//   · 外置热加载(默认现网): `$SGIT_BRAND_DIR` 或 /opt/sgit/bin/brand 下同名文件存在
//     → 直接读文件,换图即生效,与 studio 共用宿主同一份 brand 目录;
//   · 随包兜底:             回落到 assets/brand/(见 pubspec.yaml),换图需 rebuild。
// 换某个资源只改本文件一处;换资源位置只改外置目录,清单不动。
// ============================================================================

/// 全部品牌资源清单。路径均相对 brand 根(与宿主 /opt/sgit/bin/brand/public 同构)。
class BrandAssets {
  BrandAssets._();

  /// 随包资源前缀(pubspec.yaml 里声明的 assets 根)。
  static const String assetRoot = 'assets/brand/';

  /// 运行时文本配置(产品名/版权等)。
  static const String brandConfig = 'brand.json';

  /// 登录页:背景 + 盾牌 + 字标。
  static const String loginBg = 'images/login/login-bg.png';
  static const String loginMark = 'images/login/logo-mark.png';
  static const String loginWordmark = 'images/login/logo-wordmark.png';

  /// 解析成 [ImageProvider]:外置目录优先,否则随包 asset。
  static ImageProvider image(String rel) =>
      resolveBrandImage(rel, '$assetRoot$rel');
}
