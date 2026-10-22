import 'package:flutter/foundation.dart';

import 'package:sgit_studio_flutter/domain/models/chat/message_quotes.dart';

/// 一条会话（sgcode 的 thread）在列表里的摘要。
///
/// ## 时间字段：在这一层一次性转成 `DateTime`
///
/// ⚠️ sgcode 给的是 **Unix 秒的整数**（`Thread.createdAt` / `updatedAt`，
/// 见 `app-server-protocol/.../thread_data.rs`），不是 ISO 字符串。
///
/// 而历史列表原先排序用的是 `DateTime.parse(item.extra('updatedAt'))` ——
/// 喂给它一个整数会**抛异常**，被 catch 成 epoch 0，于是：
///
/// ```text
/// 所有会话都落进"更早"分组 → 排序完全乱掉 → 而且一行日志都没有
/// ```
///
/// 所以边界就设在这里：JSON 一进来就转成强类型 `DateTime`，上层拿不到
/// 字符串形态的时间，也就没法再犯。
@immutable
class ThreadSummary {
  const ThreadSummary({
    required this.id,
    required this.title,
    required this.preview,
    required this.createdAt,
    required this.updatedAt,
    this.cwd = '',
  });

  /// sgcode 的 thread id（UUIDv7）。
  final String id;

  /// 展示标题。Rust 侧 `thread_ops::display_title` 已经算好回落
  /// （用户改的名字 > 首条消息摘要 > "新对话"），这里不再自己回落 ——
  /// 两边各算一套必然漂。
  final String title;

  /// 首条用户消息的摘要，给列表副标题用。
  final String preview;

  /// ⚠️ 可能为 null：内核偶有缺时间戳的旧会话。**不要用 epoch 0 顶替** ——
  /// 那会让它们排在"最早"，看着像真的很老，而实际是数据缺失。
  /// 排序时把 null 排到末尾并保持稳定即可。
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 会话的工作目录。云端来的已被 gateway 改写过（容器内路径不外泄）。
  final String cwd;

  /// 从 FFI / gateway 的 JSON 解出来。两条路形状一致（Rust 侧同一个 `brief()`）。
  static ThreadSummary fromJson(Map<String, Object?> j) => ThreadSummary(
        id: (j['id'] ?? '').toString(),
        title: _oneLine((j['title'] ?? '').toString()),
        preview: _oneLine((j['preview'] ?? '').toString()),
        createdAt: _fromUnixSeconds(j['createdAt']),
        updatedAt: _fromUnixSeconds(j['updatedAt']),
        cwd: (j['cwd'] ?? '').toString(),
      );

  /// 标题 / 摘要压成单行文本。
  ///
  /// 首条消息带引用时，Rust 侧摘要是原文 `<quote>\n…\n</quote>\n\n正文`。
  /// 去掉开头的引用块（只剩引用时退回引用文字），再把空白折叠成一个空格。
  static String _oneLine(String raw) {
    final split = MessageQuotes.split(raw);
    var text = split.body.trim();
    if (text.isEmpty && split.quotes.isNotEmpty) text = split.quotes.first;
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Unix **秒** → `DateTime`。
  ///
  /// 只接受数字（含字符串形态的数字，某些 JSON 编码器会那么给）。
  /// ⚠️ 拿不到就返回 **null，不是 epoch 0** —— 见 [createdAt] 的注释：
  /// 用 epoch 0 顶替会把"数据缺失"伪装成"很老的会话"。
  static DateTime? _fromUnixSeconds(Object? v) {
    final secs = switch (v) {
      final int n => n,
      final double d => d.toInt(),
      final String s => int.tryParse(s.trim()),
      _ => null,
    };
    if (secs == null || secs <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(secs * 1000);
  }

  @override
  bool operator ==(Object other) =>
      other is ThreadSummary &&
      other.id == id &&
      other.title == title &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, title, updatedAt);

  @override
  String toString() => 'ThreadSummary($id, $title)';
}

/// 打开一条会话的结果：摘要 + 回放事件。
///
/// `events` 是 Rust 侧 `view::replay_thread` 产出的 `ViewEvent` JSON 序列，
/// **与实时帧解出来的是同一套语义** —— 客户端只有一套渲染逻辑。
@immutable
class ThreadReplay {
  const ThreadReplay({required this.summary, required this.events});

  final ThreadSummary summary;

  /// 按序 apply 即可重建气泡。里面**没有** turn 级事件（turnStarted /
  /// turnCompleted / tokenUsage）—— 回放是装配历史，不是"刚跑完一轮"，
  /// 投那些会把界面翻进 busy 态、并显示三天前那轮的耗时。
  final List<Map<String, Object?>> events;

  static ThreadReplay fromJson(Map<String, Object?> j) => ThreadReplay(
        summary: ThreadSummary.fromJson(
            (j['thread'] as Map?)?.cast<String, Object?>() ?? const {}),
        events: ((j['events'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => e.cast<String, Object?>())
            .toList(growable: false),
      );
}

/// 一页会话列表。
@immutable
class ThreadPage {
  const ThreadPage({required this.threads, this.nextCursor});

  final List<ThreadSummary> threads;
  final String? nextCursor;

  static ThreadPage fromJson(Map<String, Object?> j) => ThreadPage(
        threads: ((j['threads'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ThreadSummary.fromJson(e.cast<String, Object?>()))
            .toList(growable: false),
        nextCursor: (j['nextCursor'] as String?)?.trim().isEmpty ?? true
            ? null
            : j['nextCursor'] as String?,
      );
}
