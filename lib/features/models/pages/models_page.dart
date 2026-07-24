import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_page.dart';

/// 大模型中转站:模型更新。骨架占位。
class ModelsPage extends StatelessWidget {
  const ModelsPage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderPage(
        title: AppLocalizations.of(context).navModels,
        icon: Icons.hub_rounded,
      );
}
