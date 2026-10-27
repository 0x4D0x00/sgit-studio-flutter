import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 左栏用到的导航 id 与前缀。
///
/// 抽到这里是因为容器、历史区、搜索弹窗**三处**都要拼 / 拆这些 id，各写一份字面量
/// 必然漂。
///
/// ⚠️ **前缀必须互不为前缀。** `NavPanelContainer._onSelect` 靠前缀分派，先到先得：
/// 一旦某个前缀是另一个的前缀，后一个就被静默吃掉。尤其是历史会话与助理 ——
/// 两边的 id 都是 UUID 形态，走错分支不会报错，只会静默把 threadId 当 sceneId 用
/// （原先历史区复用助理前缀时点「历史对话」开出空会话、删除还删掉了场景定义本身）。
abstract final class NavIds {
  // 非 studio 的固定项 id。用常量而非字面量，避免和 studio key 撞。
  static const String newChat = 'nav.new-chat';
  static const String artifacts = 'nav.artifacts';
  static const String projects = 'nav.projects';
  static const String customize = 'nav.customize';
  static const String history = 'nav.history';
  static const String agent = 'nav.agent';
  static const String historyMore = 'nav.history-more';

  /// 助理项前缀。**只给助理用**：选中 = 用该场景开一轮新对话（`newChatWithScene`），
  /// 语义上就不该载入任何历史消息 —— 别把历史条目也挂到这个前缀上。
  static const String assistantPrefix = 'assistant:';

  /// 历史会话项前缀。
  static const String threadPrefix = 'thread:';

  /// 搜索弹窗里的产物项前缀。点开走右侧产物面板，不进导航分支。
  static const String artifactPrefix = 'artifact:';

  /// 搜索弹窗里的项目项前缀。点开落在 Projects 页。
  static const String projectPrefix = 'project:';

  static String thread(String threadId) => '$threadPrefix$threadId';
  static String artifact(String artifactId) => '$artifactPrefix$artifactId';
  static String project(String projectId) => '$projectPrefix$projectId';

  /// 去掉前缀；没有该前缀返回 null。
  static String? strip(String id, String prefix) =>
      id.startsWith(prefix) ? id.substring(prefix.length) : null;
}

/// 「未接入」占位提示。
void showNavNotWired(BuildContext context, AppLocalizations l10n, String id) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(l10n.commonNotWired(id)),
      duration: const Duration(seconds: 1),
    ),
  );
}
