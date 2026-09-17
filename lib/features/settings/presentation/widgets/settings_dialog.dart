import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/account_page.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

enum _SettingsTab { general, account }

/// 设置弹窗外壳：盖在当前页上方的大号弹窗，左侧分类栏 + 右侧内容 + 右上角关闭。
Future<void> showSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _SettingsDialog(),
  );
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  _SettingsTab _selectedTab = _SettingsTab.general;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.sizeOf(context);
    final width = math.min(800.0, size.width * 0.9);
    final height = math.min(660.0, size.height * 0.8);

    return Dialog(
      backgroundColor: skin.containerBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: skin.border),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sidebar(skin, l10n),
                VerticalDivider(width: 1, thickness: 1, color: skin.borderSecondary),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: _buildCurrentPage(),
                  ),
                ),
              ],
            ),
            Positioned(
              top: AppSpacing.sm,
              right: AppSpacing.sm,
              child: IconButton(
                icon: Icon(Icons.close, color: skin.textSecondary),
                tooltip: l10n.commonClose,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_selectedTab) {
      case _SettingsTab.general:
        return const SettingsPage();
      case _SettingsTab.account:
        return const AccountPage();
    }
  }

  Widget _sidebar(AppSkin skin, AppLocalizations l10n) => SizedBox(
        width: 220,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  l10n.settingsTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: skin.textTertiary,
                  ),
                ),
              ),
              _SidebarItem(
                icon: Icons.settings_outlined,
                label: l10n.settingsGeneral,
                skin: skin,
                selected: _selectedTab == _SettingsTab.general,
                onTap: () => setState(() => _selectedTab = _SettingsTab.general),
              ),
              const SizedBox(height: AppSpacing.xs),
              _SidebarItem(
                icon: Icons.person_outlined,
                label: l10n.settingsAccount,
                skin: skin,
                selected: _selectedTab == _SettingsTab.account,
                onTap: () => setState(() => _selectedTab = _SettingsTab.account),
              ),
            ],
          ),
        ),
      );
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.skin,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final AppSkin skin;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: selected ? skin.navItemActive : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: skin.text),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: skin.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
