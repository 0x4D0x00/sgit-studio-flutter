import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/thread_repository.dart';
import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';
import 'package:sgit_studio_flutter/features/artifacts/application/artifacts_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/session_sync_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/thread_list_controller.dart';
import 'package:sgit_studio_flutter/services/chat/chat_ports.dart';

/// [ChatPorts] 的 Riverpod 实现：把接口方法转给各 feature 的 controller。
///
/// 全部**调用时才 `read`**，不在构造时取值 —— `thread_list_controller` 会 watch
/// `chatControllerProvider`，提前取就成环。
class FeatureChatPorts implements ChatPorts {
  FeatureChatPorts(this._ref);

  final Ref _ref;

  @override
  EngineMode get engineMode =>
      _ref.read(composerSettingsProvider).settings.engineMode;

  @override
  ThreadRepository get threadRepository => _ref.read(threadRepositoryProvider);

  @override
  Future<void> syncNow() => _ref.read(sessionSyncProvider).syncNow();

  @override
  void onTurnCompleted() => _ref.read(sessionSyncProvider).onTurnCompleted();

  @override
  Future<void> reloadThreads() =>
      _ref.read(threadListProvider.notifier).reload();

  @override
  List<ThreadSummary> get threads => _ref.read(threadListProvider).items;

  @override
  void replaceArtifacts(String threadId, List<FoundArtifact> found) => _ref
      .read(artifactsControllerProvider.notifier)
      .replaceForThread(threadId, found);
}

/// 应用根与测试里注入用：`ProviderScope(overrides: [chatPortsOverride])`。
final chatPortsOverride =
    chatPortsProvider.overrideWith((ref) => FeatureChatPorts(ref));
