import 'thread_repository_io.dart'
    if (dart.library.js_interop) 'thread_repository_web.dart' as impl;

import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';

/// 会话（thread）仓储 —— 列表 / 打开 / 改名 / 删除。
///
/// ## 与 `SettingsRepository` 的一处关键不同
///
/// ⚠️ **这个仓储不按平台分流，按引擎模式分流。**
///
/// `SettingsRepository` 在桌面端恒走本地 FFI（配置就在本机硬盘上）。会话不是：
/// 桌面端的 `EngineMode` 是**运行时**设置，用户随时能在输入框下面切：
///
/// ```text
/// 本地引擎 → 会话在本机 <cid_home>/sessions/
/// 云端引擎 → 会话在服务器那台机器上
/// ```
///
/// 所以两条路都要能走，且**必须跟着 engineMode 变**。Rust 侧
/// （`sgit-ffi/src/thread.rs`）按 `get_mode()` 自己分发，Dart 这边只管调同一组
/// 符号；但 provider 仍要 watch engineMode 重建仓储 —— 否则切了云端，
/// 列表里还挂着上一次本地查出来的结果。
abstract interface class ThreadRepository {
  /// 列会话。`cursor` 为空取第一页。
  Future<ThreadPage> list({String? cursor});

  /// 打开一条会话：加载进引擎 + 拿到回放事件。
  Future<ThreadReplay> open(String threadId);

  /// 改标题。空串等于清掉自定义名字（回落到首条消息摘要）。
  Future<void> rename(String threadId, String name);

  /// 删会话。
  Future<void> delete(String threadId);
}

/// 按平台造实例。桌面/移动走 `dart:ffi`，Web 走 gateway。
///
/// ⚠️ 测试里必须 `overrideWithValue` 一个假实现 —— 桌面工厂会去 dlopen
/// `sgit_ffi.dll`，测试环境没有那个库，一调就挂。
/// （`settings_repository_provider.dart` 的注释记着同一个坑。）
ThreadRepository createThreadRepository() => impl.createThreadRepository();
