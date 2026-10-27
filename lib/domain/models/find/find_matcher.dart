/// 页内查找的匹配规则 —— **纯 Dart**。
///
/// 计数（决定「2/3」的总数）与高亮（决定画哪几段）必须用同一套规则，否则两边
/// 各数各的，序号对不上。所以两处都只调这里。
///
/// 不区分大小写；查询串按字面匹配（正则元字符会被转义）。
library;

abstract final class FindMatcher {
  static String? _lastQuery;
  static RegExp? _lastPattern;

  static RegExp? _pattern(String query) {
    if (query.isEmpty) return null;
    if (query != _lastQuery) {
      _lastQuery = query;
      _lastPattern = RegExp(
        RegExp.escape(query),
        caseSensitive: false,
        unicode: true,
      );
    }
    return _lastPattern;
  }

  /// [text] 里所有匹配的 `[start, end)`，按出现顺序，互不重叠。
  static List<(int, int)> ranges(String text, String query) {
    final re = _pattern(query);
    if (re == null || text.isEmpty) return const [];
    return [for (final m in re.allMatches(text)) (m.start, m.end)];
  }

  /// 单行省略显示的文本（左栏标题）里，匹配可能落在被截掉的后半段。
  /// 第一个匹配离开头太远时，改成从它前面几个字开始显示（前面补「…」），
  /// 其余匹配都在它后面，所以不丢、编号也不变。
  static String snippet(String text, String query, {int lead = 6}) {
    final r = ranges(text, query);
    if (r.isEmpty || r.first.$1 <= lead + 8) return text;
    return '…${text.substring(r.first.$1 - lead)}';
  }

  static int count(String text, String query) {
    final re = _pattern(query);
    if (re == null || text.isEmpty) return 0;
    return re.allMatches(text).length;
  }
}
