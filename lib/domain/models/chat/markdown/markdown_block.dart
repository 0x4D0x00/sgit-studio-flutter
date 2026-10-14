/// 块级 Markdown 解析 —— **纯 Dart，不 import Flutter**。
///
/// 产出的 AST 每块带 [MarkdownBlock.sourceStart] / [sourceEnd]（**规范化后文本的
/// 字符偏移**）。这两个偏移是流式增量的全部依据：追加一个 delta 时，只从
/// **最后一块的 `sourceStart`** 起重解析，前面所有块原样复用 —— 见
/// `ui/components/chat/markdown/markdown_view.dart` 的缓存。
///
/// 为什么能这么偷懒，以及为什么它是对的：追加文本只会让**最后一块**长大
/// （段落续行、表格续行、未闭合围栏继续吃字符），不可能回头改动前面已经封口的块。
/// 唯一的伪例外是 setext 标题（`文字` + 后续 `===` 把段落变成标题），但那时
/// 那个段落正是最后一块，本来就在重解析范围内。
///
/// 块内容**存原始字符串**，不在这里做行内词法 —— 行内解析交给
/// `markdown_inline.dart`，由 UI 层按需调用。
library;

/// 块级节点。`sealed` 让 `switch` 在 UI 层穷尽，新增块类型时编译器会拦住。
sealed class MarkdownBlock {
  const MarkdownBlock({required this.sourceStart, required this.sourceEnd});

  /// 规范化文本中的起始偏移（含）。
  final int sourceStart;

  /// 规范化文本中的结束偏移（不含）。
  final int sourceEnd;
}

/// 段落。行内的软换行**原样保留** —— 聊天里模型手写的换行通常是有意义的
/// （并列的选项、地址、短句），按 HTML 规则折成空格反而不忠实。
final class MdParagraph extends MarkdownBlock {
  const MdParagraph({
    required this.text,
    required super.sourceStart,
    required super.sourceEnd,
  });

  final String text;
}

/// ATX 标题（`#` ~ `######`）。
final class MdHeading extends MarkdownBlock {
  const MdHeading({
    required this.level,
    required this.text,
    required super.sourceStart,
    required super.sourceEnd,
  });

  /// 1..6。
  final int level;
  final String text;
}

/// 列表项。用**扁平结构 + 缩进层级**而不是树：渲染端只需要按层级加左内边距，
/// 建树会多出一堆只有一层子节点的样板类型。
final class MdListItem {
  const MdListItem({
    required this.text,
    required this.depth,
    required this.number,
  });

  final String text;

  /// 缩进层级，0 起。上限见 [MarkdownParser.maxListDepth]。
  final int depth;

  /// 有序列表的序号（从原文取，尊重 `3.` 这种起始值）；无序列表恒为 0。
  final int number;
}

/// 列表。连续的 `-`/`*`/`+` 或 `1.` 行归为一个块。
final class MdList extends MarkdownBlock {
  const MdList({
    required this.ordered,
    required this.items,
    required super.sourceStart,
    required super.sourceEnd,
  });

  final bool ordered;
  final List<MdListItem> items;
}

/// 引用块。子块递归解析（引用里可以有段落、列表、代码块）。
final class MdQuote extends MarkdownBlock {
  const MdQuote({
    required this.children,
    required super.sourceStart,
    required super.sourceEnd,
  });

  final List<MarkdownBlock> children;
}

/// 围栏代码块。
final class MdCodeFence extends MarkdownBlock {
  const MdCodeFence({
    required this.language,
    required this.code,
    required super.sourceStart,
    required super.sourceEnd,
  });

  /// 围栏后的 info string（```dart 里的 `dart`）。可能为空。
  final String language;
  final String code;
}

/// 分隔线（`---` / `***` / `___`）。
final class MdRule extends MarkdownBlock {
  const MdRule({required super.sourceStart, required super.sourceEnd});
}

