import 'package:sgit_studio_flutter/data/repositories/session_sync_repository.dart';

/// Web 的会话同步 —— **没有可同步的东西**。
///
/// 同步解决的是"本地引擎产生的会话在云端看不到"。而 Web 跑在浏览器里，
/// 它压根没有本地引擎：所有会话都由服务器上的沙箱产生，本来就在目标目录里。
///
/// 所以 [enabled] 恒为 false，[sync] 是 no-op —— 与 Rust 侧
/// `sync_enabled()` 对服务端的判断同一个道理。
final class WebSessionSyncRepository implements SessionSyncRepository {
  const WebSessionSyncRepository();

  @override
  bool get enabled => false;

  @override
  Future<SessionSyncResult> sync() async => const SessionSyncResult(
        ok: true,
        reason: 'Web 端没有本地引擎，会话本来就在服务器上',
      );
}

SessionSyncRepository createSessionSyncRepository() =>
    const WebSessionSyncRepository();
