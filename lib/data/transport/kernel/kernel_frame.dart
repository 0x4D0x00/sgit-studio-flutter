
/// 内核事件帧 —— 线格式的**唯一**解析处。
///
/// 契约见 `docs/KERNEL_FFI.md` §2，两仓共用。桌面（`asTypedList`）与 Web
/// （`Uint8Array.toDart`）拿到的都是同一份字节，所以本文件两端复用，不做平台分支。
///
/// 设计要点（这是 FFI 方案的性能来源，改之前先读 `docs/KERNEL_FFI.md` §0）：
/// - **零拷贝**：[KernelFrame.payload] 是 native 内存的 `sublistView`，不复制。
/// - **不解析 JSON**：热路径的 `ItemDelta` / `ProcessOutput` payload 是裸 UTF-8，
///   一次 `utf8.decode` 就完；JSON 类 payload 交给上层**按需**解，本层绝不主动解。
/// - **一批一读**：native 一次 drain 给一整批帧，这里顺序切片，不做任何分配。
library;

import 'dart:typed_data';

/// 帧头固定长度。
const int kKernelFrameHeaderBytes = 32;

/// 本客户端支持的帧格式版本。与 `sgit_kernel_caps` 返回的 `frame_version` 必须相等，
/// 不等就拒绝连接 —— 不做跨版本兼容降级。
const int kKernelFrameVersion = 1;

/// 事件类型。**只能追加，不得复用旧值**（见契约 §2.1）。
enum KernelFrameKind {
  hello(0x00),
  turnStarted(0x01),
  turnCompleted(0x02),
  itemStarted(0x03),
  itemDelta(0x04),
  itemCompleted(0x05),
  toolBegin(0x06),
  toolEnd(0x07),
  processOutput(0x08),
  approval(0x09),
  compacted(0x0A),
  modelRerouted(0x0B),
  callResult(0x0C),
  error(0x0D),
  disconnected(0x0E),

  /// 本轮 token 用量。**独立于 [turnCompleted]** —— 内核的
  /// `thread/tokenUsage/updated` 在 turn 跑动期间就会推，不是收尾才有。
  /// 混进 turnCompleted 会让客户端以为 turn 结束了。
  tokenUsage(0x0F);

  const KernelFrameKind(this.wire);

  /// 线上的 u8 取值。
  final int wire;

  /// payload 是裸 UTF-8（而非 JSON）的两类热路径事件。
  bool get isRawText => switch (this) {
        KernelFrameKind.itemDelta || KernelFrameKind.processOutput => true,
        _ => false,
      };

  /// native 在背压时允许丢弃的类型。其余是语义事件，永不丢。
  bool get isDroppable => isRawText;

  /// 未知 kind 返回 null —— 调用方**静默忽略**，不报错（内核可能比我们新）。
  static KernelFrameKind? fromWire(int v) => switch (v) {
        0x00 => KernelFrameKind.hello,
        0x01 => KernelFrameKind.turnStarted,
        0x02 => KernelFrameKind.turnCompleted,
        0x03 => KernelFrameKind.itemStarted,
        0x04 => KernelFrameKind.itemDelta,
        0x05 => KernelFrameKind.itemCompleted,
        0x06 => KernelFrameKind.toolBegin,
        0x07 => KernelFrameKind.toolEnd,
        0x08 => KernelFrameKind.processOutput,
        0x09 => KernelFrameKind.approval,
        0x0A => KernelFrameKind.compacted,
        0x0B => KernelFrameKind.modelRerouted,
        0x0C => KernelFrameKind.callResult,
        0x0D => KernelFrameKind.error,
        0x0E => KernelFrameKind.disconnected,
        0x0F => KernelFrameKind.tokenUsage,
        _ => null,
      };
}

/// 帧 flags 位。
abstract final class KernelFrameFlags {
  /// payload 被 native 截断，完整内容要走冷路径取。
  static const int truncated = 1 << 0;

  /// 该 item 的最后一帧。
  static const int isFinal = 1 << 1;

  /// payload 非 UTF-8（预留，当前恒 0）。
  static const int binary = 1 << 2;
}

