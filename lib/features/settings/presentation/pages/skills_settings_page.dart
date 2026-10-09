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

/// 设置弹窗里的 Skills 页面：与顶层 Customize 路由页的 Skills 内容一致，
/// 复用同一套工具条/卡片/列表组件，只是嵌在设置弹窗内（不带 Scaffold）。
class SkillsSettingsPage extends StatefulWidget {
  const SkillsSettingsPage({super.key});

  @override
  State<SkillsSettingsPage> createState() => _SkillsSettingsPageState();
}

class _SkillsSettingsPageState extends State<SkillsSettingsPage> {
  bool _isYoursView = false; // 默认 Discover
  final _searchController = TextEditingController();
  String _query = '';

  late final List<Map<String, Object>> _yoursSkills = buildYoursSkills();

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

  Future<void> _removeYoursSkill(Map<String, Object> skill) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDanger(
      context,
      title: l10n.studioRemoveConfirm(skill['title'] as String),
      confirmText: l10n.commonDelete,
    );
    if (!ok) return;

    setState(() => _yoursSkills.remove(skill));
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
    final filtered = _filterBy(_yoursSkills, (s) => s['title'] as String);

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
                    'No skills found',
                    style: TextStyle(fontSize: 14, color: skin.textSecondary),
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final skill = filtered[index];
                    return YoursListItem(
                      icon: skill['icon'] as IconData,
                      title: skill['title'] as String,
                      source: skill['source'] as String,
                      description: skill['description'] as String,
                      timeAgo: skill['timeAgo'] as String,
                      skin: skin,
                      onTap: () => _notWired(context, l10n, skill['title'] as String),
                      onRemove: () => _removeYoursSkill(skill),
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
        _buildWrap(context, _filterBy(buildForYouSkills(), (s) => s.title), skin, l10n),
        const SizedBox(height: AppSpacing.md),
        CustomizeSectionHeader(
          'New',
          showSeeAll: true,
          onSeeAll: () => _notWired(context, l10n, 'See all'),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildWrap(context, _filterBy(buildNewSkills(), (s) => s.title), skin, l10n),
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
          children: items.map((skill) {
            return SizedBox(
              width: width,
              child: SkillCard(
                skill: skill,
                skin: skin,
                l10n: l10n,
                onTap: () => _notWired(context, l10n, skill.title),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
