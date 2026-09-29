import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_section.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 设置弹窗里的 Reflect 页面:未开启记忆时提示先去记忆设置里开启。
class ReflectPage extends StatefulWidget {
  const ReflectPage({super.key, this.onOpenMemorySettings});

  /// 点击"记忆设置"链接时触发，用于跳转到设置弹窗的 Memory 页面。
  final VoidCallback? onOpenMemorySettings;

  @override
  State<ReflectPage> createState() => _ReflectPageState();
}

class _ReflectPageState extends State<ReflectPage> {
  late final TapGestureRecognizer _memorySettingsTap;

  @override
  void initState() {
    super.initState();
    _memorySettingsTap = TapGestureRecognizer()
      ..onTap = widget.onOpenMemorySettings;
  }

  @override
  void dispose() {
    _memorySettingsTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SettingsSectionHeader(l10n.reflectTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.reflectDesc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.back_hand_outlined, size: 40, color: skin.textTertiary),
                const SizedBox(height: AppSpacing.md),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      children: [
                        TextSpan(text: l10n.reflectEnableMemoryHintPrefix),
                        TextSpan(
                          text: l10n.reflectMemorySettingsLink,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: _memorySettingsTap,
                          mouseCursor: SystemMouseCursors.click,
                        ),
                        TextSpan(text: l10n.reflectEnableMemoryHintSuffix),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
