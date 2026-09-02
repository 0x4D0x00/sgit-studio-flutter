import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_frame.dart';

/// 帧编解码的 golden 测试。
///
/// ⚠️ 这些断言就是 `docs/KERNEL_FFI.md` §8 的验收项 —— Rust 侧有一份对应的测试，
/// 两边产出的字节必须一致。改帧格式必须同时改：本文件 + 契约文档 + Rust 侧测试。
void main() {
  Uint8List utf8Bytes(String s) => Uint8List.fromList(utf8.encode(s));

  group('帧头布局', () {
    test('空 payload 帧就是 32 字节头', () {
      final f = KernelFrameWriter.encode(
          kind: KernelFrameKind.turnStarted, seq: 1);
      expect(f.lengthInBytes, kKernelFrameHeaderBytes);

      final v = ByteData.sublistView(f);
      expect(v.getUint32(0, Endian.little), 32); // total_len
      expect(v.getUint8(4), 0x01); // kind
      expect(v.getUint8(5), 0); // flags
      expect(v.getUint64(8, Endian.little), 1); // seq
      expect(v.getUint32(24, Endian.little), 0); // payload_len
    });

    test('total_len 恒为 8 的倍数，payload_len 记有效长度', () {
      // 1 字节到 40 字节全试一遍，覆盖每种补齐余数。
      for (var n = 1; n <= 40; n++) {
        final f = KernelFrameWriter.encode(
          kind: KernelFrameKind.itemDelta,
          seq: n,
          payload: Uint8List(n),
        );
        final v = ByteData.sublistView(f);
        expect(f.lengthInBytes % 8, 0, reason: 'payload $n 字节时未 8 对齐');
        expect(v.getUint32(24, Endian.little), n,
            reason: 'payload_len 应为有效长度 $n，不含补齐');
        expect(v.getUint32(0, Endian.little), f.lengthInBytes);
      }
    });
  });

  group('单帧往返', () {
    test('字段与 payload 逐项还原', () {
      final frame = KernelFrameWriter.encode(
        kind: KernelFrameKind.itemDelta,
        seq: 42,
        itemId: 7,
        flags: KernelFrameFlags.truncated | KernelFrameFlags.isFinal,
        payload: utf8Bytes('正在读取仓库'),
      );

      final batch = KernelFrameReader().read(frame, 1);
      expect(batch.frames, hasLength(1));

      final f = batch.frames.single;
      expect(f.kind, KernelFrameKind.itemDelta);
      expect(f.seq, 42);
      expect(f.itemId, 7);
      expect(f.truncated, isTrue);
      expect(f.isFinal, isTrue);
      expect(utf8.decode(f.payload), '正在读取仓库');
    });

    test('payload 是视图而非副本（零拷贝）', () {
      final frame = KernelFrameWriter.encode(
        kind: KernelFrameKind.itemDelta,
        seq: 1,
        payload: utf8Bytes('abcd'),
      );
      final f = KernelFrameReader().read(frame, 1).frames.single;

      // 改底层缓冲，视图应当跟着变 —— 证明没复制。
      frame[kKernelFrameHeaderBytes] = 0x7A; // 'z'
      expect(utf8.decode(f.payload), 'zbcd');
    });
  });

  group('批量读取', () {
    test('混合帧按顺序解出，偏移不错位', () {
      final buf = KernelFrameWriter.batch([
        KernelFrameWriter.encode(kind: KernelFrameKind.turnStarted, seq: 1),
        KernelFrameWriter.encode(
            kind: KernelFrameKind.itemStarted, seq: 2, itemId: 1),
        // 长度刻意选非 8 倍数，逼出补齐 bug
        KernelFrameWriter.encode(
            kind: KernelFrameKind.itemDelta,
            seq: 3,
            itemId: 1,
            payload: utf8Bytes('abc')),
        KernelFrameWriter.encode(
            kind: KernelFrameKind.itemDelta,
            seq: 4,
            itemId: 1,
            payload: utf8Bytes('中文五个字符')),
        KernelFrameWriter.encode(kind: KernelFrameKind.turnCompleted, seq: 5),
      ]);

      final batch = KernelFrameReader().read(buf, 5);
      expect(batch.frames.map((f) => f.kind), [
        KernelFrameKind.turnStarted,
        KernelFrameKind.itemStarted,
        KernelFrameKind.itemDelta,
        KernelFrameKind.itemDelta,
        KernelFrameKind.turnCompleted,
      ]);
      expect(batch.frames.map((f) => f.seq), [1, 2, 3, 4, 5]);
      expect(utf8.decode(batch.frames[2].payload), 'abc');
      expect(utf8.decode(batch.frames[3].payload), '中文五个字符');
      expect(batch.droppedBefore, 0);
    });

    test('未知 kind 被跳过，但后续帧仍能正确解出', () {
      final unknown = KernelFrameWriter.encode(
          kind: KernelFrameKind.itemDelta, seq: 2, payload: utf8Bytes('x'));
      unknown[4] = 0x7F; // 冒充一个未来版本的 kind

      final buf = KernelFrameWriter.batch([
        KernelFrameWriter.encode(kind: KernelFrameKind.turnStarted, seq: 1),
        unknown,
        KernelFrameWriter.encode(kind: KernelFrameKind.turnCompleted, seq: 3),
      ]);

      final batch = KernelFrameReader().read(buf, 3);
      // 静默忽略：只少了那一帧，不报错、不影响别人。
      expect(batch.frames.map((f) => f.kind),
          [KernelFrameKind.turnStarted, KernelFrameKind.turnCompleted]);
      expect(batch.droppedBefore, 0, reason: '未知 kind 不算 native 丢帧');
    });

    test('长度非法时停止解析，不把错误往后扩散', () {
      final bad = KernelFrameWriter.encode(
          kind: KernelFrameKind.itemDelta, seq: 1, payload: utf8Bytes('abc'));
      ByteData.sublistView(bad).setUint32(0, 33, Endian.little); // 非 8 对齐

      final batch = KernelFrameReader().read(bad, 1);
      expect(batch.frames, isEmpty);
    });
  });

  group('背压丢帧检出（契约 §3）', () {
    test('seq 跳跃被算成 native 丢弃的帧数', () {
      final reader = KernelFrameReader();
      reader.read(
          KernelFrameWriter.encode(kind: KernelFrameKind.itemDelta, seq: 1), 1);

      // native 因队列满丢了 seq 2..8，下一帧直接 9。
      final batch = reader.read(
          KernelFrameWriter.encode(kind: KernelFrameKind.itemDelta, seq: 9), 1);
      expect(batch.droppedBefore, 7);
    });

    test('跨 drain 也能检出（reader 记住上次 seq）', () {
      final reader = KernelFrameReader();
      final a = reader.read(
          KernelFrameWriter.encode(kind: KernelFrameKind.itemDelta, seq: 10), 1);
      final b = reader.read(
          KernelFrameWriter.encode(kind: KernelFrameKind.itemDelta, seq: 12), 1);
      expect(a.droppedBefore, 0);
      expect(b.droppedBefore, 1);
    });

    test('重连后不误报丢帧', () {
      final reader = KernelFrameReader();
      reader.read(
          KernelFrameWriter.encode(kind: KernelFrameKind.itemDelta, seq: 5), 1);
      reader.resyncAfterReconnect();
      final batch = reader.read(
          KernelFrameWriter.encode(kind: KernelFrameKind.itemDelta, seq: 900), 1);
      expect(batch.droppedBefore, 0);
    });
  });
}
