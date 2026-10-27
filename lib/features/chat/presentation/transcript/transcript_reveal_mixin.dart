import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/artifact/artifact.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';
import 'package:sgit_studio_flutter/features/artifacts/application/artifacts_controller.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/artifact_chip.dart';

/// 对话流的「定位到某张文件卡」能力（从输出物页点进来时用）。
///
/// 从 `ChatTranscript` 的 State 里整段搬出，逻辑未改。宿主需要提供滚动控制器，
/// 并允许这里关掉「跟随最新」（定位期间不能被钉回底部）。
mixin TranscriptRevealMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// 宿主的列表滚动控制器。
  ScrollController get scroll;

  /// 定位期间要关掉跟随。
  set follow(bool value);

  /// 每条目一把 GlobalKey —— 「定位到某条」要靠它拿到已建出的那条的 context。
  /// 只有**当前建在树里的**条目才会有 currentContext，见 [_reveal]。
  final itemKeys = <int, GlobalKey>{};

  bool _revealScheduled = false;

  /// 本次定位已经试了几步。上限见 [_maxRevealSteps]。
  int _revealSteps = 0;

  /// 定位的步数上限。每步都是一次跳转 + 一帧，几千条的会话也在几十步内收敛
  /// （步长按「目标离已建范围多远」自适应），超了说明条目没了/出了岔子，放弃。
  static const _maxRevealSteps = 80;

  void scheduleReveal() {
    if (_revealScheduled) return;
    _revealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _revealScheduled = false;
      if (!mounted) return;
      _reveal();
    });
  }

  /// 把 `artifactFocusProvider` 请求的那张文件卡滚进视野。
  ///
  /// 从输出物页点进来时，会话是**先进页面、内容后到**的（见
  /// `ChatController.openThreadById`），所以这里可能被调很多次：载入中直接
  /// 返回，内容到齐后才真正动手。
  ///
  /// ## 为什么是「逐步逼近」而不是直接 `ensureVisible`
  ///
  /// 列表是惰性的，目标条目离视口远时**根本没建出来**，没有 context 可用。
  /// 做法：每步按「目标在已建范围的哪一侧」朝它跳一段，等下一帧建出新条目再判断，
  /// 直到目标建出来，再对它里面那张文件卡 `ensureVisible`。
  void _reveal() {
    final focus = ref.read(artifactFocusProvider);
    if (focus == null) return;
    final ctrl = ref.read(chatControllerProvider.notifier);
    // 载入中：内容还没到，等 openingThread 变 false 的监听再来。
    if (ref.read(chatControllerProvider).openingThread) return;

    final items = ctrl.items;
    final idx = _indexOfArtifact(items, focus);
    if (idx < 0) {
      // 会话载完了也没找到（被编辑重发丢掉了 / 打开失败）—— 面板已经开了，放弃定位。
      _finishReveal();
      return;
    }

    // 定位期间不能让「跟随最新」把视口钉回底部。
    follow = false;

    final target = _chipContext(itemKeys[items[idx].id]?.currentContext, focus);
    if (target != null) {
      _finishReveal();
      Scrollable.ensureVisible(
        target,
        alignment: 0.3,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if (++_revealSteps > _maxRevealSteps || !scroll.hasClients) {
      _finishReveal();
      return;
    }
    final p = scroll.position;
    if (!p.hasContentDimensions) {
      scheduleReveal();
      return;
    }

    // 目标在列表里的位置（反向列表：越靠上越大）与当前已建出的范围。
    final targetPos = items.length - 1 - idx;
    var builtMin = items.length, builtMax = -1;
    for (final e in itemKeys.entries) {
      if (e.value.currentContext == null) continue;
      final at = items.indexWhere((it) => it.id == e.key);
      if (at < 0) continue;
      final pos = items.length - 1 - at;
      if (pos < builtMin) builtMin = pos;
      if (pos > builtMax) builtMax = pos;
    }

    double step;
    bool older;
    if (builtMax < 0) {
      step = p.viewportDimension;
      older = true;
    } else {
      older = targetPos > builtMax;
      final gap = older ? targetPos - builtMax : builtMin - targetPos;
      final perScreen = (builtMax - builtMin + 1).clamp(1, 1 << 20);
      step = p.viewportDimension * (gap / perScreen * 0.8).clamp(0.9, 40.0);
    }
    final next = (p.pixels + (older ? step : -step)).clamp(
      p.minScrollExtent,
      p.maxScrollExtent,
    );
    if (next == p.pixels) {
      // 已经顶到头还没建出来：内容高度还没算全，等下一帧。
      scheduleReveal();
      return;
    }
    scroll.jumpTo(next);
    scheduleReveal();
  }

  void _finishReveal() {
    _revealSteps = 0;
    ref.read(artifactFocusProvider.notifier).clear();
  }

  /// 在 [items] 里找那张文件卡所在的消息。
  ///
  /// 先按「偏移 + 内容」精确匹配，退而只比内容 —— 偏移是规范化后原文里的位置，
  /// 同一条回复被服务端重放时理论上不变，但内容才是真正的身份。
  int _indexOfArtifact(List<ChatItem> items, Artifact focus) {
    var loose = -1;
    for (var i = items.length - 1; i >= 0; i--) {
      final it = items[i];
      if (it is! TextItem || it.role != ChatRole.assistant) continue;
      // 与渲染侧取同一份文本 —— 偏移（sourceStart）必须来自同一串字符。
      final text = it.displayText;
      if (!text.contains('```') && !text.contains('~~~')) continue;
      for (final a in ChatArtifact.fromBlocks(
        MarkdownParser.parse(text),
        text,
      )) {
        if (a.content != focus.content) continue;
        if (a.sourceStart == focus.sourceStart) return i;
        if (loose < 0) loose = i;
      }
    }
    return loose;
  }

  /// 在某条消息的子树里找文件卡本身的 context。
  ///
  /// 滚到卡片而不是整条消息：回复可能比一屏还高，居中消息会错过卡片。
  BuildContext? _chipContext(BuildContext? root, Artifact focus) {
    if (root == null) return null;
    BuildContext? found;
    void visit(Element e) {
      if (found != null) return;
      final w = e.widget;
      if (w is ArtifactChip &&
          w.artifact.content == focus.content &&
          w.artifact.sourceStart == focus.sourceStart) {
        found = e;
        return;
      }
      e.visitChildren(visit);
    }

    (root as Element).visitChildren(visit);
    // 没精确命中（偏移变了）就退回整条消息，至少落在正确的回复上。
    return found ?? root;
  }
}
