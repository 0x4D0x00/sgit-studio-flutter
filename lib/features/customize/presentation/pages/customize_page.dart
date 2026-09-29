import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

import 'package:sgit_studio_flutter/ui/components/confirm.dart';

import '../../application/customize_page_controller.dart';
import '../widgets/customize_models.dart';
import '../widgets/customize_sample_data.dart';
import '../widgets/customize_section_header.dart';
import '../widgets/customize_toolbar.dart';
import '../widgets/pill_tab_bar.dart';
import '../widgets/skill_card.dart';
import '../widgets/connector_card.dart';
import '../widgets/connectors_banner.dart';
import '../widgets/yours_list_item.dart';
import '../widgets/yours_connector_table.dart';

/// Customize 页面 - Skills, Connectors, Plugins 等自定义内容
class CustomizePage extends ConsumerStatefulWidget {
  const CustomizePage({super.key});

  @override
  ConsumerState<CustomizePage> createState() => _CustomizePageState();
}

class _CustomizePageState extends ConsumerState<CustomizePage> {
  // 当前标签（Skills/Connectors/Plugins）放在 provider 里，而不是本地
  // State —— 设置弹窗要能在用户已经停在 Customize 页面时直接切换这个标签。
  int _selectedViewIndex = 4; // Discover

  final _searchController = TextEditingController();
  String _query = '';

  // Skills + Yours 列表的数据。用 State 字段而不是局部变量，
  // 这样点「···」→ Remove 才能真的从列表里删掉一项。
  late final List<Map<String, Object>> _yoursSkills = buildYoursSkills();

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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<T> _filterBy<T>(List<T> items, String Function(T) titleOf) {
    if (_query.isEmpty) return items;
    final q = _query.toLowerCase();
    return items
        .where((item) => titleOf(item).toLowerCase().contains(q))
        .toList(growable: false);
  }

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

