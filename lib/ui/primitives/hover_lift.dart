import 'package:flutter/material.dart';

/// 卡片悬停手感：轻微放大 + 阴影浮起，由调用方在 [builder] 里按 `hovering`
/// 画出自己的阴影（各卡片的底色/描边不同，统一不了）。
///
/// 技能卡、连接器卡、资源卡、工具行共用这一份，几处 Tab 下的卡片手感才一致。
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.builder,
    this.scale = 1.01,
    this.duration = const Duration(milliseconds: 150),
  });

  /// `hovering` 为 true 时由调用方加阴影。
  final Widget Function(BuildContext context, bool hovering) builder;

  /// 悬停时的缩放倍数。默认 1.01 —— 再大网格里会压到邻居。
  final double scale;

  final Duration duration;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? widget.scale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.builder(context, _hovering),
      ),
    );
  }
}
