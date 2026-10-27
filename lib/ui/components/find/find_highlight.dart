import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:sgit_studio_flutter/domain/models/find/find_matcher.dart';

/// 页内查找的高亮色。跟主题色走：普通匹配是浅底，当前匹配是深底。
@immutable
class FindColors {
  const FindColors({required this.match, required this.current});

  factory FindColors.of(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return FindColors(
      match: primary.withValues(alpha: 0.28),
      current: primary.withValues(alpha: 0.62),
    );
  }

  final Color match;
  final Color current;
}

/// 向子树广播「现在在查什么」。纯展示层的组件（左栏行、气泡）读它决定要不要高亮，
/// 不必依赖状态库。
///
/// [navCurrent] / [transcriptCurrent] 是当前匹配在**各自区域内**的序号，
/// 当前匹配不在该区域就是 -1。
class FindScope extends InheritedWidget {
  const FindScope({
    super.key,
    required this.query,
    required this.navCurrent,
    required this.transcriptCurrent,
    required super.child,
  });

  final String query;
  final int navCurrent;
  final int transcriptCurrent;

  bool get active => query.isNotEmpty;

  static FindScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FindScope>();

  @override
  bool updateShouldNotify(FindScope old) =>
      query != old.query ||
      navCurrent != old.navCurrent ||
      transcriptCurrent != old.transcriptCurrent;
}

/// 一个区域内按顺序给匹配编号并产出带高亮的 [TextSpan]。
///
/// 编号从 [start] 起，每画出一个匹配 +1。**调用顺序必须与计数的遍历顺序一致**
/// （见 `MarkdownFind`），所以一个实例只在一次 `build` 里同步用完。
class FindHighlight {
  FindHighlight({
    required this.query,
    required int start,
    required this.current,
    required this.colors,
  }) : _next = start;

  final String query;

  /// 当前匹配在本区域内的序号；不在本区域为 -1。
  final int current;
  final FindColors colors;
  int _next;

  int get next => _next;

  /// 跳过 [n] 个匹配（子树自己另起 [FindHighlight] 去画时，父级用它对齐编号）。
  void skip(int n) => _next += n;

  /// 从当前编号起另起一个，给嵌套子树用。
  FindHighlight branch() =>
      FindHighlight(query: query, start: _next, current: current, colors: colors);

  /// [text] 带高亮的 span。没有匹配时与普通 `TextSpan` 完全一样。
  ///
  /// [recognizer] 要挂到每一段上 —— 它不会被子 span 继承。
  TextSpan span(
    String text,
    TextStyle? style, {
    GestureRecognizer? recognizer,
  }) {
    final ranges = FindMatcher.ranges(text, query);
    if (ranges.isEmpty) {
      return TextSpan(text: text, style: style, recognizer: recognizer);
    }
    final children = <InlineSpan>[];
    var last = 0;
    for (final (s, e) in ranges) {
      if (s > last) {
        children.add(
          TextSpan(text: text.substring(last, s), recognizer: recognizer),
        );
      }
      final isCurrent = _next == current;
      _next++;
      children.add(
        TextSpan(
          text: text.substring(s, e),
          style: TextStyle(
            backgroundColor: isCurrent ? colors.current : colors.match,
          ),
          recognizer: recognizer,
        ),
      );
      last = e;
    }
    if (last < text.length) {
      children.add(
        TextSpan(text: text.substring(last), recognizer: recognizer),
      );
    }
    return TextSpan(style: style, children: children);
  }
}

/// 在 [root] 的渲染子树里找「当前匹配」那一段文字，把它所在的可滚动视口滚到合适位置。
/// 找不到返回 false。
///
/// 认「当前匹配」靠它的底色就是 [FindColors.current]（见 [FindHighlight.span]）。
bool scrollToCurrentFindMatch(
  RenderObject root,
  ScrollController scroll,
  FindColors colors, {
  double alignment = 0.35,
}) {
  RenderParagraph? para;
  int? start;
  int len = 0;

  void visit(RenderObject o) {
    if (para != null) return;
    if (o is RenderParagraph) {
      var offset = 0;
      o.text.visitChildren((span) {
        if (span is TextSpan && span.text != null) {
          if (span.style?.backgroundColor == colors.current) {
            para = o;
            start = offset;
            len = span.text!.length;
            return false;
          }
          offset += span.text!.length;
        } else if (span is PlaceholderSpan) {
          offset += 1;
        }
        return true;
      });
      return;
    }
    o.visitChildren(visit);
  }

  visit(root);
  final p = para;
  if (p == null || start == null || !p.attached || !scroll.hasClients) {
    return false;
  }

  final boxes = p.getBoxesForSelection(
    TextSelection(baseOffset: start!, extentOffset: start! + len),
  );
  if (boxes.isEmpty) return false;
  // ⚠️ 要的是**纵向**那个视口（会话列表）。匹配落在表格里时，离文字最近的
  // 视口是表格外面那层横向滚动区，拿它的偏移去滚纵向列表必然跑偏。
  RenderViewportBase? viewport;
  for (RenderObject? o = p; o != null; o = o.parent) {
    if (o is RenderViewportBase && o.axis == Axis.vertical) {
      viewport = o;
      break;
    }
  }
  if (viewport == null) return false;

  final pos = scroll.position;
  final rect = boxes.first.toRect();

  // 匹配在视口里的纵向位置。两端各留一点余量：顶部有浮动的查找框。
  const margin = 24.0;
  final top = p.localToGlobal(rect.topLeft, ancestor: viewport).dy;
  final bottom = p.localToGlobal(rect.bottomLeft, ancestor: viewport).dy;
  final height = viewport.size.height;
  if (top >= margin && bottom <= height - margin) {
    // 已经在视野里：把上一次还没跑完的滚动动画停在当前位置，
    // 否则它会继续把页面带去旧目标（边打字边查时最常见）。
    if (pos.isScrollingNotifier.value) scroll.jumpTo(pos.pixels);
    return true;
  }

  final target = viewport
      .getOffsetToReveal(p, alignment, rect: rect)
      .offset
      .clamp(pos.minScrollExtent, pos.maxScrollExtent);
  scroll.animateTo(
    target,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOutCubic,
  );
  return true;
}
