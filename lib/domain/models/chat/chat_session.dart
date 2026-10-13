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
    this.thinking = false,
    this.connecting = false,
    this.openingThread = false,
    this.turnId,
    this.capabilities,
    this.lastTiming,
    this.lastUsage,
    this.fault,
    this.progress,
    this.notice,
    this.currentThreadId,
  });

  /// 是否有 turn 在跑（决定发送键变停止键）。
  final bool busy;

  /// 是否处于「已发出、还没吐出任何东西」的思考窗口。
  ///
  /// ## 为什么这是客户端状态、而不是内核事件
  ///
  /// 内核协议里**没有** reasoning / thinking 帧（[KernelFrameKind] 到
  /// `tokenUsage` 为止）。所以这一行不是"把内核的想法渲染出来"，而是
  /// **进度指示**：从发出到模型真开始吐字之间那段静默，用户看到的和"卡住了"
  /// 完全一样。Claude 自己的思考状态行也是同一回事 —— 由客户端把等待讲出来。
  ///
  /// 因此**不臆造思考内容**。将来内核真推 reasoning 帧了，那是另一条条目类型
  /// （`ChatItem`），不是把这个布尔改成字符串。
  ///
  /// 起止由 [ChatController] 管：`send()` / `editAndResend()` 置真，本轮
  /// **首个内容落地**（`itemStarted` / `toolBegin`）置假。它必须与 [busy]
  /// 一起被清 —— 见 [copyWith] 里 binding 的说明。
  final bool thinking;

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

  /// 当前接在哪条历史会话上；新对话（还没存过）时为 null。
  /// 只用来给左栏历史列表点亮"当前打开的是哪一条"——不影响任何内核交互，
  /// 那部分仍由 [ChatController] 内部的 `_client.setThread` 管。
  final String? currentThreadId;

  ChatSessionState copyWith({
    bool? busy,
    bool? thinking,
    bool? connecting,
    bool? openingThread,
    String? turnId,
    KernelCapabilities? capabilities,
    TurnTiming? lastTiming,
    TokenUsage? lastUsage,
    ChatFault? fault,
    KernelConnectProgress? progress,
    ChatNotice? notice,
    String? currentThreadId,
    bool clearProgress = false,
    bool clearNotice = false,
  }) =>
      ChatSessionState(
        busy: busy ?? this.busy,
        // ⚠️ thinking **是 busy 的下位状态**，两个必须同时为真才成立：
        // 没有 turn 在跑却还在"思考"是自相矛盾的画面（停止键没了、思考行还在
        // 转），所以任何把 busy 置假的路径都顺手把 thinking 一起带下去。
        //
        // 反过来故意**不做**（busy=真 就自动 thinking=真）：思考窗口的结束
        // 由"首个内容落地"决定，与 busy 无关 —— turn 跑动期间两态来回切是常态。
        thinking: (busy ?? this.busy) && (thinking ?? this.thinking),
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
        currentThreadId: currentThreadId ?? this.currentThreadId,
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
