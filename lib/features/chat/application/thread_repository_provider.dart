import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/thread_repository.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';

/// 会话仓储。**跟着引擎模式重建** —— 切了云端还挂着本地那份列表就错了。
///
/// ## 为什么单独一个文件
///
/// 同类 provider 在 `app/app_providers.dart`，
/// 这个不行：它要 `watch` 属于 features 层的 `composerSettingsProvider`，
/// 放进 `data/repositories/` 就成了 data 反向依赖 features。
///
/// 原先它挂在 `thread_list_controller.dart` 里，也不行 —— `chat_controller`
/// 打开会话时要用它，而 `thread_list_controller` 本身又要 watch
/// `chatControllerProvider`（等连上再拉列表），两边互引成环。
///
/// ⚠️ 测试里必须 `overrideWithValue`：桌面工厂会 dlopen `sgit_ffi.dll`，
/// 测试环境没有那个库，一调就挂。
final threadRepositoryProvider = Provider<ThreadRepository>((ref) {
  // watch 而不是 read：engineMode 变了要重建仓储，否则列表停在上一个引擎的结果。
  ref.watch(composerSettingsProvider.select((s) => s.settings.engineMode));
  return createThreadRepository();
});
