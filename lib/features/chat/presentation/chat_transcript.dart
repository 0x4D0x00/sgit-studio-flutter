import 'dart:async';

import 'package:flutter/material.dart';
// `ScrollDirection` 住 rendering 层，material 不转出来。
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

  /// 选区把手。Ctrl+A 的两种走法都要直接调 `SelectableRegion`（见 [_selectAll]）。
  final _selectionKey = GlobalKey<SelectionAreaState>();

  /// 短会话按下 Ctrl+A 时临时为 `true`：把列表的缓存区撑到 [_materializePixels]，
  /// 让**每一条**都建出来并注册进选区，`selectAll()` 才是真的全选。
  ///
  /// ⚠️ 常态必须是 `false`。惰性列表是长会话不卡的前提（类注释里的 1500 条预算），
  /// 只在这一次按键之后、选区消失之前临时付一次代价。
  bool _materializeAll = false;

  /// 撑大缓存区用的像素数。够长就行 —— 视口只会拿它当"视口外还要建多远"。
  ///
  /// ⚠️ 不能给 `double.infinity`：语义树会拿它算一个非有限矩形，
  /// `SemanticsNode` 断言直接抛（渲染层同样会炸）。
  static const _materializePixels = 1e7;

  /// 条目数不超过它就「真全选」（把条目全建出来）；超过就走「复制全文」。
  ///
  /// 200 是实测拐点：debug 下建齐 200 条约 280ms（可接受的一次性停顿），
  /// 500 条已到 580ms，而真实长会话动辄上千条 —— 那不该发生在一次 Ctrl+A 上。
  static const _selectAllLimit = 200;

  /// 长会话按下 Ctrl+A 时留下的**整段会话快照**，随后的 Ctrl+C 直接写它。
  ///
  /// ⚠️ 存文本而不是布尔：存布尔就得在复制那一刻重新拼，中间隔着流式 delta、
  /// 甚至切会话，拼出来的就不一定是用户按下 Ctrl+A 时看到的那段了。
  ///
  /// 用 [String] + thread 快照而不是 `ChatItem` 列表：复制是同步的，
  /// 不能在那一刻去读一个可能已经被替换掉的列表。
  String? _wholeCopyText;

  /// [_wholeCopyText] 属于哪条会话。切了会话就不再认这份快照。
  String? _wholeCopyThreadId;

  /// 快照是否已经「生效」。
  ///
  /// ⚠️ `selectAll()` 会**同步**回调 `onSelectionChanged`，那次是我们自己引起的，
  /// 不能当成"用户改了选区"把快照作废。所以先置 `false`、到帧末再置 `true`：
  /// 之后任何一次选区变化都是用户自己动的，快照随即失效（Ctrl+C 回到正常语义）。
  bool _wholeCopyArmed = false;

  /// 最近一次选区回调是不是"什么都没选"。
  ///
  /// `selectAll()` 先 `clearSelection()` 再建选区，中间会同步报一次空 ——
  /// 那一帧结束时再看这里就能分辨"真的被清空了"还是"正处于全选的中途"。
  bool _selectionEmpty = true;

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
      // 与渲染侧取同一份文本 —— 偏移（sourceStart）必须来自同一串字符。
      final text = it.displayText;
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

  /// Ctrl+A。短会话真全选，长会话「选中可见部分 + 备好全文」。
  ///
  /// 见 [_materializeAll] / [_wholeCopyText] 上的注释。
  void _handleSelectAll() {
    final items = ref.read(chatControllerProvider.notifier).items;

    if (items.length > _selectAllLimit) {
      // ⚠️ 先取证再选。`selectAll()` 会同步回调 `onSelectionChanged`，
      //    而那条路径在选区落空时会清掉快照。
      _wholeCopyText = _conversationText(items);
      _wholeCopyThreadId = ref.read(chatControllerProvider).currentThreadId;
      _wholeCopyArmed = false;
      _selectRegionAll();
      _armWholeCopy();
      return;
    }

    // 长会话降级过来的快照不能留到这次：这条路径走的是真选区。
    _clearWholeCopy();

    if (_materializeAll) {
      _selectRegionAll();
      return;
    }
    // ⚠️ **要两帧。** 第一帧把缓存区撑大、让条目建出来；但新的 `Text` 是
    // 在**这一帧结束之后**才向 `SelectionRegistrar` 注册成 `Selectable` 的
    // （注册发生在 `SelectionContainer` 的帧末回调里）。同一帧里就
    // `selectAll()`，选到的还是上一帧那几条 —— 正是要修的现象。
    setState(() => _materializeAll = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 再排一帧，让注册落地。
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _selectRegionAll();
      });
    });
  }

  /// 快照从下一帧起生效 —— 让 `selectAll()` 自己引起的那次回调先过去。
  void _armWholeCopy() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _wholeCopyArmed = _wholeCopyText != null;
    });
  }

  void _clearWholeCopy() {
    _wholeCopyText = null;
    _wholeCopyThreadId = null;
    _wholeCopyArmed = false;
  }

  /// Ctrl+C。长会话的全选快照优先，其余交给选区自己复制。
  ///
  /// 返回 `true` 表示已处理 —— 调用方（[_CopyIntentAction]）不再往下传。
  bool _handleCopyIntent() {
    final whole = _wholeCopyText;
    if (whole == null ||
        !_wholeCopyArmed ||
        _wholeCopyThreadId !=
            ref.read(chatControllerProvider).currentThreadId) {
      return false;
    }
    // 一次性：Ctrl+A 之后只有紧跟着的那次 Ctrl+C 拿到整段会话。再按一次
    // Ctrl+C 就该回到"复制当前选区"的常规语义，否则用户没法复制自己重新选的部分。
    _clearWholeCopy();
    Clipboard.setData(ClipboardData(text: whole));
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.chatCopiedAll),
        duration: const Duration(seconds: 1),
      ),
    );
    return true;
  }

  void _selectRegionAll() =>
      _selectionKey.currentState?.selectableRegion.selectAll();

  /// 选区变了：撑大的缓存区和整段会话快照都该跟着作废。
  ///
  /// ⚠️ **这里只记账，清理一律延到帧末。** `selectAll()` 的第一件事就是
  /// `clearSelection()`，会先同步报一次"空选区"，紧接着才建立真正的全选。
  /// 如果当场就把 [_materializeAll] 放掉，列表会在同一帧里退回惰性、
  /// 把刚建出来的条目全回收 —— 选区就只剩可见的那几条。
  ///
  /// 所以帧末还要再看一眼 [_selectionEmpty]：这一帧结束时选区已经建好，
  /// 中途那次"空"就不算数。
  void _onSelectionChanged(SelectedContent? content) {
    _selectionEmpty = content == null || content.plainText.isEmpty;
    if (_wholeCopyArmed && _selectionEmpty) _clearWholeCopy();
    if (_materializeAll && _selectionEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 期间又建起了选区（比如我们自己的全选，它先清再选）—— 不撤。
        if (!mounted || !_materializeAll || !_selectionEmpty) return;
        setState(() => _materializeAll = false);
      });
    }
  }

  /// 整段会话的纯文本 —— 用户消息与助手回答按列表顺序用空行隔开。
  ///
  /// 与界面上能选中的内容同一份文本（[TextItem.displayText]）：抬头已被剔除，
  /// 复制出去的不该比看到的更多。工具卡 / 提示条这类**界面外壳**不算正文，
  /// 不进快照。
  static String _conversationText(List<ChatItem> items) {
    final parts = <String>[];
    for (final it in items) {
      if (it is! TextItem) continue;
      final text = it.displayText.trim();
      if (text.isNotEmpty) parts.add(text);
    }
    return parts.join('\n\n');
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
                // ⚠️ **整块会话共用一个 `SelectionArea`**
                //
                // `SelectionArea` 往子树里塞一个 `SelectionRegistrar`，普通
                // [Text] 检测到它就把自己注册成一个 `Selectable`，于是所有
                // 正文段落（以及被 `ListView` 的 `_ScrollableSelectionHandler`
                // 收编的已建出条目）共享一个选区：拖选可以跨块，Ctrl+A 一次
                // 选中整屏，Ctrl+C 一次复制。
                //
                // ⚠️ **选区只认得已注册的 `Selectable`**，而列表是惰性的：滚出
                // 视口的条目连同它的 `Selectable` 一起被回收。所以直接交给默认
                // 实现，Ctrl+A 只会选中当前构建范围 —— 长会话里就是"只选了一半"。
                //
                // 外层 [Actions] 因此把 `SelectAllTextIntent` 接过来按条目数分流
                // （见 [_handleSelectAll]）：短会话临时把缓存区撑大再真全选；
                // 长会话不建那几千条，直接把整段文本备好给随后的 Ctrl+C。
                //
                // 焦点：`SelectableRegion` 自己持有 `FocusNode`，在正文里点
                // 一下才拿到焦点，Ctrl+A 才落到它头上。
                child: Actions(
                  actions: <Type, Action<Intent>>{
                    SelectAllTextIntent: _SelectAllIntentAction(_handleSelectAll),
                    CopySelectionTextIntent:
                        _CopyIntentAction(_handleCopyIntent),
                  },
                  child: SelectionArea(
                    key: _selectionKey,
                    onSelectionChanged: _onSelectionChanged,
                    child: ListView.builder(
                      controller: _scroll,
                      // ⚠️ 见类注释：翻过来画，index 0 是**列表末尾**那条。
                      reverse: true,
                      shrinkWrap: true,
                      // 短会话按下 Ctrl+A 时临时撑大，让全部条目建出来并注册；
                      // 常态为 null，逐条回收照旧 —— 平时一条都不会多建。
                      scrollCacheExtent: _materializeAll
                          ? const ScrollCacheExtent.pixels(_materializePixels)
                          : null,
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
                            key:
                                _itemKeys.putIfAbsent(item.id, () => GlobalKey()),
                            child: _card(context, ref, ctrl, l10n, item,
                                isLastAnswer: item.id == lastAssistantId,
                                // 这一条的整轮回答跑完了没有 —— 见
                                // `TextBubble.replyComplete`。
                                //
                                // ⚠️ **不能只看 `item.done`**：按 done 判定就会
                                // 在回答中间插出工具行
                                //
                                // 真正的问题是「这一条属于哪一轮」。分界线是最后
                                // 一条**用户**消息：在它之前的都跑完了；在它之后
                                // 的属于本轮，而本轮只要 [busy] 就还没结束。
                                replyComplete: !busy || at <= lastUserId),
                          ),
                        );
                      },
                    ),
                  ),
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

