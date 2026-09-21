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

  /// 剥掉 `{status, data:{...}}` 的外壳。
  ///
  /// ⚠️ `gatewayCall` 只负责**失败时抛异常**，成功时返回的是**整个信封**，
  /// 不是 `data`。而 `ThreadPage.fromJson` 读的是 `j['threads']` ——
  /// 不剥的话它找不到键，回落成**空列表且不报错**：云端模式下历史会话
  /// 全部消失，界面上与"你确实没有会话"一模一样。
  ///
  /// 桌面那条路早就有同样的处理（`thread_repository_io.dart` 的 `_unwrap`），
  /// 这边漏了。
  ///
  /// 没有 `data` 时退回整个响应：万一将来某个端点直接回扁平结构，
  /// 这里不该把它判成空。
  static Map<String, Object?> _data(Map<String, Object?> envelope) {
    final d = envelope['data'];
    return d is Map ? d.cast<String, Object?>() : envelope;
  }

  @override
  Future<ThreadPage> list({String? cursor}) async {
    final path = (cursor == null || cursor.isEmpty)
        ? '/sgcode-thread/list'
        : '/sgcode-thread/list?cursor=$cursor';
    return ThreadPage.fromJson(_data(await _repo.get(path)));
  }

  @override
  Future<ThreadReplay> open(String threadId) async => ThreadReplay.fromJson(
        _data(await _repo.post('/sgcode-thread/open', {'threadId': threadId})),
      );

  @override
  Future<void> rename(String threadId, String name) =>
      _repo.post('/sgcode-thread/rename', {'threadId': threadId, 'name': name});

  @override
  Future<void> delete(String threadId) =>
      _repo.post('/sgcode-thread/delete', {'threadId': threadId});
}

ThreadRepository createThreadRepository() => WebThreadRepository();