/// 单帧。[payload] 是原始缓冲上的视图 —— **只在本次 drain 的生命周期内有效**，
/// 缓冲归还 native 后就是野指针。要留就自己 copy。
final class KernelFrame {
  const KernelFrame({
    required this.kind,
    required this.flags,
    required this.seq,
    required this.itemId,
    required this.payload,
    this.droppedBefore = 0,
  });

  final KernelFrameKind kind;
  final int flags;
  final int seq;

  /// native 在**本帧之前**丢掉的帧数（由 `seq` 跳跃推出）。
  ///
  /// ⚠️ 必须按帧归属，不能只给整批一个总数：一批里可能既有「开一条新消息」又有
  /// 它的 delta，丢帧要算在**当时正在流的那条**身上。给整批算总数会归错人
  /// （早期实现就栽在这里，被 `chat_controller_test.dart` 的丢帧用例抓出来）。
  final int droppedBefore;

  /// 同一 item 的 delta 共享；`callResult` 时等于 req_id；否则 0。
  final int itemId;

  final Uint8List payload;

  bool get truncated => flags & KernelFrameFlags.truncated != 0;
  bool get isFinal => flags & KernelFrameFlags.isFinal != 0;
}

/// 一批帧的解析结果。
final class KernelFrameBatch {
  const KernelFrameBatch({required this.frames, required this.droppedBefore});

  final List<KernelFrame> frames;

  /// 本批总共丢了多少帧（各帧 [KernelFrame.droppedBefore] 之和）。
  ///
  /// ⚠️ 非 0 时**不许假装没发生**：受影响的 item 要走冷路径 `thread/read` 补全，
  /// 或就地打「内容已合并」标记。见契约 §3。
  /// 具体归属哪条消息，看**各帧**的 `droppedBefore`，别用这个总数去归属。
  final int droppedBefore;
}

/// 批量帧读取器。跨 drain 保持 `seq` 连续性，用来检出 native 侧的背压丢弃。
final class KernelFrameReader {
  int? _lastSeq;

  /// 解析一批帧。[buffer] 是 native 给的连续缓冲，[count] 是 `sgit_kernel_drain`
  /// 返回的帧数（用来预分配，避免 List 增长时反复搬家）。
  ///
  /// 遇到未知 kind 直接跳过（内核可能比客户端新）；遇到长度不合法立刻停止解析剩余
  /// 部分 —— 半截缓冲继续猜只会把错误扩散。
  KernelFrameBatch read(Uint8List buffer, int count) {
    final frames = <KernelFrame>[];
    final data = ByteData.sublistView(buffer);
    var dropped = 0;
    var offset = 0;
    // 待归属的丢帧数。跳过未知 kind 时先攒着，挂到下一个真正吐出去的帧上，
    // 免得丢帧信息随着被忽略的帧一起消失。
    var pendingGap = 0;

    while (offset + kKernelFrameHeaderBytes <= buffer.lengthInBytes) {
      final totalLen = data.getUint32(offset, Endian.little);
      // 长度必须容得下帧头、不越界、且 8 对齐（契约 §2 的对齐规则）。
      if (totalLen < kKernelFrameHeaderBytes ||
          totalLen % 8 != 0 ||
          offset + totalLen > buffer.lengthInBytes) {
        break;
      }

      final payloadLen = data.getUint32(offset + 24, Endian.little);
      if (kKernelFrameHeaderBytes + payloadLen > totalLen) break;

      final seq = _getU64(data, offset + 8);
      final lastSeq = _lastSeq;
      if (lastSeq != null && seq > lastSeq + 1) {
        final gap = seq - lastSeq - 1;
        dropped += gap;
        pendingGap += gap;
      }
      _lastSeq = seq;

      final kind = KernelFrameKind.fromWire(data.getUint8(offset + 4));
      if (kind != null) {
        final start = offset + kKernelFrameHeaderBytes;
        frames.add(KernelFrame(
          kind: kind,
          flags: data.getUint8(offset + 5),
          seq: seq,
          itemId: _getU64(data, offset + 16),
          // 零拷贝：视图，不是副本。
          payload: Uint8List.sublistView(buffer, start, start + payloadLen),
          droppedBefore: pendingGap,
        ));
        pendingGap = 0;
      }

      offset += totalLen;
      if (count > 0 && frames.length >= count && offset >= buffer.lengthInBytes) {
        break;
      }
    }

    return KernelFrameBatch(frames: frames, droppedBefore: dropped);
  }

