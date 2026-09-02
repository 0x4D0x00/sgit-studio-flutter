import 'package:sgit_studio_flutter/core/contracts/gateway_endpoints.dart';
import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';

/// 网关数据仓储 —— studio 各页的**唯一**数据入口。
///
/// ## SWR：先本地秒回，再拉后端刷新
/// gateway 侧同一个端点支持两态（范式见 `sgcode_models_manage`）：
/// - `mode=cache` → 读 sgcode 本地 sqlite 秒回，**不碰网络**；
/// - `mode=sync`  → 转发后端，读方法顺手写回本地缓存。
///
/// 所以 [swr] 会**连发两次、回调两次**：第一次让界面立刻有东西，第二次把真数据换上。
/// 界面不要转圈等后端。
///
/// ## 为什么经 wasm 而不是 Dart 直接 fetch
/// 会话 token 只在 wasm 里（Dart 有意拿不到），身份头由它拼。见
/// `kernel_client_web.dart` 的说明。
class GatewayRepository {
  const GatewayRepository(this._client);

  final KernelClient _client;

  /// 一次性读取（无缓存语义的端点用）。
  Future<Map<String, Object?>> get(String path) => _client.gatewayCall(path);

  /// 按端点**登记的动词**发请求，调用方不再自己选 GET 还是 POST。
  ///
  /// ⚠️ 原先各页一律 `get(listPath)`，但 gateway 的 list 端点动词并不统一
  /// （`mcp/list` 是 POST）→ MCP 页直接 405、页面空白。查表就不会再选错。
  Future<Map<String, Object?>> fetch(String path,
          [Map<String, Object?> body = const {}]) =>
      switch (verbFor(path)) {
        HttpVerb.get => get(path),
        HttpVerb.post => post(path, body),
      };

  Future<Map<String, Object?>> post(String path, Map<String, Object?> body) =>
      _client.gatewayCall(path, method: 'POST', body: body);

  /// SWR 读取：先 cache 后 sync，各回调一次。
  ///
  /// [onData] 可能被调用 1~2 次：
  /// - 本地有缓存 → 立刻回一次（`fresh: false`），后端回来再一次（`fresh: true`）；
  /// - 本地没缓存 → 只在后端回来时回一次。
  ///
  /// 后端失败但本地有缓存时**不抛异常**（界面已有内容，弹错反而更糟），
  /// 通过 [onError] 交给调用方决定要不要提示。
  Future<void> swr(
    String path,
    Map<String, Object?> body, {
    required void Function(Map<String, Object?> data, {required bool fresh})
        onData,
    void Function(Object error)? onError,
    bool syncAfterCache = true,
  }) async {
    var gotCache = false;
    try {
      final cached = await post(path, {...body, 'mode': 'cache'});
      if (_hasPayload(cached)) {
        gotCache = true;
        // 不打后端时缓存就是终态 —— 标 fresh 让界面别一直挂着"正在刷新"。
        onData(cached, fresh: !syncAfterCache);
      }
    } catch (e) {
      // 本地缓存读失败通常不算错误（后面 sync 会补上）；但如果压根不打后端，
      // 这就是唯一的数据来源，失败必须报出去。
      if (!syncAfterCache) {
        if (onError == null) rethrow;
        onError(e);
        return;
      }
    }

    // 个人作用域的数据只在本地 per-cid 库，打后端既拿不到也没必要
    // （照 React studio：personal 只读 cache）。
    if (!syncAfterCache) {
      if (!gotCache) onData(const {}, fresh: true);
      return;
    }

    try {
      onData(await post(path, {...body, 'mode': 'sync'}), fresh: true);
    } catch (e) {
      // 有缓存兜底就只报给调用方；没缓存则必须抛，否则界面空白且用户不知道为什么。
      if (!gotCache) rethrow;
      onError?.call(e);
    }
  }

  /// 响应里是否真有内容 —— 空数组的缓存等于没缓存，不该顶掉 loading 态。
  static bool _hasPayload(Map<String, Object?> m) => m.entries.any((e) {
        final v = e.value;
        if (e.key == 'status') return false;
        return switch (v) {
          final List<Object?> l => l.isNotEmpty,
          final Map<String, Object?> mm => mm.isNotEmpty,
          null => false,
          _ => true,
        };
      });
}
