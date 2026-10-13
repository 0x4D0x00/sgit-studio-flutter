/// 行内 Markdown 的词法结果 —— **纯 Dart，不含任何 Flutter 类型**。
///
/// 为什么落 `domain/` 而不是 `ui/`：解析要能脱离 widget 单测（照
/// `CodeArtifact.extractFromMarkdown` 的先例），而 `ui/` 本来就可以 import
/// `domain/`（见 ARCHITECTURE.md 的依赖方向表）。
///
/// 这里**刻意不产出 `TextSpan`** —— 那是 painting 类型，归 `design/`/`ui/` 管。
/// 映射那一步在 `ui/components/chat/markdown/markdown_spans.dart`。
library;

enum MdInlineKind {
  text,
  code,
  bold,
  italic,
  boldItalic,
  strikethrough,
  link,
}

/// 一个行内节点。
///
/// 复合节点（粗/斜/粗斜/删除线）把内容放在 [children] 里而不是压平成兄弟节点 ——
/// 这样 `**粗体里有 ``代码``**` 能嵌套，渲染时按父样式逐层叠加。
class MarkdownInline {
  const MarkdownInline.text(this.text)
      : kind = MdInlineKind.text,
        href = null,
        children = null;

  const MarkdownInline.code(this.text)
      : kind = MdInlineKind.code,
        href = null,
        children = null;

  /// [href] 是链接目标；[text] 是**显示文本**（方括号里那段）。
  const MarkdownInline.link(this.text, String this.href)
      : kind = MdInlineKind.link,
        children = null;

  const MarkdownInline.emphasis(this.kind, this.children)
      : text = '',
        href = null;

  final MdInlineKind kind;

  /// `text` / `code` 节点是这里；`link` 节点是显示文本。
  final String text;

  /// 仅 `link` 有值。
  final String? href;

  /// 仅复合节点有值。
  final List<MarkdownInline>? children;
}

/// 行内词法分析器。
///
/// ## 为什么是手写单遍扫描而不是一堆正则
///
/// 可回溯的正则（`\*\*(.+?)\*\*` 这类）在未闭合定界符密集的输入上会退化成
/// O(n²) —— 而**流式输出天然全是未闭合的半截文本**（`**文件编码` 在闭合前
/// 要逐字渲染几十次）。所以这里全部用 `indexOf` 前向扫描，并且：
///
/// **某种定界符一旦在当前位置之后彻底找不到，就把该种置为 dead，后面同种
/// 定界符一律直接当字面量。** 少了这一步，`*a *b *c …`（80 个孤立星号）
/// 会让每个 `*` 都扫到串尾 —— 那正是要避免的 O(n²)。
///
/// 这个短路是**逻辑等价**的，不是近似：某个位置之后不存在 `**`，那么再往后的
/// 任何位置同样不存在。
class MarkdownInlineParser {
  MarkdownInlineParser._();

  /// 强调嵌套的深度上限。嵌套 markdown 超过三层没有实际用例，
  /// 超过就按字面量输出 —— 顺便给递归兜个底。
  static const int _maxDepth = 3;

  static List<MarkdownInline> parse(String source) => _parse(source, 0);

