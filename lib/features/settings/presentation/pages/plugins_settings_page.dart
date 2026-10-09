import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/confirm.dart';

import 'package:sgit_studio_flutter/features/customize/presentation/widgets/customize_models.dart';
import 'package:sgit_studio_flutter/features/customize/presentation/widgets/customize_sample_data.dart';
import 'package:sgit_studio_flutter/features/customize/presentation/widgets/customize_section_header.dart';
import 'package:sgit_studio_flutter/features/customize/presentation/widgets/customize_toolbar.dart';
import 'package:sgit_studio_flutter/features/customize/presentation/widgets/pill_tab_bar.dart';
import 'package:sgit_studio_flutter/features/customize/presentation/widgets/skill_card.dart';
import 'package:sgit_studio_flutter/features/customize/presentation/widgets/yours_list_item.dart';

/// 设置弹窗里的 Plugins 页面：结构与 [SkillsSettingsPage] 完全一致
/// （同样用 YoursListItem/SkillCard），只是数据源换成 plugins。
class PluginsSettingsPage extends StatefulWidget {
  const PluginsSettingsPage({super.key});

  @override
  State<PluginsSettingsPage> createState() => _PluginsSettingsPageState();
}

class _PluginsSettingsPageState extends State<PluginsSettingsPage> {
  bool _isYoursView = false; // 默认 Discover
  final _searchController = TextEditingController();
  String _query = '';

  late final List<Map<String, Object>> _yoursPlugins = buildYoursPlugins();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<T> _filterBy<T>(List<T> items, String Function(T) titleOf) {
    if (_query.isEmpty) return items;
    final q = _query.toLowerCase();
    return items.where((item) => titleOf(item).toLowerCase().contains(q)).toList(growable: false);
  }

  void _notWired(BuildContext context, AppLocalizations l10n, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.commonNotWired(what)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _removeYoursPlugin(Map<String, Object> plugin) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDanger(
      context,
      title: l10n.studioRemoveConfirm(plugin['title'] as String),
      confirmText: l10n.commonDelete,
    );
    if (!ok) return;

    setState(() => _yoursPlugins.remove(plugin));
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: CustomizeToolbar(
            tabs: PillTabBar(
              tabs: [
                PillTab(
                  label: 'Yours',
                  selected: _isYoursView,
                  onTap: () => setState(() => _isYoursView = true),
                ),
                PillTab(
                  label: 'Discover',
                  selected: !_isYoursView,
                  onTap: () => setState(() => _isYoursView = false),
                ),
              ],
            ),
            searchController: _searchController,
            query: _query,
            searchHint: 'Search skills and plugins...',
            onQueryChanged: (v) => setState(() => _query = v),
            onTune: () => _notWired(context, l10n, 'category'),
            onSort: () => _notWired(context, l10n, 'sort'),
            onAdd: () => _notWired(context, l10n, l10n.commonAdd),
          ),
        ),
        Expanded(
          child: _isYoursView
              ? _buildYoursContent(context, skin, l10n)
              : _buildDiscoverContent(context, skin, l10n),
        ),
      ],
    );
  }

  Widget _buildYoursContent(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    final filtered = _filterBy(_yoursPlugins, (p) => p['title'] as String);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: skin.border, width: 0.5)),
          ),
          child: Row(
            children: [
              Text(
                'From Anthropic & Partners',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: skin.text),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No plugins found',
                    style: TextStyle(fontSize: 14, color: skin.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final plugin = filtered[index];
                    return YoursListItem(
                      icon: plugin['icon'] as IconData,
                      title: plugin['title'] as String,
                      source: plugin['source'] as String,
                      description: plugin['description'] as String,
                      timeAgo: plugin['timeAgo'] as String,
                      tags: (plugin['tags'] as List<String>?) ?? const ['Data'],
                      skin: skin,
                      onTap: () => _notWired(context, l10n, plugin['title'] as String),
                      onRemove: () => _removeYoursPlugin(plugin),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDiscoverContent(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    return ListView(
      children: [
        const CustomizeSectionHeader('For you'),
        const SizedBox(height: AppSpacing.md),
        _buildWrap(context, _filterBy(buildForYouPlugins(), (s) => s.title), skin, l10n),
        const SizedBox(height: AppSpacing.md),
        CustomizeSectionHeader(
          'New plugins',
          showSeeAll: true,
          onSeeAll: () => _notWired(context, l10n, 'Show all'),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildWrap(context, _filterBy(buildNewPlugins(), (s) => s.title), skin, l10n),
      ],
    );
  }

  static const double _minCardWidth = 260;

  Widget _buildWrap(
    BuildContext context,
    List<SkillItem> items,
    AppSkin skin,
    AppLocalizations l10n,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= _minCardWidth * 2 + AppSpacing.md;
        final width = twoColumns ? (constraints.maxWidth - AppSpacing.md) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: items.map((plugin) {
            return SizedBox(
              width: width,
              child: SkillCard(
                skill: plugin,
                skin: skin,
                l10n: l10n,
                onTap: () => _notWired(context, l10n, plugin.title),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
