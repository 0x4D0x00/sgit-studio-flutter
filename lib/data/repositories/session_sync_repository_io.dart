import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import 'package:sgit_studio_flutter/core/result/api_exception.dart';
import 'package:sgit_studio_flutter/core/result/auth_failure.dart';
import 'package:sgit_studio_flutter/data/repositories/session_sync_repository.dart';

// ---- C 函数签名（对齐 sgcode-rs/sgit-ffi/src/session_sync.rs）----

typedef _Str0C = Pointer<Utf8> Function();
typedef _Str0Dart = Pointer<Utf8> Function();

typedef _Str1C = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _Str1Dart = Pointer<Utf8> Function(Pointer<Utf8>);

typedef _BoolC = Bool Function();
typedef _BoolDart = bool Function();

typedef _FreeC = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

DynamicLibrary _openNativeLib() {
  if (Platform.isWindows) return DynamicLibrary.open('sgit_ffi.dll');
  if (Platform.isMacOS) return DynamicLibrary.open('libsgit_ffi.dylib');
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('libsgit_ffi.so');
  }
  if (Platform.isIOS) return DynamicLibrary.process();
  throw UnsupportedError('当前平台不支持 sgit_ffi');
}

/// 桌面/移动的会话同步 —— 转发给 `sgit_ffi` 的 `sgit_session_sync*`。
final class IoSessionSyncRepository implements SessionSyncRepository {
  IoSessionSyncRepository();

  /// ⚠️ 只读一次并缓存。
  ///
  /// Rust 那侧本来就是进程内固定的（`OnceLock`），这边每次都跨 FFI 问一遍
  /// 既慢又没有意义 —— 而这个 getter 在每次 turn 结束时都会被问到。
  ///
  /// 读失败按 **false** 处理：取不到开关时不同步，比盲目往服务器推安全
  /// （最坏是"没同步"，而不是"传错地方"）。
  bool? _enabled;

  @override
  bool get enabled => _enabled ??= _readEnabled();

  static bool _readEnabled() {
    try {
      final lib = _openNativeLib();
      return lib.lookupFunction<_BoolC, _BoolDart>('sgit_session_sync_enabled')();
    } catch (_) {
      // 库没加载起来（测试环境、或 DLL 还没同步过去）—— 当作未启用。
      return false;
    }
  }

  /// ⚠️ 必须在后台 isolate 跑。
  ///
  /// 这个调用会**串着做完整轮同步**：列服务器清单 → 逐个文件分块上传/下载。
  /// 一条几 MB 的会话就是好几次加密往返，全程同步阻塞。放在主 isolate 上
  /// 就是几秒到几十秒的界面冻结 —— 而它的触发点是"一轮对话刚结束"，
  /// 那正是用户在读回复的时候。
  @override
  Future<SessionSyncResult> sync() async {
    final raw = await Isolate.run(() {
      final lib = _openNativeLib();
      final out = lib.lookupFunction<_Str0C, _Str0Dart>('sgit_session_sync')();
      if (out == nullptr) throw const ApiException('会话同步返回空');
      try {
        return out.toDartString();
      } finally {
        lib.lookupFunction<_FreeC, _FreeDart>('free_string')(out);
      }
    });
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      throw const ApiException('会话同步响应格式异常');
    }
    // 整体原因（"未登录"/"未启用"/"服务器不可达"）在这个字段里。
    // 鉴权那类要广播出去，否则同步静默失败、用户看不出是掉线还是没开同步。
    AuthFailure.reportIfAuth(decoded['reason']?.toString());
    return SessionSyncResult.fromJson(decoded);
  }

  /// 同样在后台 isolate：它要 `session_list` 一次再按需下载。
  ///
  /// ⚠️ **一律不抛**。它跑在"用户已经看到本地内容之后"，失败只意味着没有
  /// 更新可拿 —— 抛出来会让上层去处理一个不需要用户知道的情况，而最坏的
  /// 处理方式（把已显示的内容换成错误）恰恰是最容易写出来的那种。
  @override
  Future<bool> refreshThread(String threadId) async {
    if (!enabled || threadId.isEmpty) return false;
    try {
      final raw = await Isolate.run(() {
        final lib = _openNativeLib();
        final arg = threadId.toNativeUtf8();
        try {
          final out = lib.lookupFunction<_Str1C, _Str1Dart>(
            'sgit_session_sync_thread',
          )(arg);
          if (out == nullptr) return '';
          try {
            return out.toDartString();
          } finally {
            lib.lookupFunction<_FreeC, _FreeDart>('free_string')(out);
          }
        } finally {
          malloc.free(arg);
        }
      });
      if (raw.isEmpty) return false;
      final decoded = jsonDecode(raw);
      // 「未登录」也走这里（`sgit_session_sync_thread` 原样透传 reason）。
      AuthFailure.reportIfAuth(decoded is Map ? decoded['reason']?.toString() : null);
      return decoded is Map && decoded['changed'] == true;
    } catch (e) {
      // 留痕但不上抛 —— 没有日志的话，"点开的会话总是旧的"无从排查。
      debugPrint('[sessionSync] 单条刷新失败 $threadId：$e');
      return false;
    }
  }
}

SessionSyncRepository createSessionSyncRepository() =>
    IoSessionSyncRepository();
