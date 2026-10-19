import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'package:sgit_studio_flutter/core/result/api_exception.dart';
import 'package:sgit_studio_flutter/core/result/auth_failure.dart';
import 'package:sgit_studio_flutter/data/repositories/settings_repository.dart';

// ---- C 函数签名（对齐 sgcode-rs/sgit-ffi/src/settings.rs）----

typedef _Str1C = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _Str1Dart = Pointer<Utf8> Function(Pointer<Utf8>);

typedef _Str2C = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _Str2Dart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);

typedef _Str3C = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);
typedef _Str3Dart = Pointer<Utf8> Function(
    Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>);

typedef _Str0C = Pointer<Utf8> Function();
typedef _Str0Dart = Pointer<Utf8> Function();

/// `(const char*, int)` —— `sgit_studio_refresh` 的 `force` 用它。
typedef _Str1IntC = Pointer<Utf8> Function(Pointer<Utf8>, Int);
typedef _Str1IntDart = Pointer<Utf8> Function(Pointer<Utf8>, int);

typedef _FreeC = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

/// 在后台 isolate 里跑一次「吃若干字符串、吐一个字符串」的 FFI 调用。
///
/// ## 为什么必须换个 isolate
///
/// FFI 调用是**同步**的：Dart 这边一进去，直到 Rust 返回为止，这个 isolate
/// 什么都做不了。主 isolate 就是 UI 线程 —— 于是：
///
/// ```text
/// 点进技能页 → sgit_studio_read 读 1000+ 个 SKILL.md → 界面冻住
///            → sgit_studio_refresh 打服务器全量对账     → 继续冻住
///            → 一切算完，内容"啪"地一次出现
/// ```
///
/// 把方法标成 `async` **不解决问题**：async 函数体在遇到第一个 `await` 之前
/// 是同步执行的，而这里根本没有 await 可言 —— 整段都在 UI 线程上。
/// 这正是「说好的先读本地秒回，实际每页第一次进去都卡」的原因：
/// SWR 的两态在代码里分得很清楚，但两态都把 UI 线程占死了，
/// 用户一帧中间状态都看不到。
///
/// [Isolate.run] 起一个临时 isolate 跑完就回收。代价是每次几毫秒的启动开销，
/// 换来 UI 线程全程不阻塞 —— 相对于动辄几百毫秒的目录遍历与网络往返，这笔买卖
/// 毫无悬念。
///
/// ⚠️ 传进去的闭包**不能捕获主 isolate 的对象**（`DynamicLibrary` 句柄、
/// `late final` 的函数指针都不行，它们不可跨 isolate 传递）。所以这里在
/// isolate 内部重新 open + lookup。重复 open 同一个动态库由操作系统按引用计数
/// 处理，不会真的加载两遍。
///
/// Rust 那侧的会话、tokio 运行时、脏队列都是**进程级**静态，跨 isolate 共享 ——
/// 换句话说后台 isolate 看到的是同一份状态，不需要重新登录。
Future<String> _ffiCall(String symbol, List<String> args) =>
    Isolate.run(() {
      final lib = _openNativeLib();
      final fn = switch (args.length) {
        1 => (Pointer<Utf8> a) =>
            lib.lookupFunction<_Str1C, _Str1Dart>(symbol)(a),
        _ => null,
      };
      final ptrs = args.map((s) => s.toNativeUtf8()).toList(growable: false);
      try {
        final out = switch (args.length) {
          0 => lib.lookupFunction<_Str0C, _Str0Dart>(symbol)(),
          1 => fn!(ptrs[0]),
          2 => lib.lookupFunction<_Str2C, _Str2Dart>(symbol)(ptrs[0], ptrs[1]),
          3 => lib.lookupFunction<_Str3C, _Str3Dart>(symbol)(
              ptrs[0], ptrs[1], ptrs[2]),
          _ => throw ArgumentError('不支持 ${args.length} 个参数'),
        };
        if (out == nullptr) throw const ApiException('FFI 返回空');
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

/// `sgit_studio_refresh` 单独一个 —— 它的第二个参数是 int 不是字符串。
Future<String> _ffiCallStrInt(String symbol, String a, int b) =>
    Isolate.run(() {
      final lib = _openNativeLib();
      final p = a.toNativeUtf8();
      try {
        final out = lib.lookupFunction<_Str1IntC, _Str1IntDart>(symbol)(p, b);
        if (out == nullptr) throw const ApiException('FFI 返回空');
        try {
          return out.toDartString();
        } finally {
          lib.lookupFunction<_FreeC, _FreeDart>('free_string')(out);
        }
      } finally {
        malloc.free(p);
      }
    });

/// 顶层函数（不是实例方法）—— 后台 isolate 里要能直接调到，不带任何捕获状态。
DynamicLibrary _openNativeLib() {
  if (Platform.isWindows) return DynamicLibrary.open('sgit_ffi.dll');
  if (Platform.isMacOS) return DynamicLibrary.open('libsgit_ffi.dylib');
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('libsgit_ffi.so');
  }
  if (Platform.isIOS) return DynamicLibrary.process();
  throw UnsupportedError('当前平台不支持 sgit_ffi');
}

/// 解析 native 返回的 JSON 信封。`{"error":...}` 一律抛 [ApiException]。
///
/// ⚠️ **鉴权失败必须在这里广播出去**。上游（模型列表、中转站、studio 各页）
/// 拿到异常后多数会 `catch` 住回空列表 —— 那是对的（一个 scope 挂了不该拖累
/// 另一侧），但它同时也意味着失效信号到此为止。用户看到的是"暂无可用模型"，
/// 永远回不到登录页。所以信号在这里就发，不指望异常冒泡。
Map<String, Object?> _decode(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, Object?>) {
    throw const ApiException('配置接口响应格式异常');
  }
  final e = decoded['error'];
  if (e != null) {
    final msg = e.toString();
    // 优先 native 的结构化 `code`，关键词判据只作旧 DLL 的降级。
    final byCode = decoded['code'] == 'auth_expired';
    final expired = byCode || isAuthFailureMessage(msg);
    if (expired) AuthFailure.report(msg);
    throw ApiException(msg, isAuthExpired: expired);
  }
  return decoded;
}

/// 桌面/移动的配置仓储 —— 转发给 `sgit_ffi` 的 `sgit_settings_*`。
///
/// ## 这里只有转发
///
/// 「先服务器后本地」「脏队列」「冲突备份」全在 Rust 侧（`settings.rs`）。
/// 放那边而不是这里编排两步，理由与内核通道一致：路径知识、队列状态、
/// 冲突落盘都属于同一处事务，拆到 Dart 会变成两个真源。
/// 本文件只做 marshalling 与信封解析。
///
/// ## 所有调用都在后台 isolate 上
///
/// 见 [_ffiCall]：FFI 是同步的，留在主 isolate 就等于冻住 UI。
final class IoSettingsRepository implements SettingsRepository {
  IoSettingsRepository();

  @override
  bool get hasLocalCopy => true;

  @override
  Future<List<SettingsEntry>> list(String kind) async {
    final m = _decode(await _ffiCall('sgit_settings_list', [kind]));
    final items = m['items'];
    if (items is! List) return const [];
    return items.whereType<Map>().map((raw) {
      final r = raw.cast<String, Object?>();
      return SettingsEntry(
        id: r['id']?.toString() ?? '',
        size: _int(r['size']),
        sha256: r['sha256']?.toString() ?? '',
        // 缺字段时保守当已同步 —— 免得因为解析问题给每一项都打上角标。
        synced: r['synced'] != false,
      );
    }).toList(growable: false);
  }

  @override
  Future<String> read(String kind, String id) async {
    final m = _decode(await _ffiCall('sgit_settings_read', [kind, id]));
    return m['content']?.toString() ?? '';
  }

  @override
  Future<SettingsEntry> write(String kind, String id, String content) async {
    final m = _decode(
        await _ffiCall('sgit_settings_write', [kind, id, content]));
    return SettingsEntry(
      id: id,
      sha256: m['sha256']?.toString() ?? '',
      // synced=false 不是失败：本地已写入、已排队，界面打角标即可。
      synced: m['synced'] == true,
    );
  }

  @override
  Future<void> delete(String kind, String id) async {
    _decode(await _ffiCall('sgit_settings_delete', [kind, id]));
  }

  // ---- studio 各页（SWR）----

  @override
  Future<Map<String, Object?>> readPage(String page) async =>
      _decode(await _ffiCall('sgit_studio_read', [page]));

  /// ⚠️ 这里**吞掉所有异常**，是刻意的。刷新是 SWR 的后半段，界面已经有本地
  /// 内容了 —— 断网时把异常抛上去只会让页面变成错误态，比"数据稍旧"糟得多。
  ///
  /// [force] 区分「进页面自动刷」与「用户点了刷新按钮」：受管资源那条路
  /// 一次覆盖全部目录，自动刷会被 15 秒窗口合并（见 studio.rs 的 COALESCE_WINDOW），
  /// 而按钮必须真跑 —— 否则点了没反应，像坏了。
  @override
  Future<RefreshOutcome> refreshPage(String page, {bool force = false}) async {
    try {
      final m = _decode(
          await _ffiCallStrInt('sgit_studio_refresh', page, force ? 1 : 0));
      return RefreshOutcome(
        ok: m['ok'] == true,
        changed: m['changed'] == true,
        reason: m['reason']?.toString() ?? '',
      );
    } catch (e) {
      return RefreshOutcome(ok: false, reason: e.toString());
    }
  }

  @override
  Future<void> removeFromPage(String page, String id) async {
    _decode(await _ffiCall('sgit_studio_remove', [page, id]));
  }

  @override
  Future<Map<String, Object?>> relayManage(
      String group, String method, Map<String, Object?> params) async {
    // 整个请求体按 JSON 传 —— relay_manage 收的就是一个 Value，
    // group/method/mode/scope 都在里面，与 gateway 的 body 逐字同形。
    final body = jsonEncode({'group': group, 'method': method, ...params});
    return _decode(await _ffiCall('sgit_relay_manage', [body]));
  }

  @override
  Future<void> setToolConfig(String keyPath, Object value) async {
    // 值按 JSON 传：开关是 bool，web_search 是字符串 —— 一个 C 字符串参数
    // 带两种类型，JSON 是最省事的编码，Rust 那边 serde_json 直接解。
    final json = jsonEncode(value);
    final m =
        _decode(await _ffiCall('sgit_studio_set_tool', [keyPath, json]));
    // synced:false 不是失败 —— 本地已写入并排队，与 write() 同一套语义。
    if (m['ok'] != true) {
      throw ApiException(m['reason']?.toString() ?? '设置失败');
    }
  }

  @override
  Future<SyncOutcome> sync() async {
    final m = _decode(await _ffiCall('sgit_settings_sync', const []));
    if (m['ok'] != true) {
      return SyncOutcome(ok: false, reason: m['reason']?.toString() ?? '同步失败');
    }
    final raw = m['conflicts'];
    final conflicts = raw is List
        ? raw.whereType<Map>().map((c) {
            final r = c.cast<String, Object?>();
            return SyncConflict(
              kind: r['kind']?.toString() ?? '',
              id: r['id']?.toString() ?? '',
              backup: r['backup']?.toString() ?? '',
            );
          }).toList(growable: false)
        : const <SyncConflict>[];
    return SyncOutcome(
      ok: true,
      pushed: _int(m['pushed']),
      pulled: _int(m['pulled']),
      conflicts: conflicts,
    );
  }

  static int _int(Object? v) => switch (v) {
        final num n => n.toInt(),
        final String s => int.tryParse(s) ?? 0,
        _ => 0,
      };
}

SettingsRepository createSettingsRepository() => IoSettingsRepository();
