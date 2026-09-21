import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'package:sgit_studio_flutter/core/result/api_exception.dart';
import 'package:sgit_studio_flutter/data/repositories/thread_repository.dart';
import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';

// ---- C 函数签名（对齐 sgcode-rs/sgit-ffi/src/thread.rs）----

typedef _Str1C = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _Str1Dart = Pointer<Utf8> Function(Pointer<Utf8>);

typedef _Str2C = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _Str2Dart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef _FreeC = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

/// 在后台 isolate 里跑一次 FFI 调用。
///
/// ## 为什么必须换 isolate
///
/// FFI 是**同步**的：进去之后直到 Rust 返回，这个 isolate 什么都做不了。主
/// isolate 就是 UI 线程，而这里每个调用都不便宜：
///
/// ```text
/// 列会话   → thread/list 扫 sessions/ 下的 rollout JSONL（可能上百个文件）
/// 打开会话 → thread/resume 读整条会话的历史（长会话几 MB）
/// ```
///
/// 把方法标 `async` **不解决问题** —— async 函数体在遇到第一个 `await` 之前
/// 是同步执行的，而这里没有 await 可言。`settings_repository_io.dart` 的
/// `_ffiCall` 注释记着同一个坑（"说好的先读本地秒回，实际每页第一次进去都卡"）。
///
/// ⚠️ 闭包里**不能捕获**主 isolate 的对象（`DynamicLibrary` 句柄、函数指针都
/// 不可跨 isolate 传递），所以在 isolate 内部重新 open + lookup。重复 open 同一
/// 个库由操作系统按引用计数处理，不会真加载两遍。
///
/// Rust 那侧的连接、tokio 运行时都是**进程级**静态，跨 isolate 共享 ——
/// 后台 isolate 看到的是同一个已建立的内核连接。
Future<String> _ffiCall(String symbol, List<String> args) => Isolate.run(() {
      final lib = _openNativeLib();
      final ptrs = args.map((s) => s.toNativeUtf8()).toList(growable: false);
      try {
        final out = switch (ptrs.length) {
          1 => lib.lookupFunction<_Str1C, _Str1Dart>(symbol)(ptrs[0]),
          2 => lib.lookupFunction<_Str2C, _Str2Dart>(symbol)(ptrs[0], ptrs[1]),
          _ => throw ArgumentError('不支持 ${ptrs.length} 个参数'),
        };
        if (out == nullptr) throw const ApiException('会话接口返回空');
        try {
          return out.toDartString();
        } finally {
          lib.lookupFunction<_FreeC, _FreeDart>('free_string')(out);
        }
      } finally {
        for (final p in ptrs) {
          malloc.free(p);
        }
      }
    });

DynamicLibrary _openNativeLib() {
  if (Platform.isWindows) return DynamicLibrary.open('sgit_ffi.dll');
  if (Platform.isMacOS) return DynamicLibrary.open('libsgit_ffi.dylib');
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('libsgit_ffi.so');
  }
  // iOS 静态链接进 Runner，符号在主可执行文件里。
  if (Platform.isIOS) return DynamicLibrary.process();
  throw UnsupportedError('当前平台不支持 sgit_ffi');
}

/// 解业务信封 `{status, data}` / `{status:fail, message}`。
///
/// ⚠️ 失败一律抛 [ApiException]，**不回空数据** —— "本地引擎未就绪"和
/// "你没有任何会话"对用户是两回事，后者会让人以为历史丢了。
Map<String, Object?> _unwrap(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, Object?>) {
    throw const ApiException('会话接口响应格式异常');
  }
  final status = decoded['status'];
  if (status == 'fail' || status == 'error') {
    throw ApiException(decoded['message']?.toString() ?? '会话操作失败');
  }
  final data = decoded['data'];
  return data is Map ? data.cast<String, Object?>() : decoded;
}

/// 桌面/移动的会话仓储 —— 转发给 `sgit_ffi` 的 `sgit_thread_*`。
///
/// ## 这里只有转发
///
/// 本地/云端的分发在 **Rust 侧**（`thread.rs` 按 `get_mode()` 判断），
/// 编排在 `sgit_services::thread_ops`（gateway 用的是同一份）。Dart 不该知道
/// 这两条路的存在 —— 那两个漏一个就会让会话静默消失的过滤参数也就不可能
/// 在这里被漏掉。
final class IoThreadRepository implements ThreadRepository {
  const IoThreadRepository();

  @override
  Future<ThreadPage> list({String? cursor}) async =>
      ThreadPage.fromJson(_unwrap(await _ffiCall('sgit_thread_list', [cursor ?? ''])));

  @override
  Future<ThreadReplay> open(String threadId) async =>
      ThreadReplay.fromJson(_unwrap(await _ffiCall('sgit_thread_open', [threadId])));

  @override
  Future<void> rename(String threadId, String name) async {
    _unwrap(await _ffiCall('sgit_thread_rename', [threadId, name]));
  }

  @override
  Future<void> delete(String threadId) async {
    _unwrap(await _ffiCall('sgit_thread_delete', [threadId]));
  }
}

ThreadRepository createThreadRepository() => const IoThreadRepository();
