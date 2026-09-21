import 'package:sgit_studio_flutter/data/repositories/gateway_repository.dart';
import 'package:sgit_studio_flutter/data/repositories/thread_repository.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_factory.dart';
import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';

/// Web 的会话仓储 —— 直通 gateway 的 `/sgcode-thread/*`。
///
/// Web 恒为云端模式（浏览器里没有本地引擎），所以不存在桌面那种
/// "按 engineMode 分流"的问题：这里永远打 gateway。
///
/// 返回形状与桌面 FFI 路**一字不差** —— 两侧的 JSON 都由 Rust 的同一个
/// `thread.rs::brief()` 产出，所以 `ThreadSummary.fromJson` 只有一套。
final class WebThreadRepository implements ThreadRepository {
  WebThreadRepository() : _repo = GatewayRepository(createKernelClient());

  final GatewayRepository _repo;

  @override
  Future<ThreadPage> list({String? cursor}) async {
    final path = (cursor == null || cursor.isEmpty)
        ? '/sgcode-thread/list'
        : '/sgcode-thread/list?cursor=$cursor';
    return ThreadPage.fromJson(await _repo.get(path));
  }

  @override
  Future<ThreadReplay> open(String threadId) async => ThreadReplay.fromJson(
        await _repo.post('/sgcode-thread/open', {'threadId': threadId}),
      );

  @override
  Future<void> rename(String threadId, String name) =>
      _repo.post('/sgcode-thread/rename', {'threadId': threadId, 'name': name});

  @override
  Future<void> delete(String threadId) =>
      _repo.post('/sgcode-thread/delete', {'threadId': threadId});
}

ThreadRepository createThreadRepository() => WebThreadRepository();
