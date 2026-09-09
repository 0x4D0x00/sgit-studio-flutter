import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/chat/assistant_kind.dart';
import 'package:sgit_studio_flutter/features/chat/application/assistant_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/assistant_switcher.dart';

/// 助理切换器容器 —— 把 provider / l10n 喂给纯组件 [AssistantSwitcher]。
///
/// 这一层是**唯一**知道「有哪几个助理、切了之后发生什么」的地方。
class AssistantSwitcherContainer extends ConsumerWidget {
  const AssistantSwitcherContainer({super.key});

  /// 图标在这里定，不进 [AssistantKind] —— 枚举是领域模型，不该认识 Material 图标。
  static const Map<AssistantKind, IconData> _icons = {
    AssistantKind.pentest: Icons.security_outlined,
    AssistantKind.defense: Icons.shield_outlined,
    AssistantKind.contest: Icons.emoji_events_outlined,
    AssistantKind.office: Icons.work_outline,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(assistantControllerProvider);

    return AssistantSwitcher<AssistantKind>(
      selected: selected,
      tooltip: l10n.assistantSwitcher,
      options: [
        for (final k in AssistantKind.values)
          SegmentOption(value: k, icon: _icons[k]!, label: _label(l10n, k)),
      ],
      onSelect: (k) => _onSelect(context, ref, k),
    );
  }

  /// 文案走 arb。用 switch 而非 Map：加第五个助理时这里会显形。
  String _label(AppLocalizations l10n, AssistantKind k) => switch (k) {
        AssistantKind.pentest => l10n.assistantPentest,
        AssistantKind.defense => l10n.assistantDefense,
        AssistantKind.contest => l10n.assistantContest,
        AssistantKind.office => l10n.assistantOffice,
      };

  /// 切助理 = 换 scene 开一轮新对话，中栏随之回到该助理的空态。
  ///
  /// 与左栏点历史助理走**同一条**路（[ChatController.newChatWithScene]），
  /// 不另开一套切换逻辑 —— 否则两个入口会切出不同的状态。
  void _onSelect(BuildContext context, WidgetRef ref, AssistantKind kind) {
    ref.read(assistantControllerProvider.notifier).select(kind);
    ref.read(chatControllerProvider.notifier).newChatWithScene(kind.sceneId);
  }
}
