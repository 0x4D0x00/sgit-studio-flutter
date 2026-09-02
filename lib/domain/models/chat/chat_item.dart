import 'package:flutter/foundation.dart';

/// 会话条目 —— UI 消费的领域模型。
///
/// ⚠️ 这里**没有任何协议字段**。线格式（`KernelFrame`）与协议 DTO 一律留在 data 层，
/// 由 mapper 转成这些类型。内核升协议时只改 mapper，UI 不动。
///
/// ## 为什么条目是可变的（这是本文件唯一值得解释的设计）
///
/// 流式文本如果做成不可变对象 + `copyWith`，每来一个 delta 就要复制整条消息的字符串，
/// 一条 5000 字的回答会产生 O(n²) 的复制量，长回答必卡。
///
/// 所以：条目由控制器独占持有并原地追加，UI 通过 [revision] 这个
/// `ValueListenable` 订阅**单条**变化 —— 一个 delta 只重建一个气泡，不重建列表。
sealed class ChatItem {
  ChatItem({required this.id});

  /// 与内核的 `item_id` 对齐。
  final int id;

  /// 版本号。每次内容变化 +1，UI 用 `ValueListenableBuilder` 订阅它。
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  bool _done = false;
  bool get done => _done;

  void markDone() {
    if (_done) return;
    _done = true;
    revision.value++;
  }

  void dispose() => revision.dispose();
}

enum ChatRole { user, assistant }

/// 文本消息。流式追加。
final class TextItem extends ChatItem {
  TextItem({required super.id, required this.role, String? initial}) {
    if (initial != null) _buf.write(initial);
  }

  final ChatRole role;

  final StringBuffer _buf = StringBuffer();
  String? _cache;

  /// 已累积的全文。`StringBuffer.toString()` 是 O(n)，所以缓存到下次 [append]。
  String get text => _cache ??= _buf.toString();

  bool get isEmpty => _buf.isEmpty;

  /// native 因背压丢过 delta，本条内容不完整。
  bool truncated = false;

  void append(String chunk) {
    if (chunk.isEmpty) return;
    _buf.write(chunk);
    _cache = null;
    revision.value++;
  }
}

/// 工具调用卡片。
final class ToolItem extends ChatItem {
  ToolItem({
    required super.id,
    required this.name,
    required this.argsSummary,
  });

  final String name;
  final String argsSummary;

  String? output;
  int? elapsedMs;

  /// 输出被 native 截断（超 256KB）。完整内容要走冷路径取。
  bool outputTruncated = false;

  /// 工具结束时的状态：`completed` / `failed` / `declined`（用户拒了审批）。
  /// 与 `failed` 分开 —— 界面上该说"已拒绝"而不是"失败"。
  String status = 'completed';

  bool get declined => status == 'declined';
  bool get failed => status == 'failed';

  void complete({
    String? output,
    int? elapsedMs,
    String status = 'completed',
    bool truncated = false,
  }) {
    this.output = output;
    this.elapsedMs = elapsedMs;
    this.status = status;
    outputTruncated = truncated;
    markDone();
  }
}

/// 审批请求卡片。内核在等我们回话，**不回就一直卡着**。
///
/// ⚠️ 内核**不重复带命令内容** —— 审批请求里只有 itemId，命令/补丁全文在之前
/// `item/started` 推过的那条工具 item 上（契约 §2.1.0）。所以这里持有 [target]
/// 指向那张工具卡，界面显示它的入参即可，别自己编一份。
final class ApprovalItem extends ChatItem {
  ApprovalItem({
    required super.id,
    required this.reqId,
    required this.kind,
    required this.reason,
    required this.target,
  });

  final int reqId;

  /// 审批种类：`commandExecution` / `fileChange` / `permissions`。
  final String kind;

  /// 内核给的理由（可能为空 —— 空就别显示，不要编）。
  final String reason;

  /// 被审批的工具卡。`null` 表示没收到对应的 toolBegin（不该发生，但不为此崩）。
  final ToolItem? target;

  /// 显示给用户的"到底要批准什么"。
  String get detail => target?.argsSummary ?? '';

  /// 已回应的决定（`null` = 还在等）。
  String? decision;

  void resolve(String wire) {
    decision = wire;
    markDone();
  }
}

/// 系统提示条：压缩点、模型改道、错误、断线、丢帧。
///
/// ⚠️ **只带类型与数据，不带文案** —— 控制器没有 `BuildContext`，拼不出本地化字符串。
/// 文案在 `ui/components/chat/notice_bar.dart` 里按 [kind] switch 出来。
/// [detail] 是不可本地化的原文（模型名、后端错误消息）。
final class NoticeItem extends ChatItem {
  NoticeItem({
    required super.id,
    required this.kind,
    this.detail = '',
    this.count = 0,
  });

  final NoticeKind kind;
  final String detail;
  final int count;
}

enum NoticeKind { compacted, modelRerouted, error, disconnected, dropped }

/// 会话级故障。同样只带类型，文案归 UI。
sealed class ChatFault {
  const ChatFault();
}

/// 内核帧格式版本与客户端不一致 —— 不降级，提示升级客户端。
final class FrameVersionMismatch extends ChatFault {
  const FrameVersionMismatch({required this.kernel, required this.client});
  final int kernel;
  final int client;
}

/// 还没连上内核就想发消息。给用户一个「重连」的出口，而不是干等。
final class KernelNotConnected extends ChatFault {
  const KernelNotConnected();
}

/// 内核不可用。[message] 是后端原文。
///
/// TODO 后端错误码 → 本地文案映射还没做，这里暂时直显原文。
final class KernelUnavailable extends ChatFault {
  const KernelUnavailable(this.message);
  final String message;
}
