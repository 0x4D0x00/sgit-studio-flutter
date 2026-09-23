import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// Placeholder page for unimplemented settings categories.
class SettingsPlaceholderPage extends StatelessWidget {
  const SettingsPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction_outlined,
            size: 64,
            color: skin.textTertiary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.settingsComingSoon,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: skin.text,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.settingsComingSoonDesc,
            style: TextStyle(
              fontSize: 14,
              color: skin.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
