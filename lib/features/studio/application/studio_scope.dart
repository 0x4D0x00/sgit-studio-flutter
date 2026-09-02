import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 作用域 —— studio 全部 8 个子页共用的一个维度。
///
/// | | [personal] | [master] |
/// |---|---|---|
/// | 数据落在 | per-cid 本地库（仅本人） | 服务器 SeekDB（对所有用户生效） |
/// | 中转站的行 | `tag=custom` | `tag=builtin` |
/// | 后端寻址 | 缺省（gateway 默认个人 home） | `?scope=master` / body `scope:'master'` |
///
/// ⚠️ **默认个人**，与 React studio 一致。默认管理会让用户一进来就在改全平台配置。
///
/// 后端已经全支持（gateway 的 `scope_from_query`，中转站读 body 的 `scope`），
/// 这里只是把它接上来 —— 不需要动后端。
enum StudioScope {
  personal('personal'),
  master('master');

  const StudioScope(this.wire);

  /// 传给后端的字面值。别改，两端约定好的。
  final String wire;

  bool get isMaster => this == StudioScope.master;

  /// 中转站按 tag 分作用域：管理版看内置行，个人版看自建行。
  ///
  /// 缺 `tag` 的历史行按 `builtin` 处理（归管理侧），与 React studio 的
  /// `keepByTag` 一致。
  String get tag => isMaster ? 'builtin' : 'custom';
}

/// 当前作用域。**内存态，刻意不持久化** —— 换页/刷新回到个人版更安全，
/// 免得用户上次切到管理版就一直停在那儿改全平台配置而不自知。
class StudioScopeController extends Notifier<StudioScope> {
  @override
  StudioScope build() => StudioScope.personal;

  void set(StudioScope s) => state = s;
}

final studioScopeProvider =
    NotifierProvider<StudioScopeController, StudioScope>(
        StudioScopeController.new);

/// 给 GET 端点拼 query。gateway 的 `scope_from_query` 认 `?scope=master`，
/// 缺省即个人 —— 所以个人版**不拼**，保持 URL 干净（也和 React studio 行为一致）。
String scopeQuery(StudioScope scope, [String? extra]) {
  final parts = <String>[
    if (scope.isMaster) 'scope=${scope.wire}',
    if (extra != null && extra.isNotEmpty) extra,
  ];
  return parts.isEmpty ? '' : '?${parts.join('&')}';
}
