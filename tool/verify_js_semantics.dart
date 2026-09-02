// 用 **dart2js** 编译并在 node 里跑的验证。
//
// ## 为什么必须有这一步
//
// `flutter test` 跑在 **Dart VM**（原生），而我们的目标平台是 **web（dart2js）**。
// 两者在数值语义上并不等价，最痛的一条：
//
//   ByteData.getUint64 / setUint64 在 dart2js 上**直接抛**
//   `Unsupported operation: Uint64 accessor not supported by dart2js`
//
// 帧头里有两个 u64（seq / item_id），所以帧解码器**在 web 上从来就没跑通过** ——
// 而 VM 上的单测全绿。真实后果：内核链路一个字都出不来，且没有任何一条测试会红。
//
// 这个文件用 `dart compile js` 编出与 Flutter web 同一套后端（dart2js）的产物，
// 再用 node 执行，把这类"只在 JS 上出现"的问题挡在部署之前。
//
// 跑法（`tool/verify-js.sh` 会自动做）：
//   dart compile js -o /tmp/vjs.js tool/verify_js_semantics.dart && node /tmp/vjs.js
//
// 退出码非 0 即失败。

import 'dart:convert';
import 'dart:typed_data';

import 'package:sgit_studio_flutter/data/transport/kernel/kernel_frame.dart';

int _failures = 0;

void check(String what, bool ok, [String detail = '']) {
  if (ok) {
    print('  ✓ $what');
  } else {
    _failures++;
    print('  ✗ $what ${detail.isEmpty ? '' : '—— $detail'}');
  }
}

void main() {
  print('dart2js 语义验证（node 执行）');

  // ---- 1) 帧编解码往返。这是当初炸掉的那条路。----
  print('帧编解码：');
  final buf = KernelFrameWriter.encode(
    kind: KernelFrameKind.itemDelta,
    seq: 7,
    itemId: 42,
    flags: 0,
    payload: Uint8List.fromList(utf8.encode('你好，世界')),
  );
  final batch = KernelFrameReader().read(buf, 1);
  check('能解出 1 帧', batch.frames.length == 1, '实际 ${batch.frames.length}');
  if (batch.frames.isNotEmpty) {
    final f = batch.frames.first;
    check('kind 正确', f.kind == KernelFrameKind.itemDelta);
    check('itemId 正确', f.itemId == 42, '实际 ${f.itemId}');
    check('载荷正确', utf8.decode(f.payload) == '你好，世界');
  }

  // ---- 2) u64 字段的边界。手写的 u32 对拼要能撑住大值。----
  print('u64 字段（dart2js 无 64 位整数，靠两个 u32 拼）：');
  for (final v in [0, 1, 0xFFFFFFFF, 0x100000000, 0x1FFFFFFFFFFFFF]) {
    final b = KernelFrameWriter.encode(
      kind: KernelFrameKind.hello,
      seq: v,
      itemId: v,
      flags: 0,
      payload: null,
    );
    final r = KernelFrameReader().read(b, 1);
    final got = r.frames.isEmpty ? -1 : r.frames.first.itemId;
    check('itemId=0x${v.toRadixString(16)} 往返一致', got == v, '实际 $got');
  }

  // ---- 3) 多帧连读 + 对齐。align8 算错会整批错位。----
  print('多帧连读（align8）：');
  final parts = <Uint8List>[];
  for (var i = 1; i <= 5; i++) {
    parts.add(KernelFrameWriter.encode(
      kind: KernelFrameKind.itemDelta,
      seq: i,
      itemId: 1,
      flags: 0,
      // 长度刻意不是 8 的倍数，逼出对齐问题。
      payload: Uint8List.fromList(utf8.encode('x' * i)),
    ));
  }
  final multi = KernelFrameReader().read(KernelFrameWriter.batch(parts), 5);
  check('5 帧全部解出', multi.frames.length == 5, '实际 ${multi.frames.length}');
  check(
    '各帧载荷长度递增 1..5',
    multi.frames.length == 5 &&
        List.generate(5, (i) => multi.frames[i].payload.length)
            .join(',') ==
            '1,2,3,4,5',
  );

  print(_failures == 0 ? '\n全部通过' : '\n$_failures 项失败');
  if (_failures > 0) {
    // 非 0 退出码 —— CI / 部署脚本据此拦下。
    throw Exception('dart2js 语义验证失败：$_failures 项');
  }
}
