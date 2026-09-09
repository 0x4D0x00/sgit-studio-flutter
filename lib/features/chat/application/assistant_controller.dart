import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/chat/assistant_kind.dart';

/// 当前选中的助理。默认渗透助理（与左栏第一个助理项一致）。
///
/// 只存「选了哪个」这一个字段，**切换的副作用不在这里做** —— 换 scene / 清列表由
/// `ChatController.newChatWithScene` 负责。放一起会让「读当前助理」这种纯查询
/// 也牵动会话状态。
class AssistantController extends Notifier<AssistantKind> {
  @override
  AssistantKind build() => AssistantKind.pentest;

  void select(AssistantKind kind) => state = kind;
}

final assistantControllerProvider =
    NotifierProvider<AssistantController, AssistantKind>(
  AssistantController.new,
);
