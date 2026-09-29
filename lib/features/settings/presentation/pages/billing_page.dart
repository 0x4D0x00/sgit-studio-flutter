import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 设置弹窗里的 Billing 页面:当前方案卡片 + 升级按钮 + 功能清单。
class BillingPage extends StatelessWidget {
  const BillingPage({super.key});

  void _notWired(BuildContext context, AppLocalizations l10n, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.commonNotWired(what)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);

    final features = [
      l10n.billingFeatureChatPlatforms,
      l10n.billingFeatureGenerateCode,
      l10n.billingFeatureWriteEdit,
      l10n.billingFeatureSearchWeb,
      l10n.billingFeatureMemory,
      l10n.billingFeatureCreateFiles,
      l10n.billingFeatureDesktopExtensions,
      l10n.billingFeatureConnectWorkspace,
      l10n.billingFeatureConnectors,
      l10n.billingFeatureExtendedThinking,
    ];

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: skin.border),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.auto_awesome_outlined, size: 20, color: skin.text),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.billingFreePlan,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: skin.text,
                    ),
                  ),
                  Text(
                    l10n.billingTryClaude,
                    style: TextStyle(fontSize: 13, color: skin.textSecondary),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => _notWired(context, l10n, l10n.billingUpgradePlan),
              style: FilledButton.styleFrom(
                backgroundColor: skin.text,
                foregroundColor: skin.containerBg,
              ),
              child: Text(l10n.billingUpgradePlan),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final feature in features)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_rounded, size: 18, color: skin.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    feature,
                    style: TextStyle(fontSize: 14, color: skin.text),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
