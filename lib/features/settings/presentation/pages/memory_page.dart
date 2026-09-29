import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_section.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 设置弹窗里的 Memory 页面:是否允许 Claude 从对话中生成记忆。
class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  bool _generateFromChats = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        SettingsSectionHeader(l10n.memoryTitle),
        const SizedBox(height: AppSpacing.sm),
        SettingsSectionRowWithDesc(
          title: l10n.memoryGenerateFromChats,
          description: l10n.memoryGenerateFromChatsDesc(l10n.memoryGenerateFromChatsLearnMore),
          trailing: Switch(
            value: _generateFromChats,
            onChanged: (value) => setState(() => _generateFromChats = value),
          ),
        ),
      ],
    );
  }
}