    return Scaffold(
      backgroundColor: skin.baseBg,
      body: Column(
        children: [
          _buildHeader(context, skin),
          Expanded(
            child: _buildContent(context, skin, AppLocalizations.of(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppSkin skin) {
    final l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: skin.baseBg,
        border: Border(
          bottom: BorderSide(
            color: skin.border,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
            const EdgeInsetsGeometry.all(AppSpacing.md),
            child: Text(
              'Customize',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: skin.text,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: CustomizeToolbar(
              tabs: PillTabBar(tabs: _buildTabs()),
              searchController: _searchController,
              query: _query,
              onQueryChanged: (v) => setState(() => _query = v),
              onTune: () => _notWired(context, l10n, 'category'),
              onSort: () => _notWired(context, l10n, 'sort'),
              onAdd: () => _notWired(context, l10n, l10n.commonAdd),
            ),
          ),
        ],
      ),
    );
  }

  List<PillTab> _buildTabs() {
    final labels = ['Skills', 'Connectors', 'Plugins'];
    final tabs = CustomizeTab.values;
    final selectedTab = ref.watch(customizeTabControllerProvider);
    final tabController = ref.read(customizeTabControllerProvider.notifier);
    return [
      for (var i = 0; i < labels.length; i++)
        PillTab(
          label: labels[i],
          selected: selectedTab == tabs[i],
          onTap: () => tabController.setTab(tabs[i]),
        ),
      PillTab(
        label: 'Yours',
        selected: _selectedViewIndex == 3,
        onTap: () => setState(() => _selectedViewIndex = 3),
        dividerBefore: true,
      ),
      PillTab(
        label: 'Discover',
        selected: _selectedViewIndex == 4,
        onTap: () => setState(() => _selectedViewIndex = 4),
      ),
    ];
  }

  Widget _buildContent(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    // 判断是 Yours 还是 Discover 视图
    final isYoursView = _selectedViewIndex == 3;
    final selectedTab = ref.watch(customizeTabControllerProvider);

    if (selectedTab == CustomizeTab.connectors) {
      // Connectors
      if (isYoursView) {
        return _buildConnectorsYoursContent(context, skin, l10n);
      } else {
        return _buildConnectorsDiscoverContent(context, skin, l10n);
      }
    } else {
      // Skills / Plugins
      if (isYoursView) {
        return _buildSkillsYoursContent(context, skin, l10n);
      } else {
        return _buildSkillsDiscoverContent(context, skin, l10n);
      }
    }
  }

  // Skills/Plugins + Discover 页面：显示 "For you" + "New" 区域
  Widget _buildSkillsDiscoverContent(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        CustomizeSectionHeader('For you'),
        const SizedBox(height: AppSpacing.md),
        _buildSkillsGrid(context, skin, l10n),
        const SizedBox(height: AppSpacing.md),
        CustomizeSectionHeader(
          'New',
          showSeeAll: true,
          onSeeAll: () => _notWired(context, l10n, 'See all'),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildNewSkillsRow(context, skin, l10n),
      ],
    );
  }

  // Skills/Plugins + Yours 页面：显示列表样式
  Widget _buildSkillsYoursContent(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    final filtered = _filterBy(_yoursSkills, (s) => s['title'] as String);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: skin.border,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'From Anthropic & Partners',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: skin.text,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No skills found',
                    style: TextStyle(
                      fontSize: 14,
                      color: skin.textSecondary,
                    ),
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

  // Connectors + Discover 页面：显示带轮播图的页面
  Widget _buildConnectorsDiscoverContent(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    final connectors = buildConnectors();
    final filtered = _filterBy(connectors, (c) => c.title);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        ConnectorsPromoBanner(
          skin: skin,
          onExplore: () => _notWired(context, l10n, 'Explore'),
        ),
        const SizedBox(height: AppSpacing.lg),
        CustomizeSectionHeader(
          'Top connectors',
          showSeeAll: true,
          seeAllLabel: 'Show all',
          onSeeAll: () => _notWired(context, l10n, 'Show all'),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildConnectorsWrap(context, filtered, skin, l10n),
      ],
    );
  }

  // Connectors + Yours 页面：显示表格样式
  Widget _buildConnectorsYoursContent(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    final connectors = buildYoursConnectors();
    final filtered = _filterBy(connectors, (c) => c.name);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: filtered.isEmpty
          ? Center(
              child: Text(
                'No connectors found',
                style: TextStyle(
                  fontSize: 14,
                  color: skin.textSecondary,
                ),
              ),
            )
          : YoursConnectorTable(
              skin: skin,
              connectors: filtered,
              onConnect: (connector) => _notWired(context, l10n, connector.name),
            ),
    );
  }

  Widget _buildConnectorsWrap(
    BuildContext context,
    List<ConnectorItem> items,
    AppSkin skin,
    AppLocalizations l10n,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= _minCardWidth * 2 + AppSpacing.md;
        final width = twoColumns
            ? (constraints.maxWidth - AppSpacing.md) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: items.map((connector) {
            return SizedBox(
              width: width,
              child: ConnectorCard(
                connector: connector,
                skin: skin,
                l10n: l10n,
                onTap: () => _notWired(context, l10n, connector.title),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSkillsGrid(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    final filtered = _filterBy(buildForYouSkills(), (s) => s.title);
    return _buildSkillsWrap(context, filtered, skin, l10n);
  }

  /// 一张卡片最少需要这么宽才放得下图标+文案+加号按钮，窄于此就退成单列，否则内容溢出
  static const double _minCardWidth = 280;

  Widget _buildSkillsWrap(
    BuildContext context,
    List<SkillItem> items,
    AppSkin skin,
    AppLocalizations l10n,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= _minCardWidth * 2 + AppSpacing.md;
        final width = twoColumns
            ? (constraints.maxWidth - AppSpacing.md) / 2
            : constraints.maxWidth;
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
                onTap: () => _notWired(context, l10n, '点击跳转'),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildNewSkillsRow(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    final filtered = _filterBy(buildNewSkills(), (s) => s.title);
    return _buildSkillsWrap(context, filtered, skin, l10n);
  }
}