/// GFM 表格。
final class MdTable extends MarkdownBlock {
  const MdTable({
    required this.header,
    required this.rows,
    required super.sourceStart,
    required super.sourceEnd,
  });

  final List<String> header;
  final List<List<String>> rows;
}

/// 块级解析器。
///
/// 输入的健壮性是**第一要求**：流式输出天然是半截的 —— 未闭合的围栏、
/// 刚敲到一半的表格分隔行、只有 `##` 还没写标题的标题行。任何一条都不能抛异常，
/// 也不能退化成超线性扫描。
class MarkdownParser {
  MarkdownParser._();

  /// 引用嵌套上限。防 `>>>>>>>>…` 递归爆栈。
  static const int maxQuoteDepth = 5;

  /// 列表缩进层级上限。超过就并到最深一层 —— 缩进失控时版式不会一路右移。
  static const int maxListDepth = 3;

  /// 解析 [text]。
  ///
  /// [offsetBias] 会加到所有产出块的 [MarkdownBlock.sourceStart] / [sourceEnd] 上。
  /// 增量缓存解析"最后一块那截尾巴"时用它把偏移还原到全文坐标系 ——
  /// 这样下次追加时 [MarkdownBlock.sourceEnd] 仍能当续解析的锚点。
  ///
  /// ⚠️ 只有**顶层**块带 bias。引用/列表内部递归解析出的子块偏移是相对的，
  /// 因为它们永远不会被单独续解析 —— 缓存只在顶层切片。
  static List<MarkdownBlock> parse(String text, {int offsetBias = 0}) =>
      _parseLines(_toLines(normalize(text)), 0, offsetBias);

  /// 把 CRLF / 裸 CR 统一成 `\n`。
  ///
  /// ⚠️ 必须在取偏移**之前**做，否则 Windows 换行会让每个偏移都差一，
  /// 增量缓存按偏移切片就会切错位置（症状：流式输出里偶尔吞/重一个字）。
  /// 增量缓存也靠这个前提 —— 含 `\r` 的文本直接走全量重解析，见
  /// `markdown_view_cache.dart`。
  static String normalize(String s) =>
      s.contains('\r') ? s.replaceAll('\r\n', '\n').replaceAll('\r', '\n') : s;


  /// 切行，同时记下每行在规范化文本里的起始偏移。
  static List<_Line> _toLines(String s) {
    final out = <_Line>[];
    var start = 0;
    while (true) {
      final nl = s.indexOf('\n', start);
      if (nl < 0) {
        out.add(_Line(s.substring(start), start));
        break;
      }
      out.add(_Line(s.substring(start, nl), start));
      start = nl + 1;
    }
    return out;
  }

  static List<MarkdownBlock> _parseLines(
      List<_Line> lines, int depth, int bias) {
    final out = <MarkdownBlock>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];

      if (line.text.trim().isEmpty) {
        i++;
        continue;
      }

      // ---- 围栏代码块。⚠️ 排在标题之前：``` 里的 `# 注释` 不是标题。----
      final fence = _fenceOpen(line.text);
      if (fence != null) {
        final startLine = i;
        final body = <String>[];
        i++;
        // 未闭合（流式期常态）时一路吃到文本结束，不报错。
        while (i < lines.length && !_isFenceClose(lines[i].text, fence)) {
          body.add(lines[i].text);
          i++;
        }
        final endOffset = i < lines.length
            ? lines[i].end
            : (lines.isEmpty ? 0 : lines.last.end);
        if (i < lines.length) i++; // 跳过闭合围栏
        out.add(MdCodeFence(
          language: fence.info,
          code: body.join('\n'),
          sourceStart: lines[startLine].start + bias,
          sourceEnd: endOffset + bias,
        ));
        continue;
      }

      // ---- ATX 标题 ----
      final heading = _atxHeading(line.text);
      if (heading != null) {
        out.add(MdHeading(
          level: heading.$1,
          text: heading.$2,
          sourceStart: line.start + bias,
          sourceEnd: line.end + bias,
        ));
        i++;
        continue;
      }

