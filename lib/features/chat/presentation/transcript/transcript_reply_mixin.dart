import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/features/chat/application/composer_focus_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_quotes_controller.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/transcript/transcript_widgets.dart';

/// 选中文字 →「回复」浮钮：摆位、延时、点击后把选中文字塞进输入框的引用。
///
/// 从 `ChatTranscript` 的 State 里整段搬出，逻辑未改。
mixin TranscriptReplyMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  /// 对话流里的选区把手（用来读锚点、清选区）。
  GlobalKey<SelectionAreaState> get selectionKey;

  void disposeReply() => _replyTimer?.cancel();

  // ---- 选中文字 → 「回复」浮钮 ----

  final stackKey = GlobalKey();

  /// 选区稳定后才浮出浮钮的计时（拖选过程中不闪）。
  Timer? _replyTimer;

  /// 当前选中的文字。点浮钮时用它，**不去重新读选区** —— 点击可能已让选区失焦。
  String? _replyText;

  /// 浮钮左上角，相对 [stackKey] 那层 Stack。null = 不显示。
  Offset? replyPos;

  static const _replyDelay = Duration(milliseconds: 150);

  void scheduleReply(String? text) {
    _replyTimer?.cancel();
    _replyText = text;
    if (text == null) {
      // 选区回调可能落在 layout 途中，不能就地 setState。
      if (replyPos != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _replyText == null) setState(() => replyPos = null);
        });
      }
      return;
    }
    _replyTimer = Timer(_replyDelay, _placeReply);
  }

  void _placeReply() {
    if (!mounted || _replyText == null) return;
    final stack = stackKey.currentContext?.findRenderObject() as RenderBox?;
    final region = selectionKey.currentState?.selectableRegion;
    if (stack == null || !stack.hasSize || region == null) return;
    final Offset anchor;
    try {
      anchor = stack.globalToLocal(region.contextMenuAnchors.primaryAnchor);
    } catch (_) {
      return; // 选区端点此刻不可用（刚被回收 / 清空），等下一次变化。
    }
    final size = stack.size;
    // 默认放在选区上沿之上；上面没位置就压到下面。
    var top = anchor.dy - TranscriptReplyButton.size.height - 8;
    if (top < 0) top = anchor.dy + 24;
    final left = (anchor.dx - TranscriptReplyButton.size.width / 2).clamp(
      0.0,
      (size.width - TranscriptReplyButton.size.width).clamp(0.0, size.width),
    );
    top = top.clamp(
      0.0,
      (size.height - TranscriptReplyButton.size.height).clamp(0.0, size.height),
    );
    setState(() => replyPos = Offset(left.toDouble(), top));
  }

  void submitReply() {
    final text = _replyText;
    if (text != null) ref.read(composerQuotesProvider.notifier).add(text);
    _replyTimer?.cancel();
    _replyText = null;
    setState(() => replyPos = null);
    selectionKey.currentState?.selectableRegion.clearSelection();
    ref.read(composerFocusProvider.notifier).requestFocus();
  }
}
