import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/thread_repository.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';

/// 一条会话里找到的文件卡：产物本体 + 它所在消息的时间。
typedef FoundArtifact = ({ChatArtifact artifact, DateTime? at});

/// `ChatController` 对外的依赖面。
///
/// 会话状态机需要「读引擎模式 / 触发同步 / 刷新会话列表 / 登记产物」，但这四样
/// 的实体都是 features 层的 controller —— `services` 直接 import 它们就成了反向依赖
/// （还会和 `thread_list_controller` watch `chatControllerProvider` 互相缠住）。
///
/// 所以这里只声明**接口**，实现在 `features/chat/application/chat_ports_impl.dart`，
/// 由 `ProviderScope(overrides: [chatPortsOverride])` 在应用根注入。
abstract interface class ChatPorts {
  /// 当前引擎模式（本地 / 云端）。
  EngineMode get engineMode;

  /// 会话仓储。**跟着引擎模式重建**，所以每次用都重新取，别缓存。
  ThreadRepository get threadRepository;

  /// 只把这一条会话的服务器新增部分拉到本地，返回「有没有拉到新东西」。失败一律 false。
  Future<bool> refreshThread(String threadId);

  /// 立即跑一次会话同步；未启用时是 no-op。
  Future<void> syncNow();

  /// 一轮对话结束，排一次（去抖的）同步。
  void onTurnCompleted();

  /// 重新拉取会话列表。
  Future<void> reloadThreads();

  /// 当前已载入的会话列表（最近一次 [reloadThreads] 的结果）。
  List<ThreadSummary> get threads;

  /// 整体替换某条会话的产物登记。
  void replaceArtifacts(String threadId, List<FoundArtifact> found);
}

/// ⚠️ 没有默认实现：忘了注入就在第一次读取时抛，而不是悄悄变成 no-op
/// （那样「列表不刷新」「产物不登记」会离起因很远）。测试同样需要
/// `overrides: [chatPortsOverride]`。
final chatPortsProvider = Provider<ChatPorts>(
  (ref) => throw UnimplementedError(
    'chatPortsProvider 未注入：在 ProviderScope / ProviderContainer 的 '
    'overrides 里加上 chatPortsOverride',
  ),
);
