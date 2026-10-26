import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/app/app_providers.dart';
import 'package:sgit_studio_flutter/data/repositories/session_sync_repository.dart';

/// 会话历史同步的触发器。
///
/// ## 做什么
///
/// 把本机引擎产生的 rollout 推到服务器那份 per-cid 目录，也把云端产生的拉回来。
/// 真正的搬运在 Rust（`sgit-ffi/src/session_sync.rs`）与 Go
/// （`sgcodesystem` 的 `session_*` 方法）里，这一层只管**什么时候**触发。
///
/// ## 三个触发点
///
/// | 时机 | 为什么 |
/// |---|---|
/// | 一轮对话结束 | 刚产生的内容要尽快可见；去抖 30s，避免连续对话时每轮一次 |
/// | 切到云端引擎前 | 否则刚在本地聊的那条，切过去在云端列表里看不到 |
/// | 应用退出 | 把去抖窗口里没来得及推的那次补上 |
///
/// ## 为什么去抖而不是每轮都推
///
/// rollout 是 append-only 的，一轮对话往文件尾追加几 KB。连续对话时每轮推一次
/// 会让同一个文件在几分钟内被追加十几次，每次都是一轮加密往返 —— 而它们本可以
/// 合成一次。30s 是个折中：用户切引擎/关应用时会强制 flush，所以"最多丢 30s
/// 的可见性"不会变成"丢数据"。
///
/// ## ⚠️ 服务端进程不该跑这个
///
/// 判断在 Rust 侧（`sync_enabled()`：显式开关 > 平台默认 > 容器兜底）。
/// 这边只读 [SessionSyncRepository.enabled] 决定要不要发起 —— 关着时连 FFI
/// 都不调，省掉一次 isolate 往返。
class SessionSyncController {
  SessionSyncController(this._repo);

  final SessionSyncRepository _repo;

  /// 一轮对话结束后的去抖窗口。
  static const _debounce = Duration(seconds: 30);

  Timer? _timer;

  /// 正在跑的那次同步。用来避免并发 —— 两次同时推同一个文件会在 append
  /// 偏移上互相打架（服务端会拒掉后一次，客户端再重试，白费一轮）。
  Future<void>? _inFlight;

  /// 本进程是否启用。关着时所有触发都是 no-op。
  bool get enabled => _repo.enabled;

  /// 一轮对话结束 —— 去抖后同步。
  void onTurnCompleted() {
    if (!enabled) return;
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(syncNow()));
  }

  /// 立刻同步（切引擎前、退出前）。
  ///
  /// 与去抖那条路共用 [_inFlight]，所以"定时器刚好也到点了"不会变成两次并发。
  Future<void> syncNow() {
    if (!enabled) return Future<void>.value();
    _timer?.cancel();
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  Future<void> _run() async {
    try {
      final r = await _repo.sync();
      // ⚠️ 必须留日志。同步是**后台行为**，界面上没有任何反馈 ——
      // 不打日志的话，"云端看不到本地会话"这种问题完全无从下手。
      if (r.ok) {
        if (r.uploaded > 0 || r.downloaded > 0) {
          debugPrint('[sessionSync] 上传 ${r.uploaded} 下载 ${r.downloaded}');
        }
      } else {
        debugPrint('[sessionSync] 未完成：${r.reason ?? "未知原因"}'
            '（失败 ${r.failed} 条）');
      }
    } catch (e) {
      // 同步失败**不该打扰用户**：会话本身好好的在本地，只是还没同步过去。
      // 但同样必须留痕。
      debugPrint('[sessionSync] 同步出错：$e');
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}

final sessionSyncProvider = Provider<SessionSyncController>((ref) {
  final c = SessionSyncController(ref.watch(sessionSyncRepositoryProvider));
  ref.onDispose(c.dispose);
  return c;
});
