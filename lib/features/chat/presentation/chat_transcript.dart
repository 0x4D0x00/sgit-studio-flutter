import 'dart:async';

import 'package:flutter/material.dart';
// `ScrollDirection` 住 rendering 层，material 不转出来。
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/design/tokens/bubble_metrics.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/model_list_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/services/brand/brand_assets.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/approval_card.dart';
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

    // 帧末收尾：跟随时钉回底部 + 刷新浮钮。挂在这里而不是各个通知里，
    // 是为了让"结构变化"和"尺寸变化"两条路都汇到同一个出口 —— 见 _settle。
    _scheduleSettle();

    return ValueListenableBuilder<int>(
      valueListenable: ctrl.itemsRevision,
      builder: (context, _, _) {
        final items = ctrl.items;
        // 最后一组回答的末尾气泡（当前/最近这轮的 assistant 文本）—— 从后往前
        // 找第一条 assistant TextItem，工具行对它常驻显示。
        int? lastAssistantId;
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
                    final item =
                        items[items.length - 1 - (thinking ? i - 1 : i)];
                    return KeyedSubtree(
                      key: ValueKey<int>(item.id),
                      child: _card(context, ref, ctrl, l10n, item,
                          isLastAnswer: item.id == lastAssistantId),
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
  /// 那是悬停操作和文本选择最常发生的地方。`IgnorePointer` 两头都躲开了：
  /// 布局稳定，且看不见时一点都不吃点击。
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
          {required bool isLastAnswer}) =>
      switch (item) {
        final TextItem t => TextBubble(
            item: t,
            truncatedHint: l10n.chatTextTruncated,
            isLastAnswer: isLastAnswer,
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
