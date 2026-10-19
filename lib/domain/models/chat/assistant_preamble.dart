/// 助手回复开头的「技能 / 工具调用抬头」。
///
/// ## 为什么需要它
///
/// 模型偶尔不把调用交给工具通道，而是**把调用意图直接写进正文**。见过三种形态：
///
/// ```
/// imagegen
/// file: r1/svg-diagram/SKILL.md
/// "Generate a basic style flowchart with standard elements: ..."
/// ```
///
/// ```
/// skill-creator
/// {"name": "website_list", "description": "Create a list of ...", "url": "..."}
/// ```
///
/// ```
/// skill-creator
/// {
/// "name": "comparison skill",
/// "file": "C:/.../comparison_skill/SKILL.md",
/// "description": "..."
/// }comparison skill
/// {
/// "tech1": "Claude",
/// "tech2": "DeepSeek"
/// }
/// ```
///
/// 抬头之后才是真正给用户看的回答。这是模型的输出噪声，不是回答内容 ——
/// 界面上既不该显示，也不该被复制走。
///
/// ## 结构
///
/// 抬头 = **一行技能名** + **一到多段参数**。参数段只有三种：
///
/// | 段 | 形状 | 收尾判据 |
/// |---|---|---|
/// | 路径 | `file: <带分隔符的路径>` | 行尾 |
/// | 引号串 | `"..."` | 某一行以 `"` 收尾 |
/// | JSON 对象 | `{...}` | 花括号配平到 0 |
///
/// 抬头以第一个「不是参数段」的行为界，界线之后一个字都不动。
///
/// ## 为什么是「结构匹配」而不是「删掉开头的英文」
///
/// 绝不能按「开头是英文就删」来做：一条正常回答完全可能以英文开头
/// （`Yes.` / `The fix is to restart.`），删错一次就是**吞掉用户的问题答案**，
/// 比多显示三行噪声糟得多。所以收紧到三条：
///
/// 1. 首行必须是**全小写的裸标识符**（`skill-creator` / `imagegen`）——
///    正常句子里的 `Example` / `Note` / `Yes` 因为有大写而被排除；
/// 2. 首行之后必须**紧跟着至少一段参数**，光有一个词不算抬头；
/// 3. 任何一段判不出收尾就**整体放弃**，原样返回（见下）。
///
/// ## 流式期：什么时候「先藏」，什么时候「放弃」
///
/// 参数段没收尾有两种可能 —— 还在往外吐，或者压根不是抬头。分不清时：
///
/// - **路径段**：`file:` + 带分隔符的路径已经是强信号，判不出来就**先藏**；
/// - **引号段**：前面已经收尾过别的段 → 先藏；这是**第一段** → 放弃（宁可多显示）；
/// - **JSON 段**：`{` 之后第一个非空白字符是 `"` → 先藏；否则放弃。
///
/// 外加每段 [_segmentLimit] 的长度闸：长到不可能还在写，一律放弃。
/// 缺了这道闸，一个畸形引号或花括号会把后面整篇回答一起吞掉 ——
/// 那是比多显示三行噪声严重得多的失败。
abstract final class AssistantPreamble {
  /// 只检查开头这么多字符 —— 抬头一定在最前面，长回答不必为此全文扫描。
  static const int _headLimit = 8 * 1024;

  /// 单个参数段的长度上限。超过它还没收尾 → 判定不是抬头，原样返回。
  static const int _segmentLimit = 16 * 1024;

  /// 技能名允许的字符。
  ///
  /// ⚠️ **只认全小写**。真实工具名（`imagegen` / `skill-creator` /
  /// `mcp__server__tool` / `image_gen.imagegen`）都是小写；而正常回答里
  /// 单独成行的英文单词（`Example` / `Note` / `Yes`）总是大写成句首。
  /// 这一条是「不误删正文」最便宜的保险。
  static final RegExp _toolName = RegExp(r'^[a-z0-9][a-z0-9_.-]{0,63}$');

  /// 闭合 `}` 之后可能残留的技能名（`}comparison skill`）。
  ///
  /// 允许空格（技能名本身可能是两个词），但**不许**出现中文或标点 ——
  /// 那说明这一行已经进正文了，不能连正文一起吞。
  static final RegExp _trailingName = RegExp(r'^[A-Za-z0-9_.\- ]+$');

