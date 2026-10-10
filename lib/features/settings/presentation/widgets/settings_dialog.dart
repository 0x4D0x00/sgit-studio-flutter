import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/customize/application/customize_page_controller.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/account_page.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/privacy_page.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/billing_page.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/capabilities_page.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/memory_page.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/reflect_page.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/time_focus_page.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/settings_placeholder_page.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/skills_settings_page.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/connectors_settings_page.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/plugins_settings_page.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/router/route_names.dart';

enum _SettingsTab {
  general,
  account,
  privacy,
  billing,
  capabilities,
  memory,
  reflect,
  timeFocus,
  claudeCode,
  skills,
  connectors,
  plugins,
}

/// 设置弹窗外壳：盖在当前页上方的大号弹窗，左侧分类栏 + 右侧内容 + 右上角关闭。
Future<void> showSettingsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _SettingsDialog(),
  );
}

class _SettingsDialog extends ConsumerStatefulWidget {
  const _SettingsDialog();

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  _SettingsTab _selectedTab = _SettingsTab.general;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sidebar(skin, l10n),
            VerticalDivider(width: 1, thickness: 1, color: skin.borderSecondary),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 48,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: IconButton(
                          icon: Icon(Icons.close, color: skin.textSecondary),
                          tooltip: l10n.commonClose,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        0,
                        AppSpacing.sm,
                        AppSpacing.sm,
                      ),
                      child: _buildCurrentPage(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 技能/连接器/插件项被点：如果中栏当前正显示 Customize 页面，直接切换
  /// 那边的标签并关掉本弹窗；否则按老样子在弹窗内自己渲染对应内容。
  void _onCustomizeItemTap(_SettingsTab tab) {
    final customizeTab = switch (tab) {
      _SettingsTab.skills => CustomizeTab.skills,
      _SettingsTab.connectors => CustomizeTab.connectors,
      _SettingsTab.plugins => CustomizeTab.plugins,
      _ => null,
    };
    if (customizeTab == null) return;

    // 直接问路由当前在哪一页，靠 CustomizePage 的 mount/unmount 去维护
    // 额外的标记时机不可靠。
    // 用 `GoRouter.of(context).routerDelegate.currentConfiguration` 而不是
    // `GoRouterState.of(context)`：本弹窗是 `showDialog` 开出来的独立路由，
    // 它的 `ModalRoute` 不是 go_router 的 Page，`GoRouterState.of` 在这里
    // 找不到关联状态会直接抛异常。
    final currentPath =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    final isCustomizeActive = currentPath == RouteNames.customize;
    if (isCustomizeActive) {
      ref.read(customizeTabControllerProvider.notifier).setTab(customizeTab);
      Navigator.of(context).pop();
      return;
    }

    setState(() => _selectedTab = tab);
  }

  Widget _buildCurrentPage() {
    switch (_selectedTab) {
      case _SettingsTab.general:
        return const SettingsPage();
      case _SettingsTab.account:
        return const AccountPage();
      case _SettingsTab.privacy:
        return const PrivacyPage();
      case _SettingsTab.billing:
        return const BillingPage();
      case _SettingsTab.memory:
        return const MemoryPage();
      case _SettingsTab.reflect:
        return ReflectPage(
          onOpenMemorySettings: () => setState(() => _selectedTab = _SettingsTab.memory),
        );
      case _SettingsTab.timeFocus:
        return const TimeFocusPage();
      case _SettingsTab.skills:
        return const SkillsSettingsPage();
      case _SettingsTab.connectors:
        return const ConnectorsSettingsPage();
      case _SettingsTab.plugins:
        return const PluginsSettingsPage();
      case _SettingsTab.capabilities:
        // 「技能已移至 Customize」里的链接走与侧栏「技能」项相同的分流：
        // 中栏在 Customize 就切过去并关掉弹窗，否则在弹窗内切到「技能」页。
        return CapabilitiesPage(
          onOpenSkills: () => _onCustomizeItemTap(_SettingsTab.skills),
        );
      case _SettingsTab.claudeCode:
        return const SettingsPlaceholderPage();
    }
  }

  Widget _sidebar(AppSkin skin, AppLocalizations l10n) {
    final items = [
      _SidebarItemData(
        icon: Icons.settings_outlined,
        label: l10n.settingsGeneral,
        tab: _SettingsTab.general,
      ),
      _SidebarItemData(
        icon: Icons.person_outlined,
        label: l10n.settingsAccount,
        tab: _SettingsTab.account,
      ),
      _SidebarItemData(
        icon: Icons.shield_outlined,
        label: l10n.settingsPrivacy,
        tab: _SettingsTab.privacy,
      ),
      _SidebarItemData(
        icon: Icons.receipt_outlined,
        label: l10n.settingsBilling,
        tab: _SettingsTab.billing,
      ),
      _SidebarItemData(
        icon: Icons.auto_awesome_outlined,
        label: l10n.settingsCapabilities,
        tab: _SettingsTab.capabilities,
      ),
      _SidebarItemData(
        icon: Icons.psychology_outlined,
        label: l10n.settingsMemory,
        tab: _SettingsTab.memory,
      ),
      _SidebarItemData(
        icon: Icons.wb_twilight_outlined,
        label: l10n.settingsReflect,
        tab: _SettingsTab.reflect,
      ),
      _SidebarItemData(
        icon: Icons.schedule_outlined,
        label: l10n.settingsTimeFocus,
        tab: _SettingsTab.timeFocus,
      ),
      _SidebarItemData(
        icon: Icons.code_outlined,
        label: l10n.settingsClaudeCode,
        tab: _SettingsTab.claudeCode,
      ),
    ];

    final customizeItems = [
      _SidebarItemData(
        icon: Icons.extension_outlined,
        label: l10n.settingsSkills,
        tab: _SettingsTab.skills,
      ),
      _SidebarItemData(
        icon: Icons.link_outlined,
        label: l10n.settingsConnectors,
        tab: _SettingsTab.connectors,
      ),
      _SidebarItemData(
        icon: Icons.widgets_outlined,
        label: l10n.settingsPlugins,
        tab: _SettingsTab.plugins,
      ),
    ];

    final filteredItems = _filterItems(items);
    final filteredCustomizeItems = _filterItems(customizeItems);

    return SizedBox(
      width: 220,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _searchBox(skin, l10n),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _sectionHeader(skin, l10n.settingsTitle),
                  ...filteredItems.map((item) => _SidebarItem(
                        icon: item.icon,
                        label: item.label,
                        skin: skin,
                        selected: _selectedTab == item.tab,
                        onTap: () => setState(() => _selectedTab = item.tab),
                      )),
                  const SizedBox(height: AppSpacing.sm),
                  _sectionHeader(skin, l10n.settingsCustomize),
                  ...filteredCustomizeItems.map((item) => _SidebarItem(
                        icon: item.icon,
                        label: item.label,
                        skin: skin,
                        selected: _selectedTab == item.tab,
                        onTap: () => _onCustomizeItemTap(item.tab),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchBox(AppSkin skin, AppLocalizations l10n) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: skin.border),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        autofocus: true,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(fontSize: 14, color: skin.text),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: skin.textSecondary,
          ),
          hintText: l10n.settingsSearch,
          hintStyle: TextStyle(
            fontSize: 14,
            color: skin.textTertiary,
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(AppSkin skin, String text) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        bottom: AppSpacing.xs,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: skin.textTertiary,
        ),
      ),
    );
  }

  List<_SidebarItemData> _filterItems(List<_SidebarItemData> items) {
    if (_searchQuery.isEmpty) return items;
    final query = _searchQuery.toLowerCase();
    return items
        .where((item) => item.label.toLowerCase().contains(query))
        .toList();
  }
}

class _SidebarItemData {
  const _SidebarItemData({
    required this.icon,
    required this.label,
    required this.tab,
  });

  final IconData icon;
  final String label;
  final _SettingsTab tab;
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
              color: selected ? skin.text.withValues(alpha: 0.06) : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: skin.text),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: skin.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
