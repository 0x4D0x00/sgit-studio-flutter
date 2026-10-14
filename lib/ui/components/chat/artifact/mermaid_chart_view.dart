import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/chat/mermaid_graph.dart';

/// 把 mermaid 流程图画成真的图。
///
/// 布局算法是**分层 + 层内均匀分布**（不是力导向）：流程图是 DAG，层的概念
/// 本来就有语义（第 0 层是入口），力导向会把入口拽到中间去。节点高度统一、
/// 宽度按文字自适应，所以层内排布只是一次简单的累加。
///
/// 认不出图 → [tryBuild] 返回 null，调用方退回原文。**不画一张错的图** ——
/// 拓扑错了比不画更坏，用户会照着错图去理解系统。
class MermaidChartView {
  MermaidChartView._();

  /// 尝试把 [source] 建成一张图。认不出返回 null。
  static Widget? tryBuild(String source) {
    final graph = MermaidGraph.tryParse(source);
    if (graph == null) return null;
    return _MermaidChart(graph: graph);
  }
}

/// 单个节点的排版尺寸。
const double _nodeHeight = 36;
const double _nodeMinWidth = 72;
const double _nodeMaxWidth = 200;
const double _nodeHPad = 14;
const double _layerGap = 56;
const double _nodeGap = 20;

class _MermaidChart extends StatelessWidget {
  const _MermaidChart({required this.graph});

  final MermaidGraph graph;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final layer = graph.layerOf();
    final horizontal = graph.leftToRight;

    // 按层分组。层号可能不连续（图里有孤立节点），先压平。
    final rawLayers = <int, List<MermaidNode>>{};
    for (final n in graph.nodes) {
      (rawLayers[layer[n.id] ?? 0] ??= []).add(n);
    }
    final layerKeys = rawLayers.keys.toList()..sort();

    // 每个节点的文字宽度 —— 用 TextPainter 量，不能猜字符数（中英文差一倍）。
    final sizes = <String, Size>{};
    for (final n in graph.nodes) {
      sizes[n.id] = _measure(n.label, context);
    }

    // 层内主轴方向的尺寸 = 该层节点里最宽的那个。
    final layerMainExtent = <int, double>{};
    for (final key in layerKeys) {
      var maxW = 0.0;
      for (final n in rawLayers[key]!) {
        final w = sizes[n.id]!.width;
        if (w > maxW) maxW = w;
      }
      layerMainExtent[key] = maxW;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final paint = _layout(
          layerKeys: layerKeys,
          rawLayers: rawLayers,
          sizes: sizes,
          layerMainExtent: layerMainExtent,
          horizontal: horizontal,
        );

        // 图可能比面板宽/高 —— 给双向滚动，不缩放。
        // 缩放在节点多时会小到看不清字，滚动至少文字是清楚的。
        return Scrollbar(
          thumbVisibility: false,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: paint.size.width,
                height: paint.size.height,
                child: CustomPaint(
                  painter: _MermaidPainter(
                    graph: graph,
                    positions: paint.positions,
                    sizes: sizes,
                    skin: skin,
                    textDirection: Directionality.of(context),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 量一段文字在节点里占多宽。
  Size _measure(String label, BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(fontSize: 12),
      ),
      textDirection: Directionality.of(context),
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: _nodeMaxWidth - _nodeHPad * 2);

    final w = (painter.width + _nodeHPad * 2).clamp(_nodeMinWidth, _nodeMaxWidth);
    return Size(w, _nodeHeight);
  }

  /// 算每个节点的左上角坐标与整图尺寸。
  _LayoutResult _layout({
    required List<int> layerKeys,
    required Map<int, List<MermaidNode>> rawLayers,
    required Map<String, Size> sizes,
    required Map<int, double> layerMainExtent,
    required bool horizontal,
  }) {
    final keys = graph.reversedDirection
        ? layerKeys.reversed.toList()
        : layerKeys;

    // 主轴（分层方向）上每个节点的位置。
    final mainPos = <int, double>{};
    var cursor = 0.0;
    for (final key in keys) {
      mainPos[key] = cursor;
      cursor += layerMainExtent[key]! + _layerGap;
    }

    final positions = <String, Offset>{};
    var crossMax = 0.0;

    for (final key in keys) {
      final nodes = rawLayers[key]!;
      // 层内交叉轴总长 = 各节点尺寸 + 间隙。
      var total = 0.0;
      for (final n in nodes) {
        total += horizontal ? sizes[n.id]!.height : sizes[n.id]!.width;
      }
      total += _nodeGap * (nodes.length - 1).clamp(0, nodes.length);

      var cross = 0.0;
      for (final n in nodes) {
        final size = sizes[n.id]!;
        if (horizontal) {
          // 主轴 = x，交叉轴 = y
          positions[n.id] = Offset(mainPos[key]!, cross);
          cross += size.height + _nodeGap;
        } else {
          // 主轴 = y，交叉轴 = x。层内节点要按层宽居中。
          final offset = (layerMainExtent[key]! - size.width) / 2;
          positions[n.id] = Offset(cross + offset, mainPos[key]!);
          cross += size.width + _nodeGap;
        }
      }
      final extent = horizontal ? total : cross;
      if (extent > crossMax) crossMax = extent;
    }

    final mainTotal = cursor - _layerGap;
    final size = horizontal
        ? Size(mainTotal.clamp(0, double.infinity), crossMax)
        : Size(crossMax, mainTotal.clamp(0, double.infinity));

    return _LayoutResult(positions: positions, size: size);
  }
}

class _LayoutResult {
  _LayoutResult({required this.positions, required this.size});
  final Map<String, Offset> positions;
  final Size size;
}

class _MermaidPainter extends CustomPainter {
  _MermaidPainter({
    required this.graph,
    required this.positions,
    required this.sizes,
    required this.skin,
    required this.textDirection,
  });

  final MermaidGraph graph;
  final Map<String, Offset> positions;
  final Map<String, Size> sizes;
  final AppSkin skin;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    _paintEdges(canvas);
    _paintNodes(canvas);
  }

  void _paintEdges(Canvas canvas) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = skin.borderSecondary;

    for (final e in graph.edges) {
      final from = positions[e.from];
      final to = positions[e.to];
      if (from == null || to == null) continue;

      final fromSize = sizes[e.from]!;
      final toSize = sizes[e.to]!;

      // 从边框中点连到边框中点 —— 连到中心会让箭头钻进节点里。
      final a = from + Offset(fromSize.width / 2, fromSize.height / 2);
      final b = to + Offset(toSize.width / 2, toSize.height / 2);

      final (p1, p2) = _edgeEndpoints(a, fromSize, b, toSize);
      canvas.drawLine(p1, p2, stroke);
      _paintArrowHead(canvas, p1, p2);

      if (e.label != null && e.label!.isNotEmpty) {
        _paintEdgeLabel(canvas, p1, p2, e.label!);
      }
    }
  }

