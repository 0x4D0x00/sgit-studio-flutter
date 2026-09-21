import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_sync_repository_io.dart'
    if (dart.library.js_interop) 'session_sync_repository_web.dart' as impl;

/// 一次同步的结果。
class SessionSyncResult {
  const SessionSyncResult({
    required this.ok,
    this.uploaded = 0,
    this.downloaded = 0,
    this.skipped = 0,
    this.failed = 0,
    this.reason,
  });

  final bool ok;
  final int uploaded;
  final int downloaded;
  final int skipped;
  final int failed;

  /// 未启用 / 未登录 / 服务器不可达时的说明。
  ///
  /// ⚠️ `ok == true` **也可能带 reason** —— "本进程未启用同步"是正常情形
  /// （服务端那份 sgcode 自己就是目的地），不是错误。
  final String? reason;

  static SessionSyncResult fromJson(Map<String, Object?> j) => SessionSyncResult(
        ok: j['ok'] == true,
        uploaded: _int(j['uploaded']),
        downloaded: _int(j['downloaded']),
        skipped: _int(j['skipped']),
        failed: _int(j['failed']),
        reason: j['reason']?.toString(),
      );

  static int _int(Object? v) => switch (v) {
        final int n => n,
        final double d => d.toInt(),
        final String s => int.tryParse(s) ?? 0,
        _ => 0,
      };
}

/// 会话历史同步。
///
/// 把本机引擎产生的 rollout 推到服务器那份 per-cid 目录（让云沙箱的
/// `thread/list` 也能列出来），也把云端产生的拉回本地。
///
/// 搬运本身在 Rust（`sgit-ffi/src/session_sync.rs`，按字节偏移追加）与 Go
/// （`sgcodesystem` 的 `session_*`）里，这一层只是 FFI 转发。
abstract interface class SessionSyncRepository {
  /// 本进程是否该做同步。
  ///
  /// 判断在 Rust 侧（显式开关 `SGIT_SESSION_SYNC` > 平台默认 > 容器兜底）。
  /// **服务端进程恒为 false** —— 它自己就写在目标目录里，再传一次等于自己
  /// 传给自己，还会在 append 偏移上和自己打架。
  bool get enabled;

  /// 跑一次双向同步。
  Future<SessionSyncResult> sync();

  /// 只把**这一条**会话的服务器新增部分拉到本地。返回"有没有拉到新东西"。
  ///
  /// 点开历史会话时用：先显示本地那份（秒回），同时在后台问一下服务器有没有
  /// 更新，有才重新装配界面。[sync] 做不了这件事 —— 它要列全量、比对、把
  /// 所有落后的文件补齐（本机 43 个文件 41MB 的量级），点一下会话等不起。
  ///
  /// **失败一律返回 false，不抛** —— 本地那份已经在屏幕上了，拉不到更新只是
  /// 没有更新，不该打扰用户，更不该把已显示的内容换掉。
  Future<bool> refreshThread(String threadId);
}

final sessionSyncRepositoryProvider = Provider<SessionSyncRepository>(
  (ref) => impl.createSessionSyncRepository(),
);
