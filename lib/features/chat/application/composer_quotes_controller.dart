import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 输入框里待发送的「引用」（从对话正文里选中后点「回复」加进来的片段）。
///
/// 发起方（对话流的选区浮钮）与持有方（`ChatComposer`）不在同一棵子树里，
/// 且输入框会在空态/会话态之间整棵重建 —— 状态放在 provider 里，
/// 重建时引用不会丢。
class ComposerQuotesController extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void add(String text) {
    final t = text.trim();
    if (t.isEmpty || state.contains(t)) return;
    state = [...state, t];
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.length) return;
    state = [...state]..removeAt(index);
  }

  void clear() => state = const [];
}

final composerQuotesProvider =
    NotifierProvider<ComposerQuotesController, List<String>>(
  ComposerQuotesController.new,
);