  /// 求两节点边框上的连接点。水平/垂直各取一条直边，斜向时用矩形求交。
  (Offset, Offset) _edgeEndpoints(
    Offset a,
    Size as,
    Offset b,
    Size bs,
  ) {
    final p1 = _rectIntersect(a, as, b);
    final p2 = _rectIntersect(b, bs, a);
    return (p1, p2);
  }

  /// 从矩形中心 [origin] 朝 [target] 方向，射线与矩形边的交点。
  Offset _rectIntersect(Offset center, Size size, Offset target) {
    final dx = target.dx - center.dx;
    final dy = target.dy - center.dy;
    if (dx == 0 && dy == 0) return center;

    final hw = size.width / 2;
    final hh = size.height / 2;

    // 缩放因子：让方向向量刚好碰到边界。
    final scaleX = dx == 0 ? double.infinity : hw / dx.abs();
    final scaleY = dy == 0 ? double.infinity : hh / dy.abs();
    final s = scaleX < scaleY ? scaleX : scaleY;

    return Offset(center.dx + dx * s, center.dy + dy * s);
  }

  void _paintArrowHead(Canvas canvas, Offset from, Offset to) {
    final angle = (to - from).direction;
    const len = 8.0;
    const spread = 0.42;

    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - len * math.cos(angle - spread),
        to.dy - len * math.sin(angle - spread),
      )
      ..lineTo(
        to.dx - len * math.cos(angle + spread),
        to.dy - len * math.sin(angle + spread),
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = skin.textTertiary,
    );
  }

  void _paintEdgeLabel(Canvas canvas, Offset from, Offset to, String label) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontSize: 11, color: skin.textSecondary),
      ),
      textDirection: textDirection,
    )..layout();

    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    final rect = Rect.fromCenter(
      center: mid,
      width: painter.width + 6,
      height: painter.height + 2,
    );

    // 给标签垫一层背景，否则边线会从字里穿过去。
    canvas.drawRect(
      rect,
      Paint()..color = skin.containerBg,
    );
    painter.paint(
      canvas,
      Offset(mid.dx - painter.width / 2, mid.dy - painter.height / 2),
    );
  }

  void _paintNodes(Canvas canvas) {
    for (final n in graph.nodes) {
      final pos = positions[n.id];
      if (pos == null) continue;
      final size = sizes[n.id]!;
      final rect = pos & size;

      final shape = _nodePath(n.shape, rect);

      canvas.drawPath(shape, Paint()..color = skin.containerBgSecondary);
      canvas.drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = skin.border,
      );

      final painter = TextPainter(
        text: TextSpan(
          text: n.label,
          style: TextStyle(fontSize: 12, color: skin.text),
        ),
        textDirection: textDirection,
        maxLines: 2,
        ellipsis: '…',
        textAlign: TextAlign.center,
      )..layout(maxWidth: size.width - _nodeHPad * 2);

      painter.paint(
        canvas,
        Offset(
          rect.left + (size.width - painter.width) / 2,
          rect.top + (size.height - painter.height) / 2,
        ),
      );
    }
  }

  Path _nodePath(MermaidShape shape, Rect r) {
    switch (shape) {
      case MermaidShape.rect:
        return Path()..addRect(r);
      case MermaidShape.rounded:
        return Path()
          ..addRRect(
            RRect.fromRectAndRadius(r, const Radius.circular(AppRadius.sm)),
          );
      case MermaidShape.stadium:
        return Path()
          ..addRRect(
            RRect.fromRectAndRadius(r, Radius.circular(r.height / 2)),
          );
      case MermaidShape.diamond:
        return Path()
          ..moveTo(r.center.dx, r.top)
          ..lineTo(r.right, r.center.dy)
          ..lineTo(r.center.dx, r.bottom)
          ..lineTo(r.left, r.center.dy)
          ..close();
    }
  }

  @override
  bool shouldRepaint(covariant _MermaidPainter old) =>
      old.graph != graph || old.skin != skin || old.positions != positions;
}
