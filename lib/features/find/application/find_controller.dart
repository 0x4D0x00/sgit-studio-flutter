import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 页内查找状态。
///
/// 匹配数分两个区域，**由各区域自己数完报上来**（左栏历史列表、会话转录），
/// 全局序号 = 左栏在前、转录在后（与屏幕上从左到右、从上到下的顺序一致）。
/// 控制器不碰任何文本，只管「当前是第几个」。
@immutable
class FindState {
  const FindState({
    this.open = false,
    this.query = '',
    this.current = 0,
    this.navCount = 0,
    this.transcriptCount = 0,
    this.revealTick = 0,
    this.focusTick = 0,
  });

  final bool open;
  final String query;

  /// 当前匹配的全局序号（0 起）。没有匹配时无意义。
  final int current;

  final int navCount;
  final int transcriptCount;

  /// 每次要求「滚到当前匹配」（输入变了 / 点了上下箭头）+1。
  /// 匹配数因流式内容变化而变时**不**动它 —— 否则回答在长的时候视口会被一直拽着走。
  final int revealTick;

  /// 每次要求「查找框拿焦点并全选」（已打开时再按 Ctrl+F）+1。
  final int focusTick;

  int get total => navCount + transcriptCount;
  bool get active => open && query.isNotEmpty;

  FindState copyWith({
    bool? open,
    String? query,
    int? current,
    int? navCount,
    int? transcriptCount,
    int? revealTick,
    int? focusTick,
  }) => FindState(
    open: open ?? this.open,
    query: query ?? this.query,
    current: current ?? this.current,
    navCount: navCount ?? this.navCount,
    transcriptCount: transcriptCount ?? this.transcriptCount,
    revealTick: revealTick ?? this.revealTick,
    focusTick: focusTick ?? this.focusTick,
  );
}

class FindController extends Notifier<FindState> {
  @override
  FindState build() => const FindState();

  /// 打开查找框；已经开着就让输入框重新拿焦点并全选。
  void show() {
    state = state.open
        ? state.copyWith(focusTick: state.focusTick + 1)
        : state.copyWith(open: true, focusTick: state.focusTick + 1);
  }

  void close() {
    if (!state.open) return;
    state = state.copyWith(open: false);
  }

  void setQuery(String query) {
    if (query == state.query) return;
    state = state.copyWith(
      query: query,
      current: 0,
      revealTick: state.revealTick + 1,
    );
  }

  void next() => _step(1);
  void previous() => _step(-1);

  void _step(int delta) {
    final total = state.total;
    if (!state.active || total == 0) return;
    state = state.copyWith(
      current: (state.current + delta) % total,
      revealTick: state.revealTick + 1,
    );
  }

  /// 左栏历史列表报上来的匹配数。
  void setNavCount(int n) {
    if (n == state.navCount) return;
    state = _withCounts(navCount: n);
  }

  /// 会话转录报上来的匹配数。
  void setTranscriptCount(int n) {
    if (n == state.transcriptCount) return;
    state = _withCounts(transcriptCount: n);
  }

  FindState _withCounts({int? navCount, int? transcriptCount}) {
    final nav = navCount ?? state.navCount;
    final tr = transcriptCount ?? state.transcriptCount;
    final total = nav + tr;
    return state.copyWith(
      navCount: nav,
      transcriptCount: tr,
      current: total == 0 ? 0 : state.current.clamp(0, total - 1),
    );
  }
}

final findControllerProvider = NotifierProvider<FindController, FindState>(
  FindController.new,
);
