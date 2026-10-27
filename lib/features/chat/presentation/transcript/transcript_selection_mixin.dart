import 'package:flutter/material.dart';
// `SelectedContent` 住 rendering 层，material 不转出来。
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/features/chat/application/transcript_selection_pin.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';

/// 对话流的选区：Ctrl+A 全选 / Ctrl+C 复制整段会话 / 选区钉住。
///
/// 从 `ChatTranscript` 的 State 里整段搬出，逻辑未改。宿主在 `initState` /
/// `dispose` 里调 [initSelection] / [disposeSelection]，并把 [selectionKey] /
/// [selectionFocus] 挂到 `SelectionArea` 上、[materializeAll] 用于撑大列表缓存区。
mixin TranscriptSelectionMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// 选区文字变了（null = 没有选中）。宿主据此摆「回复」浮钮。
  void onSelectionText(String? text);

  void initSelection() {
    transcriptSelectionPin.node = selectionFocus;
    transcriptSelectionPin.addListener(_onPinChanged);
  }

  void disposeSelection() {
    transcriptSelectionPin.removeListener(_onPinChanged);
    if (transcriptSelectionPin.node == selectionFocus) {
      transcriptSelectionPin.value = false;
      transcriptSelectionPin.node = null;
    }
    selectionFocus.dispose();
  }

  /// 选区把手。Ctrl+A 的两种走法都要直接调 `SelectableRegion`（见 [_selectAll]）。
  final selectionKey = GlobalKey<SelectionAreaState>();
  final selectionFocus = PinnableFocusNode(
    transcriptSelectionPin,
    debugLabel: 'transcriptSelection',
  );

  /// 放开钉住时正文已不在焦点上 —— 补上被压住的那次「失焦清选区」。
  void _onPinChanged() {
    if (transcriptSelectionPin.value || selectionFocus.hasFocus) return;
    selectionKey.currentState?.selectableRegion.clearSelection();
  }

  /// 短会话按下 Ctrl+A 时临时为 `true`：把列表的缓存区撑到 [materializePixels]，
  /// 让**每一条**都建出来并注册进选区，`selectAll()` 才是真的全选。
  ///
  /// ⚠️ 常态必须是 `false`。惰性列表是长会话不卡的前提（类注释里的 1500 条预算），
  /// 只在这一次按键之后、选区消失之前临时付一次代价。
  bool materializeAll = false;

  /// 撑大缓存区用的像素数。够长就行 —— 视口只会拿它当"视口外还要建多远"。
  ///
  /// ⚠️ 不能给 `double.infinity`：语义树会拿它算一个非有限矩形，
  /// `SemanticsNode` 断言直接抛（渲染层同样会炸）。
  static const materializePixels = 1e7;

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

  /// Ctrl+A。短会话真全选，长会话「选中可见部分 + 备好全文」。
  ///
  /// 见 [materializeAll] / [_wholeCopyText] 上的注释。
  void handleSelectAll() {
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

    if (materializeAll) {
      _selectRegionAll();
      return;
    }
    // ⚠️ **要两帧。** 第一帧把缓存区撑大、让条目建出来；但新的 `Text` 是
    // 在**这一帧结束之后**才向 `SelectionRegistrar` 注册成 `Selectable` 的
    // （注册发生在 `SelectionContainer` 的帧末回调里）。同一帧里就
    // `selectAll()`，选到的还是上一帧那几条 —— 正是要修的现象。
    setState(() => materializeAll = true);
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
  bool handleCopyIntent() {
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
      selectionKey.currentState?.selectableRegion.selectAll();

  /// 选区变了：撑大的缓存区和整段会话快照都该跟着作废。
  ///
  /// ⚠️ **这里只记账，清理一律延到帧末。** `selectAll()` 的第一件事就是
  /// `clearSelection()`，会先同步报一次"空选区"，紧接着才建立真正的全选。
  /// 如果当场就把 [materializeAll] 放掉，列表会在同一帧里退回惰性、
  /// 把刚建出来的条目全回收 —— 选区就只剩可见的那几条。
  ///
  /// 所以帧末还要再看一眼 [_selectionEmpty]：这一帧结束时选区已经建好，
  /// 中途那次"空"就不算数。
  void onSelectionChanged(SelectedContent? content) {
    _selectionEmpty = content == null || content.plainText.isEmpty;
    onSelectionText(_selectionEmpty ? null : content!.plainText);
    if (_wholeCopyArmed && _selectionEmpty) _clearWholeCopy();
    if (materializeAll && _selectionEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 期间又建起了选区（比如我们自己的全选，它先清再选）—— 不撤。
        if (!mounted || !materializeAll || !_selectionEmpty) return;
        setState(() => materializeAll = false);
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
}
