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

  /// `![说明](地址)`。agent 在最终回复里附「完成后的样子」就用它
  /// （截图落盘后给出本地绝对路径，见 sgit-browser / sgit-computer 的 `screenshot`）。
  image,
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

  /// [text] 是替代文字（方括号里那段，可以为空）；[href] 是图片地址：
  /// 本地绝对路径、`file://`、`data:` 或 `http(s)://`。
  const MarkdownInline.image(this.text, String this.href)
      : kind = MdInlineKind.image,
        children = null;

  const MarkdownInline.emphasis(this.kind, this.children)
      : text = '',
        href = null;

  final MdInlineKind kind;

  /// `text` / `code` 节点是这里；`link` 节点是显示文本；`image` 是替代文字。
  final String text;

  /// 仅 `link` / `image` 有值。
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
///
/// ## HTML 标签
///
/// 模型经常把 HTML 混进 markdown —— 不处理的话这些标签会原样画出来。
///
/// 处理范围**刻意收窄**到"格式类"标签
/// 换成对应的行内节点。**其余标签（`<div>`、`<span>`…）一律保持字面量原样
/// 显示，内容不丢** —— 因为 `a<b`、`List<T>`、`x < y` 这类"小于号形状"的
/// 文本在技术回答里同样常见，见到 `<...>` 就抹掉会静默吃掉正文。
///
/// 配对规则与强调定界符一致：**只有配对成功才生效**。孤立的开标签（含流式期
/// 还没等到闭合的那一瞬间）、孤立的闭标签、超出嵌套深度的，全部按字面量输出。
class MarkdownInlineParser {
  MarkdownInlineParser._();

  /// 强调嵌套的深度上限。嵌套 markdown 超过三层没有实际用例，
  /// 超过就按字面量输出 —— 顺便给递归兜个底。
  static const int _maxDepth = 3;

  /// HTML 标签名长度上限。超长就不当标签 —— 名字要一直扫到非字母才结束，
  /// 而 `<` 后面跟一长串字母在正文里并不罕见，不设限就是 O(n²)。
  static const int _maxTagNameLen = 10;

  /// 标签名与 `>` 之间允许的空白 / `/` 字符数上限。够 `<br />`、`</b >` 用。
  static const int _maxTagSlack = 4;

  /// 找闭合标签时允许的同名嵌套层数。
  ///
  /// 超过就当"没配对"，按字面量输出。这是个**性能兜底**，不是语义选择：
  /// 同名标签深嵌套时，每个开标签的查找都要扫到自己的配对位置，不加限制
  /// 就是 O(n²)。8 层同名格式标签（`<b>` 套 `<b>` 套…）没有任何实际用例。
  static const int _maxSameNameNesting = 8;

  /// 支持的 HTML 标签表。`name` 一律小写，匹配时大小写不敏感。
  ///
  /// `emphasis` 为 null 即空标签（`<br>`）。加一个新的格式标签只要往这里
  /// 加一行 —— 扫描、配对、嵌套都是同一套逻辑。
  static const List<_HtmlTagDef> _htmlTags = [
    _HtmlTagDef('br', lineBreak: true),
    _HtmlTagDef('b', emphasis: MdInlineKind.bold),
    _HtmlTagDef('strong', emphasis: MdInlineKind.bold),
    _HtmlTagDef('i', emphasis: MdInlineKind.italic),
    _HtmlTagDef('em', emphasis: MdInlineKind.italic),
    // ⚠️ `<code>` 走 [MarkdownInline.code]（纯文本节点），不像其他强调节点
    //    那样递归解析 —— HTML 的 `<code>` 语义就是原样，里面的 `**` 不该生效。
    _HtmlTagDef('code', emphasis: MdInlineKind.code),
    _HtmlTagDef('del', emphasis: MdInlineKind.strikethrough),
    _HtmlTagDef('s', emphasis: MdInlineKind.strikethrough),
  ];

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
    // HTML 标签按名字独立记墓碑（一个种定界符死了不代表别种也死了）。
    final deadTags = <String>{};

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

