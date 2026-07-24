import 'package:flutter/material.dart';

import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_spacing.dart';

/// 模块占位页(骨架用)。标题 + "功能开发中"。各 feature 落地后替换为真实页面。
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xl),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.commonComingSoon,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
