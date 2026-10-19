import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// 一道光沿输入框边缘匀速跑一圈（像赛车绕场），整体渐显起跑、跑完渐隐。
///
/// 移植自 sgit-studio 的 `src/components/OrbitBeam/index.tsx`。那边用 SVG 描边 +
/// `stroke-dashoffset` 实现，这里用 [CustomPainter] 的 `PathMetric` 做同一件事 ——
/// 关键取舍与那边一致，逐条说明：
///
/// - **不用旋转渐变**。conic gradient 在矩形上长边慢、短边快，看着像在抽搐；
///   沿路径按长度取点是匀速的。
/// - **起点每次随机**，且首帧光尾就已铺满 —— 否则能看出"车头从哪冒出来"。
/// - **光尾是若干首尾相接的短段**，每段单独上色与透明度：车头蓝 → 车尾红
///   （中段用逐段插值，避免直接两色混出灰），尾端逐段淡出。
/// - **相邻段只交叠极小一截**（[segmentOverlap]），只为盖住抗锯齿缝；
///   交叠多了半透明会叠出亮点。
///
/// 这是**一次性**装饰反馈，不是"进行中"指示器：发送那一刻起跑，跑完就消失。
class OrbitBeam extends StatefulWidget {
  const OrbitBeam({
    super.key,
    required this.active,
    required this.borderRadius,
    required this.child,
    this.duration = const Duration(milliseconds: 1800),
    this.onComplete,
    this.strokeWidth = 2,
  });

  final bool active;
  final double borderRadius;
  final Widget child;

  /// 跑完一圈的时长。默认 1.8s，与 studio 一致。
  final Duration duration;

  final VoidCallback? onComplete;
  final double strokeWidth;

  @override
  State<OrbitBeam> createState() => _OrbitBeamState();
}

