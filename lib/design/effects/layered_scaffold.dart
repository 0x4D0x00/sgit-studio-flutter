import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/effects/neon_layer.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';

/// ★ 四层页面结构（全局基础组件）。所有页面都套这个。
///
/// - **L0** 底色层：[AppSkin.baseBg]。透明模式下该值为全透明，桌面/毛玻璃直接透上来。
/// - **L1** 背景层：默认全透明；传 [backgroundImage] 时在这一层铺全屏背景图（cover）。
/// - **L2** 霓虹层：[NeonLayer]，只在有霓虹的位置上色。是否绘制由 [AppSkin.showNeon] 决定。
/// - **L3** 内容层：[child]，浮在最上。
///
/// ⚠️ 本组件**不依赖任何状态管理库** —— 明暗与透明模式的差异全部在 [AppSkin] 里解决过了。
/// 单页要强制关霓虹时传 `showNeon: false`。
class LayeredScaffold extends StatelessWidget {
  const LayeredScaffold({
    super.key,
    required this.child,
    this.showNeon = true,
    this.backgroundImage,
  });

  final Widget child;

  /// 页面级关闭霓虹。与皮肤的 [AppSkin.showNeon] 取「与」—— 两者都为真才画。
  final bool showNeon;

  /// L1 背景图（可选）。不传时 L1 保持纯透明。
  final ImageProvider? backgroundImage;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final neon = showNeon && skin.showNeon;

    return Stack(
      children: [
        // L0 · 底色。透明模式下 baseBg 是 Colors.transparent，等于不画。
        Positioned.fill(child: ColoredBox(color: skin.baseBg)),

        // L1 · 背景层。
        if (backgroundImage != null)
          Positioned.fill(
            child: Image(
              image: backgroundImage!,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

        // L2 · 霓虹层。RepaintBoundary 隔开：霓虹是静态的，别被上层内容的重绘带着重画。
        if (neon)
          Positioned.fill(
            child: RepaintBoundary(
              child: NeonLayer(intensity: skin.neonIntensity),
            ),
          ),

        // L3 · 内容层。
        Positioned.fill(child: child),
      ],
    );
  }
}
