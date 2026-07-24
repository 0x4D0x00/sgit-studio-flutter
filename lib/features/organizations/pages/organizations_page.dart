import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_page.dart';

/// 组织架构分配。骨架占位。
class OrganizationsPage extends StatelessWidget {
  const OrganizationsPage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderPage(
        title: AppLocalizations.of(context).navOrganizations,
        icon: Icons.account_tree_rounded,
      );
}
