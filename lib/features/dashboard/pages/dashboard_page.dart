import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderPage(
        title: AppLocalizations.of(context).navDashboard,
        icon: Icons.dashboard_rounded,
      );
}
