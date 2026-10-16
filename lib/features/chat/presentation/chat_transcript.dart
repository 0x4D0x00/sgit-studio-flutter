import 'dart:async';

import 'package:flutter/material.dart';
// `ScrollDirection` 住 rendering 层，material 不转出来。
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/design/tokens/bubble_metrics.dart';
import 'package:sgit_studio_flutter/domain/models/artifact/artifact.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';
import 'package:sgit_studio_flutter/features/artifacts/application/artifacts_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/model_list_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/services/brand/brand_assets.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/approval_card.dart';
import 'package:sgit_studio_flutter/ui/components/chat/artifact_chip.dart';
import 'package:sgit_studio_flutter/ui/components/chat/jump_to_latest_button.dart';
import 'package:sgit_studio_flutter/ui/components/chat/notice_bar.dart';
import 'package:sgit_studio_flutter/ui/components/chat/text_bubble.dart';
import 'package:sgit_studio_flutter/ui/components/chat/thinking_row.dart';
import 'package:sgit_studio_flutter/ui/components/chat/tool_card.dart';

/// 对话流。
///
/// ## 为什么订阅的是 `itemsRevision` 而不是 provider 的 state
///
/// 列表**只在增删条目时**重建；流式文本的每一条 delta 只让对应气泡自己重建
/// （见各卡片内部的 `ValueListenableBuilder`）。如果这里改成
/// `ref.watch(chatControllerProvider)`，一条 delta 就会重建整个 `ListView`，
/// 长会话直接掉帧 —— 那样 FFI 那一堆零拷贝的努力全白费。
///
/// ## 为什么列表是 `reverse: true`（**翻过来画**）
///
/// 视觉上「底部」恒定落在滚动坐标的 0 上。这一条同时买下三件事：
///
/// 1. **自动下滑是免费的**。新内容加在 0 的另一侧，视口纹丝不动 ——
///    不需要先量高度再滚（见下）。
/// 2. **打开历史会话天然停在最新一条**（需求 2）。首帧就落在 0 上，
///    没有任何"等布局完再跳"的时序舞。历史越长这条越关键：实测 1500 条的
///    长会话，正向列表「挂载后跳到最底」要 2.5 秒（中途每一条都要建出来），
///    而反向列表挂载只要 21 毫秒。
/// 3. **「在没在底部」变成一个恒等比较**（`pixels <= minScrollExtent`），
///    而不是"离 maxScrollExtent 还有多远"。
///
/// ⚠️ 代价写在 `_card` 的索引换算里：`ListView` 的 index 0 是**列表末尾**那条。
/// 别按正向来读这段代码。
///
/// 注：`reverse` 只改滚动方向的解释，不改条目的绘制顺序，鼠标滚轮的语义也
/// 已经由 Flutter 自己翻好了（`scrollable.dart` 的 `_pointerSignalEventDelta`），
/// **不需要**自己给滚轮取负。
class ChatTranscript extends ConsumerStatefulWidget {
  const ChatTranscript({super.key});

  @override
  ConsumerState<ChatTranscript> createState() => _ChatTranscriptState();
}

class _ChatTranscriptState extends ConsumerState<ChatTranscript> {
  final _scroll = ScrollController();

  /// 是否跟着最新一条走。用户往回滚就松开，滚回底部或点浮钮再咬合。
  bool _follow = true;

  /// 「回到最新」浮钮是否浮出。真正决定淡入的是 [AnimatedOpacity]。
  bool _showJump = false;

  /// 浮钮浮出前的停顿（见 [ChatBubbleMetrics.scrollDwell]）。
  Timer? _dwell;

  /// 一帧只排一次收尾回调。
  bool _settleScheduled = false;

  /// 每条目一把 GlobalKey —— 「定位到某条」要靠它拿到已建出的那条的 context。
  /// 只有**当前建在树里的**条目才会有 currentContext，见 [_reveal]。
  final _itemKeys = <int, GlobalKey>{};

