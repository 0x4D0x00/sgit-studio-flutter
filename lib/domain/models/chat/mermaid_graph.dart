/// Mermaid 流程图的**最小可用子集**解析 —— 纯 Dart，不 import Flutter。
///
/// ## 为什么自己写而不引包
///
/// 模型输出的图表描述里，压倒性多数是 `graph TD` / `flowchart LR` 这种
/// 「若干节点 + 带箭头的边」。引一个完整 mermaid 引擎要背上解析器 + 布局 +
/// 主题一大坨，而且 Web 端还要额外的 JS 桥。这里只认这一种子集，
/// 认不出来就老实退回等宽显示原文 —— 见 [MermaidGraph.tryParse] 返回 null 时
/// 调用方的兜底。
///
/// 支持：
/// - 首行 `graph`/`flowchart` + 方向 `TD`/`TB`/`BT`/`LR`/`RL`
/// - 节点 `A`、`A[文字]`、`A(文字)`、`A{文字}`、`A((文字))`
/// - 边 `-->` `---` `-.->` `==>` `<-->` `--` `~~~`
/// - 边标签 `A -->|是| B`
/// - 链式 `A --> B --> C`
///
/// 忽略 `subgraph` / `classDef` / `style` / `click` / `%%` 注释 —— 它们不影响
/// 拓扑，画出来仍是一张对的图，只是没有那些装饰。
library;

/// 图中的一个节点。
class MermaidNode {
  MermaidNode({required this.id, required this.label, required this.shape});

  final String id;

  /// 显示文字。没写 `[...]` 时就是 id 本身。
  final String label;

  final MermaidShape shape;
}

/// 节点外形。解析出来只影响画法（矩形 / 圆角 / 菱形）。
enum MermaidShape { rect, rounded, stadium, diamond }

/// 一条有向边。
class MermaidEdge {
  MermaidEdge({required this.from, required this.to, this.label});

  final String from;
  final String to;

  /// `-->|是|` 里的「是」。
  final String? label;
}

/// 解析结果。
class MermaidGraph {
  MermaidGraph({
    required this.leftToRight,
    required this.reversedDirection,
    required this.nodes,
    required this.edges,
  });

  /// 主轴是水平的（`LR` / `RL`）。false 表示垂直（`TD` / `TB` / `BT`）。
  final bool leftToRight;

  /// `BT` / `RL` —— 层序反向，入口落在视觉的下端 / 右端。
  final bool reversedDirection;

  final List<MermaidNode> nodes;
  final List<MermaidEdge> edges;

  /// 支持的箭头，**长的排前面** —— 匹配时先试 `<-->` 再试 `-->`，
  /// 否则 `<-->` 会被切成 `<` + `-->`。
  static const List<String> _arrows = [
    '<-->',
    '<==>',
    '-.->',
    '-->',
    '==>',
    '---',
    '~~~',
    '--',
    '==',
  ];

  /// 会干扰解析的指令行前缀。
  static const List<String> _ignorePrefixes = [
    'subgraph',
    'end',
    'classdef',
    'class ',
    'style',
    'linkstyle',
    'click',
    'direction',
    '%%',
  ];

  static final RegExp _directionRe =
      RegExp(r'^(?:graph|flowchart)\s+(TD|TB|BT|LR|RL)\b', caseSensitive: false);

