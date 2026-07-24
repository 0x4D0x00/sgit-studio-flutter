import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_controller.dart';
import 'neon_layer.dart';

/// ★ 三层页面结构(全局基础组件)。所有页面都套这个。
///
/// - **L1** 全透明底层:整个应用不铺任何不透明背景(桌面端因此能看到窗口透明/毛玻璃)。
/// - **L2** 霓虹层:[NeonLayer]，只在有霓虹的位置上色，其余纯透明；跟随主题主色/次色。
/// - **L3** 内容层:传入的 [child]，浮在最上。
///
/// 用法:页面直接 `return LayeredScaffold(child: ...)`；或在 App 根/Shell 处包一层，
/// 内部页面只写 L3 内容。这里默认**每页自带**，也可通过 [showNeon] 关掉某页的霓虹。
class LayeredScaffold extends ConsumerWidget {
  const LayeredScaffold({super.key, required this.child, this.showNeon = true});

  final Widget child;
  final bool showNeon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final transparentMode = ref.watch(themeControllerProvider.select((s) => s.transparentMode));

    return Stack(
      children: [
        // L0 · 稍透底色(深灰/浅白，亮一点)。透明模式下完全透明。
        if (!transparentMode)
          Positioned.fill(
            child: ColoredBox(
              color: isDark
                  ? const Color(0xFF1A1A1A).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.92),
            ),
          ),

        // L1 · 全透明(保留结构)。
        const Positioned.fill(child: ColoredBox(color: Colors.transparent)),

        // L2 · 霓虹层(固定紫粉蓝渐变)。透明模式下隐藏。
        if (showNeon && !transparentMode)
          Positioned.fill(
            child: NeonLayer(intensity: isDark ? 1.0 : 0.5),
          ),

        // L3 · 内容层。
        Positioned.fill(child: child),
      ],
    );
  }
}
