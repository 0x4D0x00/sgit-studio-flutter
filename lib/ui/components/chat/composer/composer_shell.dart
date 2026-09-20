import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/composer_metrics.dart';

/// 输入框的磨砂玻璃外壳 —— 1:1 对齐 studio 的 `getGlassInputStyle`
/// （`features/ChatInput/glassInputStyle.ts:7-17`）。
///
/// ## 与 [GlassCard] 的关系
///
/// 结构同源（半透明底 + `BackdropFilter` + `blurSigma<=0` 整层不建的降级），
/// 但**不复用它**：那个用 `glassBg/glassBorder`（卡片语义、模糊 16、描边 1.5px），
/// 输入框用 `inputBg/inputBorder/inputShadow`（模糊 12、描边 1px）。
/// 硬凑成一个组件就得加一堆参数把每个差异都开成开关，还不如两份各自清楚。
///
/// ## 那道顶部高光
///
/// studio 靠 `box-shadow: inset 0 1px 0 rgba(255,255,255,.5)` 做。
/// Flutter 的 [BoxDecoration] **没有 inset shadow** —— 这里在内侧叠一条 1px 的
/// 渐变顶边代替。别删：暗色下少了它，磨砂面会平得像一块灰卡片。
///
/// ⚠️ 纯展示组件：不 import 状态库、不 import features、不判 `isDark`。
class ComposerShell extends StatelessWidget {
  const ComposerShell({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;

  /// 覆盖默认的四边 [ComposerMetrics.shellPadding]。
  /// 传 [EdgeInsets.zero] 时由调用方自己给子树上内边距。
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final radius = BorderRadius.circular(ComposerMetrics.shellRadius);

    // 尊重特效分级：皮肤把 blurSigma 降到 0 时整层不建（不是把半径设 0 ——
    // 那样依然要付一次离屏合成）。见 GlassCard 同款注释。
    final sigma =
        skin.blurSigma <= 0 ? 0.0 : ComposerMetrics.shellBlurSigma;

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: skin.inputBg,
        borderRadius: radius,
        border: Border.all(
          color: skin.inputBorder,
          width: ComposerMetrics.shellBorderWidth,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: padding ??
                const EdgeInsets.all(ComposerMetrics.shellPadding),
            child: child,
          ),
          // inset 0 1px 0 的替身。IgnorePointer：它盖在内容顶部，
          // 不挡住第一行文字的点击/选区。
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: ComposerMetrics.shellInsetHighlightHeight,
                decoration: BoxDecoration(
                  color: skin.inputInsetHighlight,
                  borderRadius: BorderRadius.only(
                    topLeft: radius.topLeft,
                    topRight: radius.topRight,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // 投影必须在 ClipRRect **外面** —— 裁剪会把它一起剪掉。
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: skin.inputShadow,
      ),
      child: sigma <= 0
          ? ClipRRect(borderRadius: radius, child: surface)
          : ClipRRect(
              borderRadius: radius,
              // RepaintBoundary：模糊层一重绘就要重采样底下所有像素，
              // 别让它跟着邻居（消息列表滚动）一起重绘。
              child: RepaintBoundary(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: surface,
                ),
              ),
            ),
    );
  }
}