  /// 认不出来就返回 null，调用方据此退回原文显示。
  static MermaidGraph? tryParse(String source) {
    final lines = source.split('\n');
    // 首个非空行必须是 graph/flowchart 声明，否则不是我们能画的图。
    var header = -1;
    MermaidDirection? dir;
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].trim();
      if (t.isEmpty || t.startsWith('%%')) continue;
      final m = _directionRe.firstMatch(t);
      if (m == null) return null;
      dir = MermaidDirection.parse(m.group(1)!);
      header = i;
      break;
    }
    if (header < 0 || dir == null) return null;

    final nodes = <String, MermaidNode>{};
    final edges = <MermaidEdge>[];

    for (var i = header + 1; i < lines.length; i++) {
      final raw = lines[i].trim();
      if (raw.isEmpty || raw.startsWith('%%')) continue;
      if (_ignorePrefixes.any((p) => raw.toLowerCase().startsWith(p))) continue;

      // `;` 可以分隔同一行的多条语句。
      for (final stmt in raw.split(';')) {
        final s = stmt.trim();
        if (s.isEmpty) continue;
        _parseStatement(s, nodes, edges);
      }
    }

    // 一条边都没有的图不值得画，退回原文更有信息量。
    if (edges.isEmpty) return null;

    return MermaidGraph(
      leftToRight: dir.leftToRight,
      reversedDirection: dir.reversed,
      nodes: nodes.values.toList(growable: false),
      edges: edges,
    );
  }

  /// 一条语句：`A[x] -->|label| B(y) --> C`。
  static void _parseStatement(
    String stmt,
    Map<String, MermaidNode> nodes,
    List<MermaidEdge> edges,
  ) {
    final parts = _splitOnArrows(stmt);
    if (parts.isEmpty) return;

    String? pendingLabel;
    String? prevId;

    for (final part in parts) {
      if (part.isArrow) continue;

      // 段可能是 `|label| B` —— 标签属于**前面那条边**。
      var body = part.text.trim();
      String? edgeLabel;
      if (body.startsWith('|')) {
        final close = body.indexOf('|', 1);
        if (close > 0) {
          edgeLabel = body.substring(1, close).trim();
          body = body.substring(close + 1).trim();
        }
      }
      if (body.isEmpty) continue;

      final ref = _parseNodeRef(body);
      if (ref == null) continue;

      // 后写的 `A[新文字]` 覆盖先写的裸 `A`。
      final existing = nodes[ref.id];
      if (existing == null) {
        nodes[ref.id] = MermaidNode(
          id: ref.id,
          label: ref.label,
          shape: ref.shape,
        );
      } else if (ref.explicitLabel) {
        nodes[ref.id] = MermaidNode(
          id: ref.id,
          label: ref.label,
          shape: ref.shape,
        );
      }

      if (prevId != null) {
        edges.add(MermaidEdge(
          from: prevId,
          to: ref.id,
          label: edgeLabel ?? pendingLabel,
        ));
      }
      prevId = ref.id;
      pendingLabel = null;
    }
  }

  /// 按箭头切段。箭头之间的文字是节点引用。
  static List<_Seg> _splitOnArrows(String s) {
    final out = <_Seg>[];
    var rest = s;
    while (rest.isNotEmpty) {
      var bestIdx = -1;
      String? bestArrow;
      for (final a in _arrows) {
        final idx = rest.indexOf(a);
        if (idx < 0) continue;
        // 取**最靠左**的箭头；同位置时取更长的（列表已按长度降序）。
        if (bestIdx < 0 || idx < bestIdx) {
          bestIdx = idx;
          bestArrow = a;
        }
      }
      if (bestIdx < 0 || bestArrow == null) {
        out.add(_Seg(text: rest, isArrow: false));
        break;
      }
      if (bestIdx > 0) {
        out.add(_Seg(text: rest.substring(0, bestIdx), isArrow: false));
      }
      out.add(_Seg(text: bestArrow, isArrow: true));
      rest = rest.substring(bestIdx + bestArrow.length);
    }
    return out.where((s) => s.isArrow || s.text.trim().isNotEmpty).toList();
  }

  /// `A` / `A[文字]` / `A(文字)` / `A{文字}` / `A((文字))` → 节点引用。
  static _NodeRef? _parseNodeRef(String s) {
    // id 到第一个括号或空白为止。
    var end = 0;
    while (end < s.length) {
      final c = s[end];
      if (c == '[' || c == '(' || c == '{' || c == ' ' || c == '\t') break;
      end++;
    }
    if (end == 0) return null;
    final id = s.substring(0, end);
    final tail = s.substring(end).trim();
    if (tail.isEmpty) {
      return _NodeRef(id: id, label: id, shape: MermaidShape.rect,
          explicitLabel: false);
    }

    // 取最先出现的闭合符 —— `A[x](y)` 这种畸形写法按第一个收口，不猜。
    final candidates = [
      tail.indexOf(']'),
      tail.indexOf(')'),
      tail.indexOf('}'),
    ].where((i) => i > 0).toList()
      ..sort();
    final closeIdx = candidates.isEmpty ? -1 : candidates.first;
    if (closeIdx <= 0) {
      return _NodeRef(id: id, label: id, shape: MermaidShape.rect,
          explicitLabel: false);
    }

    final open = tail[0];
    var label = tail.substring(1, closeIdx).trim();
    // `((文字))` / `([文字])` 这类双重包裹，剥掉剩下的括号。
    label = label.replaceAll(RegExp(r'^[\(\[\{]+'), '').replaceAll(
        RegExp(r'[\)\]\}]+$'), '').trim();
    if (label.isEmpty) label = id;

    final shape = switch (open) {
      '{' => MermaidShape.diamond,
      '(' => label != tail.substring(1, closeIdx).trim()
          ? MermaidShape.stadium
          : MermaidShape.rounded,
      _ => MermaidShape.rect,
    };

    return _NodeRef(id: id, label: _unquote(label), shape: shape,
        explicitLabel: true);
  }

  /// 去掉 mermaid 的引号包裹（`A["带 空格"]`）。
  static String _unquote(String s) {
    if (s.length >= 2 &&
        ((s.startsWith('"') && s.endsWith('"')) ||
            (s.startsWith("'") && s.endsWith("'")))) {
      return s.substring(1, s.length - 1);
    }
    return s;
  }

  /// 图分层 —— 每个节点在第几层。用于排版。
  ///
  /// 层号 = 从根节点（没有入边的节点）出发的**最长路径**。这样 `A→B→C` 会被
  /// 排成三层而不是挤在一起。有环时靠 [visited] 兜住，不会死循环。
  Map<String, int> layerOf() {
    final incoming = <String, int>{for (final n in nodes) n.id: 0};
    final outgoing = <String, List<String>>{for (final n in nodes) n.id: []};
    for (final e in edges) {
      incoming[e.to] = (incoming[e.to] ?? 0) + 1;
      (outgoing[e.from] ??= []).add(e.to);
    }

    final layer = <String, int>{for (final n in nodes) n.id: 0};
    // 从所有根出发做松弛。边数有限，层数不会超过节点数。
    for (var pass = 0; pass < nodes.length; pass++) {
      var changed = false;
      for (final e in edges) {
        final cand = (layer[e.from] ?? 0) + 1;
        if (cand > (layer[e.to] ?? 0) && cand < nodes.length) {
          layer[e.to] = cand;
          changed = true;
        }
      }
      if (!changed) break;
    }

    // 没有任何入边的孤立节点归到第 0 层。
    for (final n in nodes) {
      if ((incoming[n.id] ?? 0) == 0 && (layer[n.id] ?? 0) > 0) {
        layer[n.id] = 0;
      }
    }
    return layer;
  }
}

/// 方向。
class MermaidDirection {
  const MermaidDirection(this.leftToRight, this.reversed);

  final bool leftToRight;

  /// `BT` / `RL` —— 反向排布。
  final bool reversed;

  static MermaidDirection parse(String raw) => switch (raw.toUpperCase()) {
    'LR' => const MermaidDirection(true, false),
    'RL' => const MermaidDirection(true, true),
    'BT' => const MermaidDirection(false, true),
    _ => const MermaidDirection(false, false), // TD / TB
  };
}

class _Seg {
  _Seg({required this.text, required this.isArrow});
  final String text;
  final bool isArrow;
}

class _NodeRef {
  _NodeRef({
    required this.id,
    required this.label,
    required this.shape,
    required this.explicitLabel,
  });
  final String id;
  final String label;
  final MermaidShape shape;
  final bool explicitLabel;
}