/// Ctrl+A 的入口：交给 [onSelectAll] 自己决定怎么全选。
///
/// ⚠️ 必须挂在 `SelectionArea` **外面**。`SelectableRegion` 是用
/// `Action.overridable` 注册 `SelectAllTextIntent` 的，查找方向只往祖先走 ——
/// 放在它里面永远拦不到。外层换掉之后，默认动作只剩 `callingAction` 一条路，
/// 由 [_SelectAllIntentAction] 决定要不要往下传（见 `selectable_region.dart`
/// 的 `_NonOverrideAction.invoke`）。
class _SelectAllIntentAction extends Action<SelectAllTextIntent> {
  _SelectAllIntentAction(this.onSelectAll);

  final VoidCallback onSelectAll;

  @override
  void invoke(SelectAllTextIntent intent) => onSelectAll();
}

/// Ctrl+C 的入口：能自己处理就吞掉，否则回落给选区。
///
/// 回落走 `callingAction`（`Action.overridable` 在调用我们之前塞进来的默认动作），
/// 所以"复制当前选区"这套平台行为一点没变，只有长会话的全选快照走我们的分支。
class _CopyIntentAction extends Action<CopySelectionTextIntent> {
  _CopyIntentAction(this.onCopy);

  /// 返回 `true` 表示已处理，不要再往下传。
  final bool Function() onCopy;

  @override
  void invoke(CopySelectionTextIntent intent) {
    if (onCopy()) return;
    callingAction?.invoke(intent);
  }
}