  /// 路径段的固定前缀。
  static const String _filePrefix = 'file:';

  /// `_segmentEnd` 的返回：这一段还没收尾，调用方应「先藏」。
  static const int _unterminated = -1;

  /// `_segmentEnd` 的返回：这一段判不出收尾，调用方应「放弃识别」。
  static const int _giveUp = -2;

  /// `_segmentEnd` 的返回：这一行不是参数段 —— 抬头到此为止，但已认出的段照收。
  ///
  /// ⚠️ 必须与 [_unterminated] / [_giveUp] 区分开。三者都是负数，混用会
  /// 让「抬头正常结束」被当成「还没吐完」，整条回答直接空白。
  static const int _notSegment = -3;

  /// 去掉开头这段抬头；不匹配时原样返回 [text]。
  static String strip(String text) {
    if (text.isEmpty) return text;

    final head = text.length > _headLimit ? text.substring(0, _headLimit) : text;

    // 首行必须完整（有换行）—— 只有一行「imagegen」时看不出这是抬头还是回答。
    final firstBreak = head.indexOf('\n');
    if (firstBreak <= 0) return text;

    final first = _withoutCr(head.substring(0, firstBreak)).trim();
    if (!_toolName.hasMatch(first)) return text;

    var cursor = firstBreak + 1;
    // 首行之后什么都没有 —— 还在流式，或者这压根不是抬头。原样显示。
    if (cursor >= text.length) return text;

    var segments = 0;

    while (true) {
      final lineStart = cursor;
      final line = _lineAt(text, cursor);
      if (line == null) break; // 到底了

      final trimmed = line.trimLeft();
      if (trimmed.isEmpty) {
        cursor = _nextLineStart(text, lineStart);
        continue;
      }

      final end = _segmentEnd(text, lineStart, trimmed, segments);
      if (end == _giveUp) return text; // 不是抬头 —— 一个字都别动
      if (end == _unterminated) return ''; // 还在吐 —— 整段先藏
      if (end == _notSegment) break; // 抬头到此为止

      cursor = end;
      segments++;
    }

    // 一段参数都没有 → 不是抬头。宁可漏，不可误删。
    if (segments == 0) return text;

    // 抬头与正文之间的空行一并吃掉。
    while (true) {
      final line = _lineAt(text, cursor);
      if (line == null) return '';
      if (line.trim().isNotEmpty) break;
      cursor = _nextLineStart(text, cursor);
    }

    return text.substring(cursor);
  }

  /// 从 [lineStart] 这一行开始试认一个参数段。
  ///
  /// 返回**该段收尾之后的偏移**；或 [_unterminated] / [_giveUp] / [_notSegment]。
  ///
  /// [closed] 是此前已经收尾的段数 —— 引号段拿它决定「先藏还是放弃」。
  static int _segmentEnd(
      String text, int lineStart, String trimmed, int closed) {
    if (trimmed.startsWith(_filePrefix)) {
      return _pathSegment(text, lineStart, trimmed);
    }
    if (trimmed.startsWith('"')) {
      final end = _quotedBlockEnd(text, lineStart);
      if (end == null) {
        // 前面已收尾过别的段 → 这几乎肯定还是抬头，先藏；
        // 这是第一段 → 可能只是正文里一行以引号开头的话，不冒险。
        if (closed == 0) return _giveUp;
        return text.length - lineStart > _segmentLimit
            ? _giveUp
            : _unterminated;
      }
      return _afterSegment(text, end);
    }
    if (trimmed.startsWith('{')) {
      final end = _jsonObjectEnd(text, lineStart);
      if (end < 0) {
        // 判不出是不是 JSON 对象 → 不是参数段，但也不算「放弃识别」。
        if (end == _unterminated) {
          return text.length - lineStart > _segmentLimit
              ? _giveUp
              : _unterminated;
        }
        return _giveUp;
      }
      return _afterSegment(text, end);
    }
    return _notSegment;
  }

