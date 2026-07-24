import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_page.dart';

/// API Key 管理:录入、清理。骨架占位。
class ApiKeysPage extends StatelessWidget {
  const ApiKeysPage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderPage(
        title: AppLocalizations.of(context).navApiKeys,
        icon: Icons.vpn_key_rounded,
      );
}