      // ---- HTML 格式标签。见类文档的「HTML 标签」一节。----
      //
      // 位置：排在转义之后（`\<` 要能挡住它），与反引号分支**互不干扰** ——
      // 行内代码是整段原子吞掉的，`` `<br>` `` 里那个 `<` 根本走不到这里。
      if (c == '<') {
        final tag = _tryHtmlTag(s, i);
        if (tag != null) {
          final (def, closing, after) = tag;

          // `<br>` / `<br/>` → 换行。
          if (def.lineBreak && !closing) {
            // 段首的 `<br>` 丢掉：块解析已经把每行 `.trim()` 过，它等价于
            // 那点被去掉的前导空白，留着会在段首凭空多出一个空行。
            if (out.isEmpty && buf.isEmpty) {
              i = after;
              continue;
            }
            buf.write('\n');
            i = after;
            continue;
          }

          // `<b>…</b>` 这类 → 找配对，递归解析内容。
          if (!closing &&
              def.emphasis != null &&
              !deadTags.contains(def.name) &&
              depth < _maxDepth) {
            final close = _findCloseTag(s, after, def.name);
            final end = close.end;
            if (end != null) {
              final inner = s.substring(after, end);
              if (inner.isNotEmpty) {
                flush();
                // `<code>` 的语义就是原样 —— 里面的 `**` 不该生效，
                // 所以它是唯一直接产出纯文本节点、不递归解析的标签。
                out.add(def.emphasis == MdInlineKind.code
                    ? MarkdownInline.code(inner)
                    : MarkdownInline.emphasis(
                        def.emphasis!, _parse(inner, depth + 1)));
                i = close.after;
                continue;
              }
            } else if (close.exhausted) {
              // 与强调定界符同一个短路：`</name>` 在 i 之后不存在，那在更靠后的
              // 任何位置同样不存在。少了这一步，模型刷一串没闭合的 `<b>`（流式
              // 生成中途就是这样）会让每个开标签都扫到串尾 —— O(n²)。
              deadTags.add(def.name);
            }
          }
        }

        // 不认识的标签、没配对的开标签、孤立的闭标签 → **一律当字面量**，
        // 正文一个字都不丢（`a<b`、`List<T>`、讨论 HTML 语法本身都靠这条）。
        buf.write(c);
        i++;
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

      // ---- 图片 ![替代文字](地址)。与链接共用 linkDead 墓碑：两者都靠 `](`。----
      if (c == '!' &&
          !linkDead &&
          i + 1 < s.length &&
          s[i + 1] == '[') {
        final open = s.indexOf('](', i + 2);
        if (open < 0) {
          linkDead = true;
          buf.write(c);
          i++;
          continue;
        }
        final target = _linkTarget(s, open + 2);
        if (target == null) {
          buf.write(c);
          i++;
          continue;
        }
        final (src, after) = target;
        final alt = s.substring(i + 2, open);
        if (src.isEmpty || alt.contains('\n')) {
          buf.write(c);
          i++;
          continue;
        }
        flush();
        out.add(MarkdownInline.image(alt, src));
        i = after;
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
        if (s.indexOf(')', open + 2) < 0) {
          linkDead = true;
          buf.write(c);
          i++;
          continue;
        }
        final target = _linkTarget(s, open + 2);
        if (target == null) {
          buf.write(c);
          i++;
          continue;
        }
        final (href, after) = target;
        final label = s.substring(i + 1, open);
        if (label.isEmpty || href.isEmpty) {
          buf.write(c);
          i++;
          continue;
        }
        flush();
        out.add(MarkdownInline.link(label, href));
        i = after;
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

  /// 解析 `(` 之后的链接目标，返回 `(目标, `)` 之后的下标)`；不成形返回 null。
  ///
  /// 支持 CommonMark 的尖括号写法 `(<含 空格 的路径>)` —— Windows 本地截图路径
  /// 常带空格（用户名、`Program Files`），不包起来的话第一个空格就把路径截断了。
  static (String, int)? _linkTarget(String s, int from) {
    var i = from;
    while (i < s.length && s[i] == ' ') {
      i++;
    }
    if (i < s.length && s[i] == '<') {
      final end = s.indexOf('>', i + 1);
      if (end < 0) return null;
      final inner = s.substring(i + 1, end);
      if (inner.contains('\n')) return null;
      var j = end + 1;
      while (j < s.length && s[j] == ' ') {
        j++;
      }
      if (j >= s.length || s[j] != ')') return null;
      return (inner, j + 1);
    }
    final close = s.indexOf(')', from);
    if (close < 0) return null;
    return (s.substring(from, close).trim(), close + 1);
  }

  /// 从 [start] 处（`s[start] == '<'`）尝试认一个 HTML 标签。
  ///
  /// 返回 `(标签定义, 是否闭标签, 标签结束后的下标)`；不是**已知**标签就返回 null
  /// —— 未知标签一律按字面量走，调用方不需要区分"不认识的标签"和"根本不是标签"。
  ///
  /// 认下的语法（大小写不敏感）：
  ///
  /// - `<br>`、`<br/>`、`<br />` —— 闭合斜杠可有可无，标签内不能有属性
  /// - `</b>`、`</b >` —— 闭标签。
  ///
  /// 只扫到 [_maxTagNameLen] 个字符就得见到 `>`，否则不算 —— `a<b<c<d…` 这种
  /// 长串里每个 `<` 都要扫到串尾就是 O(n²)。
  static (_HtmlTagDef, bool, int)? _tryHtmlTag(String s, int start) {
    var i = start + 1;
    var closing = false;

    if (i < s.length && s[i] == '/') {
      closing = true;
      i++;
    }

    // 标签名：ASCII 字母。
    final nameStart = i;
    while (i < s.length &&
        i - nameStart <= _maxTagNameLen &&
        _isAsciiLetter(s.codeUnitAt(i))) {
      i++;
    }
    if (i == nameStart || i - nameStart > _maxTagNameLen) return null;

    final name = s.substring(nameStart, i).toLowerCase();
    final def = _tagByName(name);
    if (def == null) return null;

    // 名字与 `>` 之间：空白与一个可选的自闭合斜杠。
    var slack = 0;
    while (i < s.length && slack <= _maxTagSlack) {
      final ch = s[i];
      if (ch == '>') {
        // 自闭合的 `</b/>` 没有意义，当普通闭标签处理（宽容一点不报错）。
        return (def, closing, i + 1);
      }
      if (ch == ' ' || ch == '\t' || (ch == '/' && !closing)) {
        slack++;
        i++;
        continue;
      }
      return null; // 有属性或别的字符 → 不是我们支持的标签。
    }
    return null;
  }

  /// 找 [name] 的闭标签。
  ///
  /// 返回 `(内容终点, 闭标签结束后的下标, 是否已扫到串尾)`。
  /// [end] 为 null 即没找到 —— 此时 [exhausted] 区分两种原因：true 表示
  /// **确实不存在**（调用方可以给这种标签立墓碑），false 只是同名嵌套超了
  /// [_maxSameNameNesting]，后面的文本里可能还有。
  ///
  /// 同名嵌套按**深度计数**配对（`<b>a<b>b</b>c</b>` 的外层要配最后那个
  /// `</b>`），所以不能简单 `indexOf('</b>')`。
  ///
  /// ⚠️ 必须是**单趟前向**扫描。不能每轮都 `indexOf('</', cursor)` 重新找 ——
  /// 输入 `<b>` + 一万个孤立 `<` + `</b>` 会让每轮都重扫同一段尾巴，退化成
  /// O(n²)。这里 `indexOf` 只用来**跳过**到下一个 `<`，每个位置过一遍。
  static ({int? end, int after, bool exhausted}) _findCloseTag(
      String s, int from, String name) {
    var cursor = from;
    var nesting = 1;

    while (cursor < s.length) {
      final lt = s.indexOf('<', cursor);
      if (lt < 0) break;
      final t = _tryHtmlTag(s, lt);

      // 不是已知标签（`<` 后面跟数字、或未知标签名）→ 跳过这个 `<` 继续。
      if (t == null) {
        cursor = lt + 1;
        continue;
      }

      final (def, closing, after) = t;
      // 别的标签不参与配对，但仍然整体跳过 —— 否则 `<div>` 里的 `div` 会被
      // 当成正文再扫一遍。注意**未知标签走的是上面那条**，因为 _tryHtmlTag
      // 对它们返回 null，这里不会把它们整段吃掉。
      if (def.name != name) {
        cursor = after;
        continue;
      }

      if (!closing) {
        nesting++;
        if (nesting > _maxSameNameNesting) {
          return (end: null, after: after, exhausted: false);
        }
        cursor = after;
        continue;
      }

      nesting--;
      if (nesting == 0) {
        // ⚠️ [end] 是闭标签的**起点**（`</` 那个 `<`），调用方拿它当内容终点
        //    切片。绝不能返回 `from` —— 那会让内容恒为空串，表现为标签连着
        //    正文一起被悄悄吞掉。
        return (end: lt, after: after, exhausted: false);
      }
      cursor = after;
    }

    return (end: null, after: s.length, exhausted: true);
  }

  /// 查表。标签表只有 8 条，线性扫比建 map 划算（且是 const）。
  static _HtmlTagDef? _tagByName(String name) {
    for (final d in _htmlTags) {
      if (d.name == name) return d;
    }
    return null;
  }

  static bool _isAsciiLetter(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);

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

/// 一条受支持的 HTML 标签规则。
///
/// [name] 必须是小写；匹配时把源码里的名字 `toLowerCase()` 后比对。
/// [lineBreak] 与 [emphasis] 互斥 —— 前者是空标签（`<br>`），后者要配闭合。
class _HtmlTagDef {
  const _HtmlTagDef(this.name, {this.lineBreak = false, this.emphasis});

  final String name;
  final bool lineBreak;

  /// null 表示这个标签不产出强调节点（目前只有 `<br>`）。
  final MdInlineKind? emphasis;
}