  bool _revealScheduled = false;

  /// 本次定位已经试了几步。上限见 [_maxRevealSteps]。
  int _revealSteps = 0;

  /// 定位的步数上限。每步都是一次跳转 + 一帧，几千条的会话也在几十步内收敛
  /// （步长按「目标离已建范围多远」自适应），超了说明条目没了/出了岔子，放弃。
  static const _maxRevealSteps = 80;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _dwell?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  bool get _atBottom {
    if (!_scroll.hasClients) return true;
    final p = _scroll.position;
    // 首帧尺寸还没定，此刻「在底部」是唯一说得通的状态（内容还没超出去）。
    if (!p.hasContentDimensions) return true;
    return p.pixels <= p.minScrollExtent;
  }

  /// 用户自己滚了。
  ///
  /// ⚠️ **必须区分「谁滚的」**。程序化的 `jumpTo` 同样会走到这里 —— 少了
  /// [ScrollDirection.idle] 这道判断，自动下滑每钉一次底部都会被当成
  /// "用户在往回滚"，跟随立刻松开，然后**永远不再下滑**。
  void _onScroll() {
    final p = _scroll.position;
    if (p.hasContentDimensions &&
        p.userScrollDirection != ScrollDirection.idle) {
      _follow = p.pixels <= p.minScrollExtent;
    }
    _scheduleSettle();
  }

  /// 条目尺寸变了（流式回答变长、图片加载完、字体接管完成……）。
  ///
  /// 用的是 `ScrollMetricsNotification` 而不是 `ScrollNotification` 的
  /// `extentAfter`：后者只在"滚动事件"里报数，而这里要的恰恰是**没人在滚**
  /// 的时候内容长高了。反向列表下，一次超高的 delta 批处理能把这一帧垫高
  /// 好几屏 —— 那时位置还老老实实停在 0，视口却已经被顶离底部了。
  bool _onMetrics(ScrollMetricsNotification n) {
    // 只认这一层列表。深层（卡片内部的横向滚动、代码块）与我们无关。
    if (n.depth != 0) return false;
    _scheduleSettle();
    return false;
  }

