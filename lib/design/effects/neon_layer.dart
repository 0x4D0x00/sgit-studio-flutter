import 'package:flutter/material.dart';

/// L2 · 霓虹层。**只在有霓虹光晕的位置上色，其余纯透明**。
///
/// 用若干径向渐变模拟霓虹辉光:**固定紫→粉→蓝渐变色**，不跟随主题。
/// 整层不铺任何不透明底色——底下的 L1 透过来仍是全透明。
class NeonLayer extends StatelessWidget {
  const NeonLayer({super.key, this.intensity = 1.0});

  /// 辉光强度(0~1)，用于浅色主题下调弱。
  final double intensity;

  // 固定霓虹色:再次调深饱和度。
  static const _color1 = Color(0xFFC76ADE); // 粉紫(更深)
  static const _color2 = Color(0xFF8B8FED); // 淡紫(更深)
  static const _color3 = Color(0xFF5AADE8); // 淡蓝(更深)

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        // 第一色(左上)
        decoration: BoxDecoration(
          gradient: _glow(const Alignment(-0.9, -0.8), _color1, 0.55, radius: 1.1),
        ),
        child: DecoratedBox(
          // 第二色(中间)
          decoration: BoxDecoration(
            gradient: _glow(const Alignment(0.1, 0.0), _color2, 0.45, radius: 1.0),
          ),
          child: DecoratedBox(
            // 第三色(右下)
            decoration: BoxDecoration(
              gradient: _glow(const Alignment(1.0, 0.9), _color3, 0.5, radius: 1.2),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  /// 一团径向霓虹辉光:中心色 -> 透明。淡入淡出。
  RadialGradient _glow(Alignment center, Color color, double alpha,
      {double radius = 1.0}) {
    final finalAlpha = alpha * intensity * 0.45;
    return RadialGradient(
      center: center,
      radius: radius,
      colors: [
        color.withValues(alpha: finalAlpha),
        color.withValues(alpha: finalAlpha * 0.6),
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.5, 1.0], // 淡入淡出:中心浓 -> 中间渐变 -> 边缘全透明
    );
  }
}
