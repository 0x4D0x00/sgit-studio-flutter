import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';

/// Markdown 块级缓存 —— 流式增量解析的全部性能在这里。
///
/// ## 为什么它是对的
///
/// 追加文本只会让**最后一块**长大(段落续行、表格续行、未闭合围栏吃字符)，
/// 不可能回头改动前面已封口的块。因此只需要：
/// 1. 判新文本是否**以旧文本为前缀**(流式追加的常态)；
/// 2. 是 → 丢弃最后一块，从它的 [MarkdownBlock.sourceStart] 起重解析；
/// 3. 否(编辑/重发/回放) → 全量重解析。
///
/// 每次 delta 的代价 = **O(最后一块的长度)**，不是 O(全文)。
///
/// 唯一的伪例外是 setext 标题(`文字` + 后续 `===` 把段落变成标题)，但那时
/// 那个段落正是最后一块，本来就在重解析范围内。
class MarkdownViewCache {
  String? _prevText;
  List<MarkdownBlock>? _blocks;

  /// 解析 [text]，尽可能复用上次的块。
  ///
  /// 流式追加时返回的列表**前 N-1 块与上次 identity 相同** ——
  /// [MarkdownView] 用 `KeyedSubtree(key: ValueKey(block.sourceStart))` 包每块，
  /// 复用 blocks[i] identity → Flutter 复用 Element，跳过 build 与 layout。
  List<MarkdownBlock> parse(String text) {
    final prev = _prevText;
    final blocks = _blocks;

    // 初次或文本含 `\r`(Windows 换行未统一) → 全量解析。
    if (prev == null || text.contains('\r')) {
      final result = MarkdownParser.parse(text);
      _prevText = text;
      _blocks = result;
      return result;
    }

    // 新文本以旧文本为前缀 → 增量。
    if (text.startsWith(prev) && blocks != null && blocks.isNotEmpty) {
      final lastBlock = blocks.last;
      final prefix = blocks.sublist(0, blocks.length - 1);

      // 从最后一块的起点重新解析尾巴(含旧块内容+新增部分)。
      final reparse = text.substring(lastBlock.sourceStart);
      final newTail = MarkdownParser.parse(
        reparse,
        offsetBias: lastBlock.sourceStart,
      );

      final result = [...prefix, ...newTail];
      _prevText = text;
      _blocks = result;
      return result;
    }

    // 否则(编辑/重发/回放) → 全量。
    final result = MarkdownParser.parse(text);
    _prevText = text;
    _blocks = result;
    return result;
  }

  void clear() {
    _prevText = null;
    _blocks = null;
  }
}