class _OrbitBeamState extends State<OrbitBeam>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  /// 随机起点（路径长度比例 0..1）。每次起跑重掷一次 —— 固定在同一个角
  /// 会让人以为那是"起点标记"，随机才像绕场。
  double _origin = 0;

  @override
  void initState() {
    super.initState();
    _ctl.addStatusListener(_onStatus);
    if (widget.active) _start();
  }

  @override
  void didUpdateWidget(covariant OrbitBeam oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _start();
    } else if (!widget.active && oldWidget.active) {
      _ctl.reset();
    }
  }

  void _start() {
    _origin = math.Random().nextDouble();
    _ctl
      ..reset()
      ..forward();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) widget.onComplete?.call();
  }

  @override
  void dispose() {
    _ctl.removeStatusListener(_onStatus);
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;

    return Stack(
      // 光晕要能画到框外（React 那边是 `overflow: visible`）。
      // Stack 默认 Clip.hardEdge，会把外溢的那半圈光晕直接切掉。
      clipBehavior: Clip.none,
      children: [
        widget.child,
        // IgnorePointer：光在边框上，绝不能挡住框内文字的点击与选区。
        //
        // 画布比输入框四周各大出一圈 [_glowBleed]，光晕画在里侧的正常位置上。
        // 不能只靠 Clip.none 让它溢出：这层在 RepaintBoundary 里，引擎可能把
        // 它缓存成 bounds 大小的纹理，溢出的部分照样丢。
        Positioned(
          left: -_glowBleed,
          top: -_glowBleed,
          right: -_glowBleed,
          bottom: -_glowBleed,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _OrbitBeamPainter(
                  progress: _ctl,
                  origin: _origin,
                  borderRadius: widget.borderRadius,
                  strokeWidth: widget.strokeWidth,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---- 视觉常量：与 studio 的 OrbitBeam 逐项对齐 ----

/// 车头颜色（蓝）。
const Color _headColor = Color(0xFF4A7CFF);

/// 车尾颜色（红）。
const Color _tailColor = Color(0xFFF05464);

/// 光尾长度，占周长的比例。
const double _tailLength = 0.36;

/// 光尾由多少段拼成。
const int _segments = 36;

/// 车头光晕覆盖的段数。
const int _glowSegments = 10;

/// 相邻段交叠量（占周长比例），只为盖住抗锯齿缝。
const double _segmentOverlap = 0.0003;

/// 画布往框外多留的边距。要盖住光晕（3px 描边 + 4px 模糊）。
const double _glowBleed = 12;

/// 整体渐显 / 渐隐各占总时长的比例。
const double _fadeIn = 0.3;
const double _fadeOut = 0.35;

/// 以匀速为主、略带起步加速和收尾减速。
///
/// 纯 ease-in 会让光在渐显时停在原地，暴露起点；纯匀速又显得机械。
double _travel(double p) => 0.75 * p + 0.25 * (0.5 - math.cos(math.pi * p) / 2);

double _smoothstep(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

class _OrbitBeamPainter extends CustomPainter {
  _OrbitBeamPainter({
    required this.progress,
    required this.origin,
    required this.borderRadius,
    required this.strokeWidth,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final double origin;
  final double borderRadius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // 画布比输入框四周各大出 [_glowBleed]（见 build 里的 Positioned），
    // 路径要按这个内缩量还原到真实边框的位置上。
    final borderInset = strokeWidth / 2;
    final inset = borderInset + _glowBleed;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth - _glowBleed * 2,
      size.height - strokeWidth - _glowBleed * 2,
    );
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(math.max(0, borderRadius - borderInset)),
        ),
      );

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final m = metrics.first;
    final total = m.length;
    if (total <= 0) return;

    // 整体渐显 → 保持 → 渐隐。
    final p = progress.value;
    final opacity = _smoothstep(p / _fadeIn) * _smoothstep((1 - p) / _fadeOut);
    if (opacity <= 0) return;

    final segmentLength = _tailLength / _segments;
    final head = origin + _travel(p);

    // 光晕层先画（粗、模糊），再画实体光尾 —— 顺序决定谁盖谁。
    _paintSegments(
      canvas,
      m,
      total,
      head,
      segmentLength,
      opacity * 0.35,
      strokeWidth * 3,
      glow: true,
    );
    _paintSegments(
      canvas,
      m,
      total,
      head,
      segmentLength,
      opacity * 0.9,
      strokeWidth,
      glow: false,
    );
  }

  void _paintSegments(
    Canvas canvas,
    PathMetric metric,
    double total,
    double head,
    double segmentLength,
    double opacity,
    double width, {
    required bool glow,
  }) {
    final count = glow ? _glowSegments : _segments;

    for (var i = 0; i < count; i++) {
      // 前 65% 完成蓝→红过渡，后段保持红色并淡出。
      // ⚠️ 必须走 Oklab，不能用 `Color.lerp`（那是 sRGB 直线）——
      // 蓝红直连的中段会发灰。见 [_mixOklab]。
      final t = math.min(1.0, i / (0.65 * (_segments - 1)));
      final color = _mixOklab(_headColor, _tailColor, t);
      final segOpacity = math.min(1.0, (1 - i / _segments) / 0.55) * opacity;
      // 车头最粗，往车尾逐段变细。
      final widthScale = 1 - (0.35 * i) / _segments;

      // 段在光尾里的位置：车头在 head，往车尾依次倒退。
      final startFraction = head - (i + 1) * segmentLength;
      final startDist = (startFraction % 1.0) * total;
      var endDist = startDist + (segmentLength + _segmentOverlap) * total;
      // 跨过路径首尾接缝时分两段画，保持无缝。
      if (endDist <= total) {
        _drawPiece(canvas, metric, startDist, endDist, color, segOpacity,
            width * widthScale, glow);
      } else {
        _drawPiece(canvas, metric, startDist, total, color, segOpacity,
            width * widthScale, glow);
        _drawPiece(canvas, metric, 0, endDist - total, color, segOpacity,
            width * widthScale, glow);
      }
    }
  }

  void _drawPiece(
    Canvas canvas,
    PathMetric metric,
    double start,
    double end,
    Color color,
    double opacity,
    double width,
    bool glow,
  ) {
    if (end <= start || opacity <= 0) return;
    final piece = metric.extractPath(start, end);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color.withValues(alpha: opacity);
    if (glow) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    }
    canvas.drawPath(piece, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbitBeamPainter old) =>
      old.origin != origin ||
      old.borderRadius != borderRadius ||
      old.strokeWidth != strokeWidth;
}

// ---- Oklab 插值 ----
//
// React 那边写的是 `color-mix(in oklch, tail x%, head)`，**不是**普通的 RGB
// 混合 —— 逐段注释里点明了原因：直接混两色，中段会发灰（蓝和红走 RGB 直线会
// 经过一段低饱和的暗色）。这里补上同一种插值，否则光尾中段会明显比 React 暗。
//
// 标准 Oklab 定义（Björn Ottosson），sRGB ↔ 线性 ↔ LMS 三步换算。

double _srgbToLinear(double c) =>
    c <= 0.040_45 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _linearToSrgb(double c) => c <= 0.003_130_8
    ? c * 12.92
    : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;

/// sRGB 分量（0..1）→ Oklab 的 L / a / b。
List<double> _toOklab(double r, double g, double b) {
  final lr = _srgbToLinear(r);
  final lg = _srgbToLinear(g);
  final lb = _srgbToLinear(b);

  final l = 0.412_221_470_8 * lr + 0.536_332_536_3 * lg + 0.051_445_992_9 * lb;
  final m = 0.211_903_498_2 * lr + 0.680_699_545_1 * lg + 0.107_396_956_6 * lb;
  final s = 0.088_302_461_9 * lr + 0.281_718_837_6 * lg + 0.629_978_700_5 * lb;

  final l_ = math.pow(l, 1 / 3).toDouble();
  final m_ = math.pow(m, 1 / 3).toDouble();
  final s_ = math.pow(s, 1 / 3).toDouble();

  return [
    0.210_454_255_3 * l_ + 0.793_617_785_0 * m_ - 0.004_072_046_8 * s_,
    1.977_998_495_1 * l_ - 2.428_592_205_0 * m_ + 0.450_593_709_9 * s_,
    0.025_904_037_1 * l_ + 0.782_771_766_2 * m_ - 0.808_675_766_0 * s_,
  ];
}

/// Oklab → sRGB 分量（0..1）。
List<double> _fromOklab(double L, double a, double b) {
  final l_ = L + 0.396_337_777_4 * a + 0.215_803_757_3 * b;
  final m_ = L - 0.105_561_345_8 * a - 0.063_854_172_8 * b;
  final s_ = L - 0.089_484_177_5 * a - 1.291_485_548_0 * b;

  final l = l_ * l_ * l_;
  final m = m_ * m_ * m_;
  final s = s_ * s_ * s_;

  final lr = 4.076_741_662_1 * l - 3.307_711_591_3 * m + 0.230_969_929_2 * s;
  final lg = -1.268_438_004_6 * l + 2.609_757_401_1 * m - 0.341_319_396_5 * s;
  final lb = -0.004_196_086_3 * l - 0.703_418_614_7 * m + 1.707_614_701_0 * s;

  return [
    _linearToSrgb(lr.clamp(0.0, 1.0)),
    _linearToSrgb(lg.clamp(0.0, 1.0)),
    _linearToSrgb(lb.clamp(0.0, 1.0)),
  ];
}

/// 在 Oklab 空间把 [head] 往 [tail] 插值 [t]。
///
/// 等价于 React 的 `color-mix(in oklch, tail (t*100)%, head)` —— 段颜色按
/// 「车头到车尾」的进度取色，中段不会像 RGB 插值那样发灰。
Color _mixOklab(Color head, Color tail, double t) {
  final from = _toOklab(head.r, head.g, head.b);
  final to = _toOklab(tail.r, tail.g, tail.b);
  final mixed = _fromOklab(
    _lerp(from[0], to[0], t),
    _lerp(from[1], to[1], t),
    _lerp(from[2], to[2], t),
  );
  return Color.from(
    alpha: _lerp(head.a, tail.a, t),
    red: mixed[0],
    green: mixed[1],
    blue: mixed[2],
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
