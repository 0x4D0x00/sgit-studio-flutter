import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 工作台空态的创作模式 —— 由输出产物页的 Docs / Slides / Design 入口设置。
///
/// 只影响空态输入框的提示语和下方的标签行；开新对话（[ChatController.newChat]）时复位。
enum WorkspaceMode { chat, docs, slides, design }

class WorkspaceModeController extends Notifier<WorkspaceMode> {
  @override
  WorkspaceMode build() => WorkspaceMode.chat;

  void set(WorkspaceMode mode) => state = mode;
}

final workspaceModeProvider =
    NotifierProvider<WorkspaceModeController, WorkspaceMode>(
  WorkspaceModeController.new,
);