  /// 路径段：`file: <路径>`。必须像路径（有分隔符、不含空白），
  /// 挡掉「file: 说明」这类普通句子。
  static int _pathSegment(String text, int lineStart, String trimmed) {
    final path = trimmed.substring(_filePrefix.length).trim();
    if (path.isEmpty ||
        path.contains(RegExp(r'\s')) ||
        (!path.contains('/') && !path.contains(r'\'))) {
      return _notSegment;
    }
    // 这一行还没写完（流式）→ 先藏。缺了它，半条路径会先以正文显示一下。
    if (_isLastLine(text, lineStart)) return _unterminated;
    return _nextLineStart(text, lineStart);
  }

  /// 收尾偏移 → 抬头内的下一个位置。
  ///
  /// 处理 `}comparison skill` 这种「闭合符后面同一行还挂着一个技能名」的写法：
  /// 该行的剩余部分**是纯 ASCII 名字**就一起吃进抬头。
  /// 一旦出现中文 / 标点，说明这一行已经是正文了，只吃到闭合符为止。
  static int _afterSegment(String text, int end) {
    final rest = _lineAt(text, end);
    if (rest == null) return end;
    if (rest.trim().isNotEmpty && !_trailingName.hasMatch(rest.trim())) {
      return end;
    }
    return _nextLineStart(text, end);
  }

  /// [start] 处那一行（不含换行符）。越界返回 null。
  static String? _lineAt(String s, int start) {
    if (start >= s.length) return null;
    final end = s.indexOf('\n', start);
    return _withoutCr(s.substring(start, end < 0 ? s.length : end));
  }

  /// [start] 所在行的下一行起点；已经是最后一行则返回 [s] 的长度。
  static int _nextLineStart(String s, int start) {
    final end = s.indexOf('\n', start);
    return end < 0 ? s.length : end + 1;
  }

  static bool _isLastLine(String s, int start) => s.indexOf('\n', start) < 0;

  /// 从引号段的第一行开始，返回**收尾行末尾**的偏移；没收尾返回 null。
  ///
  /// 收尾判据是「某一行以 `"` 收尾」。参数本身可能跨行，所以不能只看首行。
  static int? _quotedBlockEnd(String s, int start) {
    var cursor = start;
    while (cursor < s.length) {
      final end = s.indexOf('\n', cursor);
      final lineEnd = end < 0 ? s.length : end;
      final line = _withoutCr(s.substring(cursor, lineEnd)).trimRight();
      // 首行只有开引号也算数（例如 `"` 单独一行起头）。
      if (line.length > 1 && line.endsWith('"')) return lineEnd;
      if (end < 0) return null;
      cursor = end + 1;
    }
    return null;
  }

  /// 从 `{` 所在行开始配平花括号，返回**闭合 `}` 之后**的偏移。
  ///
  /// 返回 [_unterminated] 表示还没闭合，[_giveUp] 表示这不像 JSON 对象。
  ///
  /// ⚠️ 只数字符串外的花括号 —— JSON 里的 `"description": "{...}"` 是常见写法，
  /// 把它们也数进去会永远配不平。
  ///
  /// 「像 JSON」的判据是 `{` 之后第一个非空白字符是 `"`（一个键），
  /// 且配平范围内出现过 `:`。缺了它，普通段落里随手一对花括号就会被当成参数段。
  static int _jsonObjectEnd(String s, int start) {
    // 定位这一行的 `{`（可能有缩进）。
    var i = start;
    while (i < s.length && (s[i] == ' ' || s[i] == '\t')) {
      i++;
    }
    if (i >= s.length || s[i] != '{') return _giveUp;

    // `{` 之后（可跨行）第一个非空白字符必须是 `"`。
    var probe = i + 1;
    while (probe < s.length &&
        (s[probe] == ' ' || s[probe] == '\t' || s[probe] == '\n' || s[probe] == '\r')) {
      probe++;
    }
    if (probe >= s.length || s[probe] != '"') return _giveUp;

    var depth = 0;
    var inString = false;
    var escaped = false;
    var sawColon = false;

    for (; i < s.length; i++) {
      final c = s[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (c == r'\') {
          escaped = true;
        } else if (c == '"') {
          inString = false;
        }
        continue;
      }
      if (c == '"') {
        inString = true;
      } else if (c == ':') {
        sawColon = true;
      } else if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) {
          // 配平了但没有键值对 —— 不是 JSON 对象。
          return sawColon ? i + 1 : _giveUp;
        }
      }
    }
    return _unterminated;
  }

  static String _withoutCr(String s) =>
      s.endsWith('\r') ? s.substring(0, s.length - 1) : s;
}
