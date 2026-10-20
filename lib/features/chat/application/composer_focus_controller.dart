import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 「把光标送到对话输入框」的中转站。
///
/// 发起方（搜索弹窗的 `Tab`、将来可能的全局快捷键）与执行方（`ChatComposer`
/// 的 [FocusNode]）不在同一棵子树里，且发起时输入框可能还没挂载 —— 直接拿
/// 对方的 FocusNode 是拿不到的。所以只登记「有一张待办」，由输入框在挂载后
/// 自己领走。
///
/// ⚠️ 不持有 FocusNode 本身：输入框会在空态/会话态之间整棵重建，FocusNode
/// 跟着 State 一起销毁，provider 里留一个已 dispose 的节点必然崩。
class ComposerFocusController extends Notifier<int> {
  /// 每次请求 +1。输入框监听这个计数，变了就把焦点抢过来。
  @override
  int build() => 0;

  /// 请求聚焦。只发信号，不管导航 —— 跳不跳页由调用方决定。
  void requestFocus() => state = state + 1;
}

final composerFocusProvider =
    NotifierProvider<ComposerFocusController, int>(
  ComposerFocusController.new,
);