      // ---- 分隔线 ----
      if (_isRule(line.text)) {
        out.add(MdRule(sourceStart: line.start + bias, sourceEnd: line.end + bias));
        i++;
        continue;
      }

      // ---- 引用块。递归前把 `>` 前缀剥掉。----
      if (_quotePrefix(line.text) != null && depth < maxQuoteDepth) {
        final startLine = i;
        final inner = <String>[];
        while (i < lines.length) {
          final p = _quotePrefix(lines[i].text);
          if (p != null) {
            inner.add(p);
            i++;
          } else if (lines[i].text.trim().isEmpty) {
            break; // 空行结束引用
          } else {
            // 惰性续行：`> 引用` 下面直接跟一行普通文字，仍算引用内。
            inner.add(lines[i].text);
            i++;
          }
        }
        out.add(MdQuote(
          children: _parseLines(_toLines(inner.join('\n')), depth + 1, 0),
          sourceStart: lines[startLine].start + bias,
          sourceEnd: lines[i - 1].end + bias,
        ));
        continue;
      }

      // ---- 列表 ----
      final marker = _listMarker(line.text);
      if (marker != null) {
        final startLine = i;
        final ordered = marker.ordered;
        final items = <MdListItem>[];
        while (i < lines.length) {
          final m = _listMarker(lines[i].text);
          if (m != null) {
            // 标记种类变了（`-` 段之后跟 `1.` 段）→ 另起一个列表块。
            if (m.ordered != ordered) break;
            items.add(MdListItem(
              text: m.text,
              depth: (m.indent ~/ 2).clamp(0, maxListDepth),
              number: m.number,
            ));
            i++;
          } else if (lines[i].text.trim().isEmpty) {
            break;
          } else if (items.isNotEmpty &&
              !_startsBlock(lines, i)) {
            // 惰性续行：并到上一项，不新起段落。
            final last = items.removeLast();
            items.add(MdListItem(
              text: '${last.text}\n${lines[i].text.trim()}',
              depth: last.depth,
              number: last.number,
            ));
            i++;
          } else {
            break;
          }
        }
        out.add(MdList(
          ordered: ordered,
          items: items,
          sourceStart: lines[startLine].start + bias,
          sourceEnd: lines[i - 1].end + bias,
        ));
        continue;
      }

      // ---- 表格。必须**同时**看到表头行和分隔行才判表格 ----
      //      （`|` 很多的普通文本在日志/正则里到处都是，不能一看竖线就当表格）。
      if (i + 1 < lines.length &&
          lines[i].text.contains('|') &&
          _isDelimiterRow(lines[i + 1].text)) {
        final startLine = i;
        final header = _splitRow(lines[i].text);
        i += 2; // 跳过表头与分隔行
        final rows = <List<String>>[];
        while (i < lines.length &&
            lines[i].text.trim().isNotEmpty &&
            lines[i].text.contains('|')) {
          rows.add(_fitToWidth(_splitRow(lines[i].text), header.length));
          i++;
        }
        out.add(MdTable(
          header: header,
          rows: rows,
          sourceStart: lines[startLine].start + bias,
          sourceEnd: lines[i - 1].end + bias,
        ));
        continue;
      }

      // ---- setext 标题（`标题` 下面跟 === 或 ---）----
      if (i + 1 < lines.length && lines[i].text.trim().isNotEmpty) {
        final u = lines[i + 1].text.trim();
        if (u.isNotEmpty && RegExp(r'^=+$').hasMatch(u)) {
          out.add(MdHeading(
            level: 1,
            text: line.text.trim(),
            sourceStart: line.start + bias,
            sourceEnd: lines[i + 1].end + bias,
          ));
          i += 2;
          continue;
        }
        if (u.length >= 2 && RegExp(r'^-+$').hasMatch(u)) {
          out.add(MdHeading(
            level: 2,
            text: line.text.trim(),
            sourceStart: line.start + bias,
            sourceEnd: lines[i + 1].end + bias,
          ));
          i += 2;
          continue;
        }
      }