  static List<MarkdownInline> _parse(String s, int depth) {
    final out = <MarkdownInline>[];
    final buf = StringBuffer();

    // 「这种定界符后面已经彻底没有了」的墓碑位。见类文档。
    var backtickDead = false;
    var boldStarDead = false;
    var italicStarDead = false;
    var boldUnderscoreDead = false;
    var italicUnderscoreDead = false;
    var strikeDead = false;
    var linkDead = false;

    void flush() {
      if (buf.isNotEmpty) {
        out.add(MarkdownInline.text(buf.toString()));
        buf.clear();
      }
    }

    var i = 0;
    while (i < s.length) {
      final c = s[i];

      // ---- 反斜杠转义。必须放在所有定界符之前，否则 `\*` 会被当成强调。----
      if (c == r'\' && i + 1 < s.length) {
        buf.write(s[i + 1]);
        i += 2;
        continue;
      }

      // ---- 行内代码。优先于强调：`` `a**b` `` 里的 `**` 不该被当成强调。----
      if (c == '`' && !backtickDead) {
        final end = s.indexOf('`', i + 1);
        if (end < 0) {
          backtickDead = true;
          buf.write(c);
          i++;
          continue;
        }
        final code = s.substring(i + 1, end);
        if (code.isEmpty) {
          buf.write(c);
          i++;
          continue;
        }
        flush();
        out.add(MarkdownInline.code(code));
        i = end + 1;
        continue;
      }

      // ---- 删除线 ~~x~~（GFM）。----
      if (c == '~' && !strikeDead && i + 1 < s.length && s[i + 1] == '~') {
        if (depth >= _maxDepth) {
          buf.write('~~');
          i += 2;
          continue;
        }
        final end = s.indexOf('~~', i + 2);
        if (end < 0) {
          strikeDead = true;
          buf.write(c);
          i++;
          continue;
        }
        final inner = s.substring(i + 2, end);
        if (inner.isEmpty || inner.contains('\n')) {
          buf.write(c);
          i++;
          continue;
        }
        flush();
        out.add(MarkdownInline.emphasis(
            MdInlineKind.strikethrough, _parse(inner, depth + 1)));
        i = end + 2;
        continue;
      }

      // ---- 链接 [显示文本](目标)。----
      //
      // ⚠️ 先找 `](` 这个**整体**而不是先找 `]`：`[` 密集但完全没有链接的文本
      // （比如被方括号包围的日志）若先找 `]`，每个 `[` 都会匹配到同一个 `]`
      // 再发现后面不是 `(` —— 又是一个 O(n²)。找 `](` 的话找不到就一次置 dead。
      if (c == '[' && !linkDead) {
        final open = s.indexOf('](', i + 1);
        if (open < 0) {
          linkDead = true;
          buf.write(c);
          i++;
          continue;
        }
        final close = s.indexOf(')', open + 2);
        if (close < 0) {
          linkDead = true;
          buf.write(c);
          i++;
          continue;
        }
        final label = s.substring(i + 1, open);
        final href = s.substring(open + 2, close).trim();
        if (label.isEmpty || href.isEmpty) {
          buf.write(c);
          i++;
          continue;
        }
        flush();
        out.add(MarkdownInline.link(label, href));
        i = close + 1;
        continue;
      }

      // ---- 粗斜体 ***x***。必须排在 ** 之前，否则 ***a*** 会被吃成
      //      bold("*a")。找不到配对的 *** 就落到 ** 分支兜底。----
      if (c == '*' &&
          !boldStarDead &&
          depth < _maxDepth &&
          i + 2 < s.length &&
          s[i + 1] == '*' &&
          s[i + 2] == '*') {
        final end = s.indexOf('***', i + 3);
        if (end >= 0) {
          final inner = s.substring(i + 3, end);
          if (inner.isNotEmpty && !inner.contains('\n')) {
            flush();
            out.add(MarkdownInline.emphasis(
                MdInlineKind.boldItalic, _parse(inner, depth + 1)));
            i = end + 3;
            continue;
          }
        }
        // 没有配对 → 交给下面的 ** 分支。
      }

      // ---- 粗体 **x** ----
      if (c == '*' && !boldStarDead && i + 1 < s.length && s[i + 1] == '*') {
        final end = s.indexOf('**', i + 2);
        if (end < 0) {
          boldStarDead = true;
          buf.write(c);
          i++;
          continue;
        }
        final inner = s.substring(i + 2, end);
        if (inner.isEmpty || inner.contains('\n')) {
          buf.write(c);
          i++;
          continue;
        }
        if (depth >= _maxDepth) {
          buf.write('**');
          i += 2;
          continue;
        }
        flush();
        out.add(MarkdownInline.emphasis(
            MdInlineKind.bold, _parse(inner, depth + 1)));
        i = end + 2;
        continue;
      }

      // ---- 粗体 __x__ ----
      if (c == '_' &&
          !boldUnderscoreDead &&
          i + 1 < s.length &&
          s[i + 1] == '_' &&
          _isBoundaryBefore(s, i)) {
        final end = s.indexOf('__', i + 2);
        if (end < 0 || !_isBoundaryAfter(s, end + 2)) {
          if (end < 0) boldUnderscoreDead = true;
          buf.write(c);
          i++;
          continue;
        }
        final inner = s.substring(i + 2, end);
        if (inner.isEmpty || inner.contains('\n') || depth >= _maxDepth) {
          buf.write(c);
          i++;
          continue;
        }
        flush();
        out.add(MarkdownInline.emphasis(
            MdInlineKind.bold, _parse(inner, depth + 1)));
        i = end + 2;
        continue;
      }

      // ---- 斜体 *x* ----
      if (c == '*' && !italicStarDead) {
        // `**` 已被上面的分支处理过，能走到这里说明是单个星号。
        final end = s.indexOf('*', i + 1);
        if (end < 0) {
          italicStarDead = true;
          buf.write(c);
          i++;
          continue;
        }
        final inner = s.substring(i + 1, end);
        // 空内容 / 含换行 / 是空白 —— 都当字面量，避免 `a * b * c` 被吃掉。
        if (inner.trim().isEmpty || inner.contains('\n') || depth >= _maxDepth) {
          buf.write(c);
          i++;
          continue;
        }
        flush();
        out.add(MarkdownInline.emphasis(
            MdInlineKind.italic, _parse(inner, depth + 1)));
        i = end + 1;
        continue;
      }

      // ---- 斜体 _x_ ----
      //
      // 额外要求两侧都是词边界：否则 `snake_case_name` 会被吃成
      // `snake_case_nam` 加斜体 —— 代码标识符在技术回答里太常见了。
      if (c == '_' && !italicUnderscoreDead && _isBoundaryBefore(s, i)) {
        final end = s.indexOf('_', i + 1);
        if (end < 0 || !_isBoundaryAfter(s, end + 1)) {
          if (end < 0) italicUnderscoreDead = true;
          buf.write(c);
          i++;
          continue;
        }
        final inner = s.substring(i + 1, end);
        if (inner.trim().isEmpty || inner.contains('\n') || depth >= _maxDepth) {
          buf.write(c);
          i++;
          continue;
        }
        flush();
        out.add(MarkdownInline.emphasis(
            MdInlineKind.italic, _parse(inner, depth + 1)));
        i = end + 1;
        continue;
      }

      buf.write(c);
      i++;
    }

    flush();
    return out;
  }

  /// 定界符**之前**是行首或非词字符 —— `_` 版强调的左侧边界条件。
  static bool _isBoundaryBefore(String s, int i) {
    if (i == 0) return true;
    final p = s.codeUnitAt(i - 1);
    return !_isWordCode(p);
  }

  /// 定界符**之后**是行尾或非词字符。`anchor_name.value` 里的下划线靠这条挡住。
  static bool _isBoundaryAfter(String s, int i) {
    if (i >= s.length) return true;
    return !_isWordCode(s.codeUnitAt(i));
  }

  static bool _isWordCode(int c) =>
      (c >= 0x30 && c <= 0x39) || // 0-9
      (c >= 0x41 && c <= 0x5A) || // A-Z
      (c >= 0x61 && c <= 0x7A) || // a-z
      c == 0x5F; // _
}