  /// 把这一帧的收尾工作排到 layout 之后。
  ///
  /// ⚠️ **不能就地做**。上面的通知是在 layout 途中派发的，此刻 `setState` /
  /// `jumpTo` 都是违规操作；而且刚长出来的高度要到 layout 完才写进
  /// `maxScrollExtent`，就地跳只会跳到上一帧的旧值上。统一延到帧末，就只有
  /// 一条时序，不用逐个回调去推敲。
  void _scheduleSettle() {
    if (_settleScheduled) return;
    _settleScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _settleScheduled = false;
      if (!mounted) return;
      _settle();
    });
  }

  void _settle() {
    if (_follow && _scroll.hasClients) {
      final p = _scroll.position;
      if (p.hasContentDimensions) _scroll.jumpTo(p.minScrollExtent);
    }
    _syncJumpButton();
  }

  /// 浮钮的显隐。**跟 [_follow] 分开算** —— 跟随是"要不要继续钉住"，
  /// 浮钮是"要不要给出口"，两者在"用户滚回底部"时才同时归位。
  void _syncJumpButton() {
    if (_atBottom) {
      _dwell?.cancel();
      _dwell = null;
      if (_showJump) setState(() => _showJump = false);
      return;
    }
    // 已经在等、或者已经浮出来了就别重排 —— 这里每帧都会被调到，
    // 无条件重建 timer 会让它永远走不完（浮钮就永远不出现）。
    if (_showJump || _dwell != null) return;
    _dwell = Timer(ChatBubbleMetrics.scrollDwell, () {
      _dwell = null;
      // 等的过程中又滚回去了（或者内容缩了）—— 那就别浮出来了。
      if (!mounted || _atBottom) return;
      setState(() => _showJump = true);
    });
  }

  void _scheduleReveal() {
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
    _follow = false;

    final target = _chipContext(_itemKeys[items[idx].id]?.currentContext, focus);
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

    if (++_revealSteps > _maxRevealSteps || !_scroll.hasClients) {
      _finishReveal();
      return;
    }
    final p = _scroll.position;
    if (!p.hasContentDimensions) {
      _scheduleReveal();
      return;
    }

    // 目标在列表里的位置（反向列表：越靠上越大）与当前已建出的范围。
    final targetPos = items.length - 1 - idx;
    var builtMin = items.length, builtMax = -1;
    for (final e in _itemKeys.entries) {
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
    final next = (p.pixels + (older ? step : -step))
        .clamp(p.minScrollExtent, p.maxScrollExtent);
    if (next == p.pixels) {
      // 已经顶到头还没建出来：内容高度还没算全，等下一帧。
      _scheduleReveal();
      return;
    }
    _scroll.jumpTo(next);
    _scheduleReveal();
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
      final text = it.text;
      if (!text.contains('```') && !text.contains('~~~')) continue;
      for (final a
          in ChatArtifact.fromBlocks(MarkdownParser.parse(text), text)) {
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

  void _jumpToLatest() {
    // 先咬合跟随再跳：否则这一次 `jumpTo` 之后又会被下一次内容增长顶开
    // （浮钮点完立刻又冒出来，看着像没生效）。
    _follow = true;
    _dwell?.cancel();
    _dwell = null;
    setState(() => _showJump = false);
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.minScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final ctrl = ref.read(chatControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);

    // ⚠️ **只订阅这一个 bool**，不订整个 state。真正的流式热路径是
    // `itemsRevision` + 各气泡自己的 `revision`，这里多订一个字段会让
    // 每次 parse state 变化都过一遍本 widget 的 build —— `select` 把它缩到
    // "这一个 bool 变了才重建"。
    final thinking =
        ref.watch(chatControllerProvider.select((s) => s.thinking));

    // 有没有 turn 在跑 —— 决定末尾回答的工具行露不露面（见下面 tailComplete）。
    final busy = ref.watch(chatControllerProvider.select((s) => s.busy));

    // 帧末收尾：跟随时钉回底部 + 刷新浮钮。挂在这里而不是各个通知里，
    // 是为了让"结构变化"和"尺寸变化"两条路都汇到同一个出口 —— 见 _settle。
    _scheduleSettle();

    // 从输出物页跳来的定位请求。三个触发点：请求本身（watch，覆盖「页面刚挂载、
    // 请求已在」）、会话内容到齐（下面 itemsRevision 的 builder）、载入态结束。
    if (ref.watch(artifactFocusProvider) != null) _scheduleReveal();
    ref.listen(chatControllerProvider.select((s) => s.openingThread),
        (was, now) {
      if (was == true && now == false) _scheduleReveal();
    });

    return ValueListenableBuilder<int>(
      valueListenable: ctrl.itemsRevision,
      builder: (context, _, _) {
        final items = ctrl.items;
        // 回收已不在列表里的条目的 key（会话切换 / 编辑重发会丢条目）。
        final live = {for (final it in items) it.id};
        _itemKeys.removeWhere((id, _) => !live.contains(id));
        if (ref.read(artifactFocusProvider) != null) _scheduleReveal();
        // 最后一组回答的末尾气泡（当前/最近这轮的 assistant 文本）—— 从后往前
        // 找第一条 assistant TextItem，工具行对它常驻显示。
        int? lastAssistantId;
        // 最后一个**用户**气泡的下标 —— 它之后的条目全都属于本轮回答。
        // 这是「哪一条还在跑」的分界线（见下面的 replyComplete）。
        var lastUserId = -1;
        for (var i = items.length - 1; i >= 0; i--) {
          final it = items[i];
          if (it is TextItem && it.role == ChatRole.user) {
            lastUserId = i;
            break;
          }
        }
        for (var i = items.length - 1; i >= 0; i--) {
          final it = items[i];
          if (it is TextItem && it.role == ChatRole.assistant) {
            lastAssistantId = it.id;
            break;
          }
        }
        return Stack(
          // 撑满：ListView 是唯一未定位的子项，让它吃满整块区域，
          // 否则 Stack 会按内容去量一个滚动列表（量不出来）。
          fit: StackFit.expand,
          children: [
            NotificationListener<ScrollMetricsNotification>(
              onNotification: _onMetrics,
              // ⚠️ **一屏放得下的会话要从版式顶部开始排**
              //
              // 实现是 `shrinkWrap` + 顶对齐这一对：列表在内容不足一屏时把自己的
              // 高度缩到**内容高度**，外层 `Align` 再把它顶到上沿。内容超过一屏时
              // 高度被顶回视口高，`reverse` 照旧把最新一条钉在底部
              //
              // ⚠️ **长会话没有代价，别把它改成 SingleChildScrollView**。约束是
              // **有界的**（`Align` 传下来的是 loose 而非 unbounded：maxHeight 仍是
              // 视口高），`RenderShrinkWrappingViewport.performLayout` 拿
              // `constraints.maxHeight` 当 mainAxisExtent，布局循环填满视口就停，
              // 不会为了量高度把整表建出来 —— 类注释里那条「1500 条 21ms」的账
              // 不受影响。（shrinkWrap 变慢的经典场景是放在 Column 里、主轴约束
              // **无界**，那时才必须遍历全部子项才能算出自身高度。）
              child: Align(
                alignment: Alignment.topCenter,
                child: ListView.builder(
                  controller: _scroll,
                  // ⚠️ 见类注释：翻过来画，index 0 是**列表末尾**那条。
                  reverse: true,
                  shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                        horizontal: WorkspaceMetrics.contentPaddingInline,
                        vertical: WorkspaceMetrics.framePadding),
                  // ⚠️ 思考行是列表的**最后一项**，不是 index 0 的头部 ——
                  // 它跟着"最新一轮"走，而不是钉在会话顶端。反向列表下它是
                  // **index 0**（最底部那条）。
                  //
                  // 代价是 items 每加一条就让它的索引+1，也就是说**它无法被
                  // Element 复用**，每轮对话都会重新 mount（Timer 跟着重建，
                  // 见 ThinkingRow 的 dispose）。换来的是不用在每张卡前面插一刀、
                  // 也不必管它该排在哪条旁边。这一行一轮只出现一次，重建的代价
                  // 可以忽略。
                  itemCount: items.length + (thinking ? 1 : 0),
                  // 条目身份稳定，给 key 让 Flutter 复用 Element，避免整表重建。
                  itemBuilder: (context, i) {
                    if (thinking && i == 0) return const ThinkingRow();
                    // 反向索引换算：i 越大越靠上（越旧）。
                    final at = items.length - 1 - (thinking ? i - 1 : i);
                    final item = items[at];
                    return KeyedSubtree(
                      key: ValueKey<int>(item.id),
                      // 内层 GlobalKey 只服务于「定位到某条」（见 [_reveal]）。
                      child: KeyedSubtree(
                        key: _itemKeys.putIfAbsent(item.id, () => GlobalKey()),
                        child: _card(context, ref, ctrl, l10n, item,
                            isLastAnswer: item.id == lastAssistantId,
                            // 这一条的整轮回答跑完了没有 —— 见
                            // `TextBubble.replyComplete`。
                            //
                            // ⚠️ **不能只看 `item.done`**：那是 `itemCompleted`
                            // 的标记，而一轮回答由**多段**组成（每段一对
                            // started/completed），所以一轮跑到一半时，前面那些段
                            // 各自 done 都已经是 true —— 按 done 判定就会在回答中间插出工具行（正是这次要修的现象）。
                            //
                            // 真正的问题是「这一条属于哪一轮」。分界线是最后一条
                            // **用户**消息：在它之前的都跑完了；在它之后的属于本轮，
                            // 而本轮只要 [busy] 就还没结束。
                            replyComplete: !busy || at <= lastUserId),
                      ),
                    );
                  },
                ),
              ),
            ),
            _jumpButton(l10n),
          ],
        );
      },
    );
  }

  /// 「回到最新」浮钮。
  ///
  /// ⚠️ **常驻在树里，靠 opacity + IgnorePointer 控制**，不做条件挂载。
  /// 条件挂载会让整棵 Stack 在浮钮进出时重建一次布局；而纯粹淡出（不摘）则
  /// 会在对话右下角留一块透明的 [SizedBox] —— 正好压住最后一条回复的结尾，
  Widget _jumpButton(AppLocalizations l10n) => Positioned(
        // 与输入框同轴居中，不贴右边缘。正文列是有上限的
        // （`TranscriptWidth` 的 640/800/960 三档），宽档下屏幕很宽，
        // 贴右下角会在屏幕上孤零零地漂着；居中才和输入框那条轴线对上。
        left: 0,
        right: 0,
        bottom: ChatBubbleMetrics.jumpButtonMarginBottom,
        child: IgnorePointer(
          ignoring: !_showJump,
          child: AnimatedOpacity(
            opacity: _showJump ? 1 : 0,
            duration: ChatBubbleMetrics.jumpButtonFade,
            child: Center(
              child: JumpToLatestButton(
                tooltip: l10n.chatJumpToLatest,
                onPressed: _jumpToLatest,
              ),
            ),
          ),
        ),
      );

  /// 一条 → 一张卡。用 sealed class 的 switch，新增条目类型时编译器会在这里拦住。
  Widget _card(BuildContext context, WidgetRef ref, ChatController ctrl,
          AppLocalizations l10n, ChatItem item,
          {required bool isLastAnswer, required bool replyComplete}) =>
      switch (item) {
        final TextItem t => TextBubble(
            item: t,
            truncatedHint: l10n.chatTextTruncated,
            isLastAnswer: isLastAnswer,
            replyComplete: replyComplete,
            // 品牌头像在这里注入 —— `ui/` 层不许 import `services/`，
            // 所以 TextBubble 只收 ImageProvider，自己去哪取归本层管。
            assistantAvatar: BrandAssets.image(BrandAssets.loginMark),
            onEditSave: t.role == ChatRole.user
                ? (text) => ctrl.editAndResend(t.id, text,
                    model: ref
                        .read(modelListProvider)
                        .effective(ref
                            .read(composerSettingsProvider)
                            .settings
                            .selectedModel)
                        ?.id)
                : null,
          ),
        final ToolItem t => ToolCard(
            item: t,
            runningLabel: l10n.chatToolRunning,
            truncatedLabel: l10n.chatToolTruncated,
            elapsedLabel: switch (t.elapsedMs) {
              final int ms => l10n.chatToolElapsed(ms),
              null => null,
            },
          ),
        final ApprovalItem a => ApprovalCard(
            item: a,
            title: l10n.chatApprovalTitle,
            labels: {
              ApprovalDecision.accept: l10n.chatApprovalAllowOnce,
              ApprovalDecision.acceptForSession: l10n.chatApprovalAllowAlways,
              ApprovalDecision.decline: l10n.chatApprovalDeny,
            },
            resolvedLabel: (wire) => switch (wire) {
              'accept' => l10n.chatApprovalResolvedAllow,
              'acceptForSession' => l10n.chatApprovalResolvedAlways,
              'decline' => l10n.chatApprovalResolvedDeny,
              _ => wire,
            },
            onDecide: (d) => ctrl.respond(a, d),
          ),
        final NoticeItem n => NoticeBar(item: n),
      };
}
