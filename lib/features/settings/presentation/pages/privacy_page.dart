import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_section.dart';

class PrivacyPage extends ConsumerStatefulWidget {
  const PrivacyPage({super.key});

  @override
  ConsumerState<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends ConsumerState<PrivacyPage> {
  bool _locationMetadata = true;
  bool _improveModels = true;

  void _notWired(String what) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.commonNotWired(what)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Privacy title
        SettingsSectionHeader(l10n.privacyTitle),
        const SizedBox(height: AppSpacing.md),

        // Privacy intro with links
        RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            children: [
              TextSpan(
                text: 'Anthropic believes in transparent data practices. Learn how your information is protected when using Anthropic products, and visit our ',
              ),
              WidgetSpan(
                child: InkWell(
                  onTap: () => _notWired(l10n.privacyCenter),
                  child: Text(
                    l10n.privacyCenter,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              TextSpan(text: ' and '),
              WidgetSpan(
                child: InkWell(
                  onTap: () => _notWired(l10n.privacyPolicy),
                  child: Text(
                    l10n.privacyPolicy,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              TextSpan(text: ' for more details.'),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // How we protect your data
        SettingsSectionRow(
          title: l10n.privacyProtectData,
          onTap: () => _notWired(l10n.privacyProtectData),
          trailing: Icon(
            Icons.chevron_right,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        const SettingsSectionDivider(),

        // How we use your data
        SettingsSectionRow(
          title: l10n.privacyUseData,
          onTap: () => _notWired(l10n.privacyUseData),
          trailing: Icon(
            Icons.chevron_right,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Preferences section
        SettingsSectionHeader(l10n.privacyPreferences),
        const SizedBox(height: AppSpacing.sm),

        // Location metadata toggle
        SettingsSectionRowWithDesc(
          title: l10n.privacyLocationMetadata,
          description: 'Allow SGIT to use coarse location metadata (city/region) to improve product experiences. Learn more.',
          trailing: Switch(
            value: _locationMetadata,
            onChanged: (value) => setState(() => _locationMetadata = value),
          ),
        ),

        const SettingsSectionDivider(),

        // Help improve our AI models toggle
        SettingsSectionRowWithDesc(
          title: l10n.privacyImproveModels,
          description: 'Allow the use of your chats and coding sessions to train and improve Anthropic AI models. Learn more.',
          trailing: Switch(
            value: _improveModels,
            onChanged: (value) => setState(() => _improveModels = value),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Your data section
        SettingsSectionHeader(l10n.privacyYourData),
        const SizedBox(height: AppSpacing.sm),

        // Export data
        SettingsSectionRow(
          title: l10n.privacyExportData,
          trailing: _ActionButton(
            label: l10n.privacyExportDataButton,
            onPressed: () => _notWired(l10n.privacyExportDataButton),
          ),
        ),

        const SettingsSectionDivider(),

        // Shared chats
        SettingsSectionRow(
          title: l10n.privacySharedChats,
          trailing: _ActionButton(
            label: l10n.privacyManage,
            onPressed: () => _notWired(l10n.privacySharedChats),
          ),
        ),

        const SettingsSectionDivider(),

        // Shared artifacts
        SettingsSectionRow(
          title: l10n.privacySharedArtifacts,
          trailing: _ActionButton(
            label: l10n.privacyManage,
            onPressed: () => _notWired(l10n.privacySharedArtifacts),
          ),
        ),

        const SettingsSectionDivider(),

        // Uploaded files
        SettingsSectionRow(
          title: l10n.privacyUploadedFiles,
          trailing: _ActionButton(
            label: l10n.privacyManage,
            onPressed: () => _notWired(l10n.privacyUploadedFiles),
          ),
        ),

        const SettingsSectionDivider(),

        // Your feedback
        SettingsSectionRow(
          title: l10n.privacyYourFeedback,
          trailing: _ActionButton(
            label: l10n.privacyManage,
            onPressed: () => _notWired(l10n.privacyYourFeedback),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Text(label),
    );
  }
}
