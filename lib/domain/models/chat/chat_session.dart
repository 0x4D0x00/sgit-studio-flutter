import 'package:flutter/foundation.dart';

import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';

/// 一次性的轻提示。**与 [ChatFault] 分开**：fault 是"连接坏了，需要你处理"，
/// notice 是"这次动作没做成，原因如下"，前者常驻故障条、后者一闪即过。
///
/// 同样只带类型不带文案 —— 控制器没有 BuildContext。
enum ChatNotice {
  /// 上一轮还在跑，不能新开一轮。
  busy,

  /// 没有进行中的 turn，插不了话。
  noTurnToSteer,

  /// 发出去后内核长时间没有任何回应，已放开输入。
  stalled,

  /// 中转站没有可用模型（选择器为空），拒绝发送。
  noModel,
}

/// 会话级状态。**不含消息列表** —— 列表走 `ChatController.items` +
/// `itemsRevision`，避免每来一条消息就重建整个 provider 的下游。
@immutable
class ChatSessionState {
  const ChatSessionState({
    this.busy = false,
    this.connecting = false,
    this.openingThread = false,
    this.turnId,
    this.capabilities,
    this.lastTiming,
    this.lastUsage,
    this.fault,
    this.progress,
    this.notice,
  });

  /// 是否有 turn 在跑（决定发送键变停止键）。
  final bool busy;

  /// 正在建连（首屏与重连时显示）。
  final bool connecting;

  /// 正在载入一条历史会话。
  ///
  /// 点开历史会话是**先进页面、内容后到**的（见 `ChatController.openThreadById`）——
  /// 原先要等 `thread/resume` 整条回来才 `context.go`，长会话下就是
  /// **「点了半天进不去 L2 页面」**，而且没有任何反馈，像是没点中。
  ///
  /// 这个标志覆盖那段空窗：界面能显示"正在载入"，输入框能先禁掉
  /// （resume 没落地前 `turn/start` 找不到 thread，发出去必然失败）。
  final bool openingThread;

  final String? turnId;
  final KernelCapabilities? capabilities;

  /// 上一轮的耗时（内核算好的）。
  final TurnTiming? lastTiming;

  /// 最近一次用量。turn 跑动期间也会更新。
  final TokenUsage? lastUsage;

  /// 会话级故障。**只带类型，文案归 UI** —— 控制器没有 BuildContext。
  final ChatFault? fault;

  /// 建连进度。仅 [connecting] 期间有值。
  final KernelConnectProgress? progress;

  /// 一次性轻提示（动作被拒的原因）。
  final ChatNotice? notice;

  ChatSessionState copyWith({
    bool? busy,
    bool? connecting,
    bool? openingThread,
    String? turnId,
    KernelCapabilities? capabilities,
    TurnTiming? lastTiming,
    TokenUsage? lastUsage,
    ChatFault? fault,
    KernelConnectProgress? progress,
    ChatNotice? notice,
    bool clearProgress = false,
    bool clearNotice = false,
  }) =>
      ChatSessionState(
        busy: busy ?? this.busy,
        connecting: connecting ?? this.connecting,
        openingThread: openingThread ?? this.openingThread,
        // ⚠️ turnId 与 fault 刻意**不做 `?? this.x` 回落** —— 不传就等于清空。
        // turn 结束要清 turnId、重连成功要清 fault，回落会让它们粘住。
        turnId: turnId,
        capabilities: capabilities ?? this.capabilities,
        lastTiming: lastTiming ?? this.lastTiming,
        lastUsage: lastUsage ?? this.lastUsage,
        fault: fault,
        progress: clearProgress ? null : (progress ?? this.progress),
        // notice 是一次性的：**默认清掉**，只有显式传才留。粘住的提示比没提示更糟
        // （用户会以为新动作也失败了）。
        notice: clearNotice ? null : notice,
      );
}

/// 一轮的耗时。**内核已经算好，我们只显示，不重算**。
@immutable
class TurnTiming {
  const TurnTiming({
    required this.durationMs,
    required this.llmMs,
    required this.toolMs,
  });

  /// 整轮墙钟耗时。
  final int durationMs;

  /// 其中花在模型采样上的。
  final int llmMs;

  /// 其中花在等工具执行上的。
  final int toolMs;
}

/// token 用量。来自内核的 `thread/tokenUsage/updated`，**turn 跑动期间就会更新**。
@immutable
class TokenUsage {
  const TokenUsage({
    required this.inputTokens,
    required this.cachedInputTokens,
    required this.outputTokens,
    required this.totalTokens,
  });

  final int inputTokens;
  final int cachedInputTokens;
  final int outputTokens;
  final int totalTokens;
}