  /// 重连后调用：`seq` 跨重连不重置，但客户端要允许一次跳变而不误报丢帧。
  void resyncAfterReconnect() => _lastSeq = null;
}

/// 帧写入器。**生产路径用不到** —— 帧只由 Rust 侧产出。
/// 这里提供它是为了：① mock 通道能产出真帧，让编解码在开发期就被真实跑通；
/// ② 单测能构造 golden 字节与 Rust 侧对账（契约 §8 的验收项）。
final class KernelFrameWriter {
  static const int _align = 8;

  /// 按契约 §2 编一帧。`payload` 尾部自动补 0 到 8 的整数倍。
  static Uint8List encode({
    required KernelFrameKind kind,
    required int seq,
    int itemId = 0,
    int flags = 0,
    Uint8List? payload,
  }) {
    final body = payload ?? Uint8List(0);
    final padded = _align8(body.lengthInBytes);
    final total = kKernelFrameHeaderBytes + padded;

    final out = Uint8List(total);
    final view = ByteData.sublistView(out);
    view.setUint32(0, total, Endian.little);
    view.setUint8(4, kind.wire);
    view.setUint8(5, flags);
    // 6..8 reserved = 0
    _setU64(view, 8, seq);
    _setU64(view, 16, itemId);
    view.setUint32(24, body.lengthInBytes, Endian.little);
    // 28..32 reserved2 = 0
    out.setRange(kKernelFrameHeaderBytes,
        kKernelFrameHeaderBytes + body.lengthInBytes, body);
    return out;
  }

  /// 把多帧拼成一次 drain 的缓冲。
  static Uint8List batch(List<Uint8List> frames) {
    final total = frames.fold<int>(0, (a, f) => a + f.lengthInBytes);
    final out = Uint8List(total);
    var at = 0;
    for (final f in frames) {
      out.setRange(at, at + f.lengthInBytes, f);
      at += f.lengthInBytes;
    }
    return out;
  }

  static int _align8(int n) => (n + _align - 1) & ~(_align - 1);
}

// ---------------------------------------------------------------------------
// u64 的读写：**必须手工拆成两个 u32**
//
// ⚠️ `ByteData.getUint64` / `setUint64` 在 **dart2js 上直接抛**
// `Unsupported operation: Uint64 accessor not supported by dart2js`
// —— JavaScript 没有 64 位整数类型。
//
// 这个坑极其阴险：`flutter test` 跑在 **Dart VM**（原生，u64 完全正常），
// 所以帧编解码的单测全绿；而 web 上第一帧就炸，整条内核链路一个字都出不来。
// 我们的目标平台恰恰是 web，等于测试完全没覆盖真实运行环境。
//
// 因此帧测试**必须同时跑 `flutter test --platform chrome`**，见
// `test/kernel_frame_test.dart` 顶部说明。
//
// 精度：JS 数字是 double，安全整数上限 2^53-1。seq 与 item_id 都是自增计数，
// 现实中远达不到 9 千万亿，够用；真溢出时高位也已经先失真，这里不额外掩饰。

int _getU64(ByteData d, int offset) {
  final lo = d.getUint32(offset, Endian.little);
  final hi = d.getUint32(offset + 4, Endian.little);
  // 绝大多数帧的高 32 位是 0，走这条快路径避免一次乘法。
  return hi == 0 ? lo : lo + hi * 0x100000000;
}

void _setU64(ByteData d, int offset, int value) {
  d.setUint32(offset, value & 0xFFFFFFFF, Endian.little);
  // `>>> 32` 在 dart2js 上对 double 是安全的（先转 uint32 再移位会丢高位，
  // 所以用除法取高位）。
  d.setUint32(offset + 4, (value ~/ 0x100000000) & 0xFFFFFFFF, Endian.little);
}
