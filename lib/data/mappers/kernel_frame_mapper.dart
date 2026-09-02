import 'dart:convert';

import 'package:sgit_studio_flutter/data/transport/kernel/kernel_frame.dart';

/// 帧 → 上层可用值的映射。**协议细节到此为止，不再往上传。**
///
/// 关键约束：热路径（`itemDelta` / `processOutput`）**只做一次 UTF-8 解码，绝不 jsonDecode**。
/// JSON 类 payload 由调用方按需解 —— 很多帧上层其实只看 kind，解了就是白花 CPU。
abstract final class KernelFrameMapper {
  /// 裸 UTF-8 payload → 文本。热路径唯一的解码点。
  static String text(KernelFrame f) =>
      f.payload.isEmpty ? '' : utf8.decode(f.payload, allowMalformed: true);

  /// JSON payload → Map。坏 JSON 不抛异常（内核抖一下不该让界面炸），返回空 Map。
  static Map<String, Object?> json(KernelFrame f) {
    if (f.payload.isEmpty) return const {};
    try {
      final v = jsonDecode(utf8.decode(f.payload, allowMalformed: true));
      return v is Map<String, Object?> ? v : const {};
    } on FormatException {
      return const {};
    }
  }

  static String str(Map<String, Object?> j, String key, [String fallback = '']) =>
      j[key]?.toString() ?? fallback;

  static int? intOrNull(Map<String, Object?> j, String key) =>
      switch (j[key]) { final num n => n.toInt(), _ => null };
}
