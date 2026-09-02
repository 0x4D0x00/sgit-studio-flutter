import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';

/// 可拖拽宽度 + 可折叠的侧面板（对应 studio 的 `DraggablePanel`）。
///
/// 行为对齐 studio：
/// - 折叠时宽度直接到 **0**（不是变窄），200ms ease-out 动画；
/// - 拖拽把手在**朝向内容的那一侧边缘**（左栏拖右边缘、右栏拖左边缘）；
/// - 宽度夹在 [minWidth]~[maxWidth] 之间。
class ResizablePanel extends StatelessWidget {
  const ResizablePanel({
    super.key,
    required this.child,
    required this.width,
    required this.expanded,
    required this.onWidthChanged,
    required this.side,
    required this.minWidth,
    required this.maxWidth,
    this.backgroundColor,
    this.borderSide,
  });

  final Widget child;
  final double width;
  final bool expanded;
  final ValueChanged<double> onWidthChanged;

  /// 面板贴哪一边：把手画在相对的另一边。
  final AxisDirection side;

  final double minWidth;
  final double maxWidth;
  final Color? backgroundColor;

  /// 面板与内容之间的分割线（studio 右栏有、左栏没有）。
  final BorderSide? borderSide;

  bool get _isLeft => side == AxisDirection.left;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: WorkspaceMetrics.panelAnim,
      curve: Curves.easeOut,
      width: expanded ? width : 0,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: borderSide == null
            ? null
            : Border(
                left: _isLeft ? BorderSide.none : borderSide!,
                right: _isLeft ? borderSide! : BorderSide.none,
              ),
      ),
      // 折叠动画期间宽度会短暂小于内容宽 —— 不裁剪会刷一屏溢出报错。
      clipBehavior: Clip.hardEdge,
      child: OverflowBox(
        alignment: _isLeft ? Alignment.centerLeft : Alignment.centerRight,
        minWidth: 0,
        maxWidth: width,
        child: SizedBox(
          width: width,
          child: Stack(
            children: [
              Positioned.fill(child: child),
              if (expanded) _resizer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resizer() {
    return Positioned(
      top: 0,
      bottom: 0,
      left: _isLeft ? null : 0,
      right: _isLeft ? 0 : null,
      width: WorkspaceMetrics.resizerHitWidth,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: (d) {
            // 左栏往右拖变宽；右栏往左拖变宽 —— 故右栏取反。
            final delta = _isLeft ? d.delta.dx : -d.delta.dx;
            onWidthChanged((width + delta).clamp(minWidth, maxWidth));
          },
        ),
      ),
    );
  }
}
