/// 用户消息里携带的「引用」（选中对话文字后点「回复」加入的片段）。
///
/// 线上格式：消息开头依次排 `<quote>\n…\n</quote>\n\n`，后面才是用户自己写的正文。
/// 内核与模型看到的就是这段原文；界面把它拆开，引用画成卡片、正文画进气泡。
/// 历史回放拿回来的也是同一份原文，所以拆分只依赖文本本身。
class MessageQuotes {
  MessageQuotes._();

  static final _lead = RegExp(r'^<quote>\n([\s\S]*?)\n</quote>\n\n');

  static String encode(List<String> quotes, String body) {
    if (quotes.isEmpty) return body;
    final head = quotes.map((q) => '<quote>\n$q\n</quote>\n\n').join();
    return '$head$body';
  }

  static ({List<String> quotes, String body}) split(String text) {
    final quotes = <String>[];
    var rest = text;
    for (var m = _lead.firstMatch(rest); m != null; m = _lead.firstMatch(rest)) {
      quotes.add(m.group(1)!);
      rest = rest.substring(m.end);
    }
    return (quotes: quotes, body: rest);
  }
}
