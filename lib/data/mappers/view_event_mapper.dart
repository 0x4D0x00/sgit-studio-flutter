import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';

/// 历史回放事件 → [ChatItem]。
///
/// ## 与帧路的关系
///
/// 实时对话走二进制帧（`KernelFrameMapper` + `ChatController._apply`），回放走
/// 这里的 JSON。**两条路必须产出同样的 `ChatItem`** —— 否则同一条工具卡在
/// "实时看"和"打开历史看"时长得不一样，那种偏差极难发现。
///
/// 为什么回放不走帧：帧是为热路径 delta 设计的（一秒上千个增量），而回放是一次
/// 冷的批量读取；走帧还得给中继协议加上行 op → bump `KERNEL_RELAY_VERSION` →
/// 旧客户端硬不兼容（兼容判断是 `==`）。
///
/// 事件形状由 Rust 的 `sgit_kernel::view::ViewEvent` 定义（`tag = "t"`，
/// 字段 camelCase），产出方是 `view::replay_thread`。
abstract final class ViewEventMapper {
    /// 把一串回放事件转成条目列表。
  ///
  /// [nextId] 用来给条目分配本地 id —— 每调一次递减一个负数。
  ///
  /// ⚠️ 回放条目用**负数 id**，与帧路的 `item_id`（内核给的 u64，非负）天然
  /// 不撞。回放完线程是 idle 的、不会有针对旧 item 的实时帧，所以不需要维护
  /// 一张 native id → 本地 id 的映射表。
  ///
  /// [createdAt] 是这条会话（thread）的创建时间，所有文本条目共用。单条消息
  /// 没有真时间戳（见 [ChatItem.createdAt]），所以落 thread 级时间 —— 粒度粗，
  /// 但是真的、且同一会话里恒定；传 null 则不显示，**不要**在这里补 `now()`。
  static List<ChatItem> toItems(
    List<Map<String, Object?>> events,
    int Function() nextId, {
    DateTime? createdAt,
  }) {
    final out = <ChatItem>[];
    // 同一个 item 的 started/delta/completed 要落到同一个条目上。
    final byItemId = <String, ChatItem>{};

    for (final e in events) {
      final t = (e['t'] ?? '').toString();
      final itemId = (e['itemId'] ?? '').toString();

      switch (t) {
        case 'userMessage':
          out.add(TextItem(
            id: nextId(),
            role: ChatRole.user,
            initial: (e['text'] ?? '').toString(),
            createdAt: createdAt,
          )..markDone());

        case 'textStarted':
          final item = TextItem(
              id: nextId(), role: ChatRole.assistant, createdAt: createdAt);
          byItemId[itemId] = item;
          out.add(item);

        case 'textDelta':
          final item = byItemId[itemId];
          if (item is TextItem) item.append((e['chunk'] ?? '').toString());

        case 'textCompleted':
          final item = byItemId[itemId];
          if (item is TextItem) item.markDone();

        case 'toolBegin':
          final item = ToolItem(
            id: nextId(),
            name: (e['name'] ?? 'tool').toString(),
            argsSummary: (e['args'] ?? '').toString(),
          );
          byItemId[itemId] = item;
          out.add(item);

        case 'toolEnd':
          final item = byItemId[itemId];
          if (item is ToolItem) {
            item.complete(
              output: (e['output'] ?? '').toString(),
              elapsedMs: _int(e['durationMs']),
              status: (e['status'] ?? '').toString(),
              truncated: false,
            );
          }

        case 'compacted':
          out.add(NoticeItem(id: nextId(), kind: NoticeKind.compacted));

        case 'error':
          out.add(NoticeItem(
            id: nextId(),
            kind: NoticeKind.error,
            detail: (e['message'] ?? '').toString(),
          ));

        // ⚠️ turn 级事件（turnStarted / turnCompleted / tokenUsage）**回放里
        // 本来就不该有** —— Rust 的 `replay_thread` 刻意不产它们（投出去会把
        // 界面翻进 busy 态、并把三天前那轮的耗时显示成"本轮耗时"）。
        // 真收到了说明上游改了行为，忽略但不假装没发生。
        default:
          break;
      }
    }
    return out;
  }

  static int? _int(Object? v) => switch (v) {
        final int n => n,
        final double d => d.toInt(),
        final String s => int.tryParse(s),
        _ => null,
      };
}