      // ---- 段落：吃到空行或下一个块起点 ----
      final startLine = i;
      final buf = <String>[];
      while (i < lines.length) {
        if (lines[i].text.trim().isEmpty) break;
        if (i > startLine && _startsBlock(lines, i)) break;
        buf.add(lines[i].text.trim());
        i++;
      }
      out.add(MdParagraph(
        text: buf.join('\n'),
        sourceStart: lines[startLine].start + bias,
        sourceEnd: lines[i - 1].end + bias,
      ));
    }

    return out;
  }

  /// 当前行是否会**开启一个新块** —— 段落的终止条件。
  static bool _startsBlock(List<_Line> lines, int i) {
    final t = lines[i].text;
    if (_fenceOpen(t) != null) return true;
    if (_atxHeading(t) != null) return true;
    if (_isRule(t)) return true;
    if (_quotePrefix(t) != null) return true;
    if (_listMarker(t) != null) return true;
    if (i + 1 < lines.length &&
        t.contains('|') &&
        _isDelimiterRow(lines[i + 1].text)) {
      return true;
    }
    return false;
  }

  /// 围栏起始行 → info string；不是围栏则 null。
  ///
  /// 只认行首（允许 ≤3 空格缩进）的 ``` 或 ~~~。
  static _Fence? _fenceOpen(String raw) {
    final line = _stripIndent(raw, 3);
    if (line.length < 3) return null;
    final ch = line[0];
    if (ch != '`' && ch != '~') return null;
    var n = 0;
    while (n < line.length && line[n] == ch) {
      n++;
    }
    if (n < 3) return null;
    // info string 里不许再出现反引号（CommonMark 规定），挡住 `` `a` `` 这种行内代码行。
    final info = line.substring(n).trim();
    if (ch == '`' && info.contains('`')) return null;
    return _Fence(ch, n, info);
  }

  static bool _isFenceClose(String raw, _Fence open) {
    final line = _stripIndent(raw, 3);
    var n = 0;
    while (n < line.length && line[n] == open.char) {
      n++;
    }
    if (n < open.length) return false;
    // 闭合围栏后面只许有空白。
    return line.substring(n).trim().isEmpty;
  }

  /// `#{1,6} ` 开头的标题 → (level, text)；否则 null。
  static (int, String)? _atxHeading(String raw) {
    final line = _stripIndent(raw, 3);
    var n = 0;
    while (n < line.length && line[n] == '#') {
      n++;
    }
    if (n == 0 || n > 6) return null;
    // 必须跟空格或就到此为止 —— `#tag` 不是标题。
    if (n < line.length && line[n] != ' ' && line[n] != '\t') return null;
    // 去掉收尾的一串 `#`（`## 标题 ##`）。
    var body = line.substring(n).trim();
    body = body.replaceFirst(RegExp(r'\s*#+$'), '').trim();
    return (n, body);
  }

  /// 分隔线：只有 `-`/`*`/`_` 和空白，且同种字符 ≥3 个。
  static bool _isRule(String raw) {
    final line = _stripIndent(raw, 3).trim();
    if (line.length < 3) return false;
    final ch = line[0];
    if (ch != '-' && ch != '*' && ch != '_') return false;
    var count = 0;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == ch) {
        count++;
      } else if (c != ' ' && c != '\t') {
        return false;
      }
    }
    return count >= 3;
  }

  /// `>` 前缀 → 剥掉后的内容；不是引用行则 null。
  static String? _quotePrefix(String raw) {
    final line = _stripIndent(raw, 3);
    if (line.isEmpty || line[0] != '>') return null;
    var rest = line.substring(1);
    if (rest.startsWith(' ')) rest = rest.substring(1);
    return rest;
  }

  /// 列表标记 → 解析结果；否则 null。
  static _Marker? _listMarker(String raw) {
    var indent = 0;
    while (indent < raw.length &&
        (raw[indent] == ' ' || raw[indent] == '\t')) {
      indent++;
    }
    // 缩进 ≥4 空格按续行/代码缩进处理，不算新列表项。
    if (indent >= 4) return null;
    if (indent >= raw.length) return null;

    final c = raw[indent];
    if (c == '-' || c == '*' || c == '+') {
      if (indent + 1 < raw.length &&
          raw[indent + 1] != ' ' &&
          raw[indent + 1] != '\t') {
        return null;
      }
      final text = raw.substring(indent + 1).trim();
      if (text.isEmpty) return null;
      return _Marker(ordered: false, indent: indent, number: 0, text: text);
    }

    // 有序：`1.` / `1)`
    var d = indent;
    while (d < raw.length && _isDigit(raw.codeUnitAt(d))) {
      d++;
    }
    if (d == indent || d >= raw.length) return null;
    if (raw[d] != '.' && raw[d] != ')') return null;
    if (d + 1 < raw.length && raw[d + 1] != ' ' && raw[d + 1] != '\t') {
      return null;
    }
    final text = raw.substring(d + 1).trim();
    if (text.isEmpty) return null;
    final n = int.tryParse(raw.substring(indent, d)) ?? 1;
    return _Marker(ordered: true, indent: indent, number: n, text: text);
  }

  /// 表格分隔行：按 `|` 切开后每格都是 `:?-+:?`。
  static bool _isDelimiterRow(String raw) {
    final line = raw.trim();
    if (line.isEmpty || !line.contains('-')) return false;
    final cells = _splitRow(line);
    if (cells.isEmpty) return false;
    for (final c in cells) {
      if (!RegExp(r'^:?-+:?$').hasMatch(c.trim())) return false;
    }
    return true;
  }

  /// 把一行数据补齐/裁到 [width] 格。
  ///
  /// ⚠️ **不是可选的健壮性，是必需的**：Flutter 的 `Table` 在所有行的单元格
  /// 数不一致时直接 assert 崩掉（"Table contains irregular row lengths"）。
  /// 而流式输出里**任何一行的格子数都会阶段性对不上** —— 刚敲到 `| ` 的行
  /// 只有 1 格、表头 3 格而正文只写了 2 格、闭口的 `|` 还没打出来。
  /// 所以这里统一补齐（缺的填空串）或裁掉（多的丢掉），保证发出的 AST
  /// 永远是矩形。
  static List<String> _fitToWidth(List<String> cells, int width) {
    if (cells.length == width) return cells;
    if (cells.length > width) return cells.sublist(0, width);
    return [...cells, ...List.filled(width - cells.length, '')];
  }

  /// 按 `|` 切格，去掉首尾空管道与每格空白。
  static List<String> _splitRow(String raw) {
    var line = raw.trim();
    if (line.startsWith('|')) line = line.substring(1);
    if (line.endsWith('|')) line = line.substring(0, line.length - 1);
    return line.split('|').map((c) => c.trim()).toList();
  }

  /// 剥掉最多 [max] 个前导空格。
  static String _stripIndent(String s, int max) {
    var n = 0;
    while (n < max && n < s.length && s[n] == ' ') {
      n++;
    }
    return s.substring(n);
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
}

/// 一行文本 + 它在规范化文本里的起始偏移。
class _Line {
  _Line(this.text, this.start);
  final String text;
  final int start;
  int get end => start + text.length;
}

class _Fence {
  _Fence(this.char, this.length, this.info);
  final String char;
  final int length;
  final String info;
}

class _Marker {
  _Marker({
    required this.ordered,
    required this.indent,
    required this.number,
    required this.text,
  });
  final bool ordered;
  final int indent;
  final int number;
  final String text;
}
