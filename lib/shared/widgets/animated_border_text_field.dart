import 'package:flutter/material.dart';

/// 带跑马灯边框效果的输入框。获得焦点时光芒沿边框循环移动。
class AnimatedBorderTextField extends StatefulWidget {
  const AnimatedBorderTextField({
    super.key,
    this.controller,
    this.obscureText = false,
    this.decoration,
    this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final bool obscureText;
  final InputDecoration? decoration;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AnimatedBorderTextField> createState() => _AnimatedBorderTextFieldState();
}

class _AnimatedBorderTextFieldState extends State<AnimatedBorderTextField>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    if (_isFocused) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _isFocused
              ? _MarqueeBorderPainter(
                  progress: _controller.value,
                  color: const Color(0xFFB0E5FC), // 固定冰蓝色（彗星色）
                )
              : null,
          child: TextField(
            controller: widget.controller,
            obscureText: widget.obscureText,
            focusNode: _focusNode,
            onSubmitted: widget.onSubmitted,
            decoration: widget.decoration?.copyWith(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
            ),
          ),
        );
      },
    );
  }
}

/// 跑马灯边框画笔。沿矩形边框画一个带光尾的彗星（椭圆光头 + 渐变拖尾）。
class _MarqueeBorderPainter extends CustomPainter {
  _MarqueeBorderPainter({required this.progress, required this.color});

  final double progress; // 0~1
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    final path = Path()..addRRect(rrect);

    final pathMetrics = path.computeMetrics().first;
    final totalLength = pathMetrics.length;

    // 光点位置(沿路径移动)
    final distance = totalLength * progress;
    final tangent = pathMetrics.getTangentForOffset(distance);
    if (tangent == null) return;

    final position = tangent.position;
    final angle = tangent.angle;

    // 画光尾：从光点向后延伸，渐变透明并逐渐变细
    const tailLength = 100.0; // 光尾长度
    const tailSegments = 30; // 光尾分段数（更多段更平滑）

    final tailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < tailSegments; i++) {
      final t = i / tailSegments;
      final tailDistance = distance - tailLength * t;
      if (tailDistance < 0) continue;

      final tailTangent = pathMetrics.getTangentForOffset(tailDistance % totalLength);
      if (tailTangent == null) continue;

      final alpha = (1.0 - t) * (1.0 - t) * 0.9; // 二次衰减，越靠后越透明
      final strokeWidth = (1.0 - t) * (1.0 - t) * 8.0; // 二次衰减，越靠后越细

      tailPaint.color = color.withValues(alpha: alpha);
      tailPaint.strokeWidth = strokeWidth;

      if (i + 1 < tailSegments) {
        final nextT = (i + 1) / tailSegments;
        final nextDistance = distance - tailLength * nextT;
        if (nextDistance < 0) continue;

        final nextTangent = pathMetrics.getTangentForOffset(nextDistance % totalLength);
        if (nextTangent == null) continue;

        canvas.drawLine(tailTangent.position, nextTangent.position, tailPaint);
      }
    }

    // 画椭圆光头（沿移动方向拉长，缩小尺寸）
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(angle);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 1.0),
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(const Rect.fromLTRB(-12, -5, 12, 5));

    canvas.drawOval(const Rect.fromLTRB(-12, -5, 12, 5), glowPaint); // 椭圆：长24，高10

    canvas.restore();

    // 画底层边框(半透明白)
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _MarqueeBorderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
