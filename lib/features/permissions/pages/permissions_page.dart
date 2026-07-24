import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../shared/widgets/placeholder_page.dart';

/// 权限分配:菜单权限 + 文件权限。骨架占位。
class PermissionsPage extends StatelessWidget {
  const PermissionsPage({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderPage(
        title: AppLocalizations.of(context).navPermissions,
        icon: Icons.shield_rounded,
      );
}
