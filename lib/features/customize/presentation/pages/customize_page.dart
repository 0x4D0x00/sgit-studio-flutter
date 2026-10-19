import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

import 'package:sgit_studio_flutter/ui/components/confirm.dart';

import '../../application/customize_page_controller.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/pages/studio_page.dart';
import '../widgets/customize_models.dart';
import '../widgets/customize_sample_data.dart';
import '../widgets/customize_section_header.dart';
import '../widgets/customize_show_all_view.dart';
import '../widgets/customize_toolbar.dart';
import '../widgets/pill_tab_bar.dart';
import '../widgets/responsive_card_wrap.dart';
import '../widgets/skill_card.dart';
import '../widgets/skill_library.dart';
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

  // 「Show all」进入的全量列表：'New skills' / 'New plugins' / 'All connectors'，
  // null 表示停在 Discover。三个 Tab 共用，切 Tab 时由 _buildTabs 清掉。
  String? _showAllTitle;
  final _showAllSearchController = TextEditingController();
  String _showAllQuery = '';

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
    _showAllSearchController.dispose();
    super.dispose();
  }

  List<T> _filterBy<T>(List<T> items, String Function(T) titleOf) {
    if (_query.isEmpty) return items;
    final q = _query.toLowerCase();
    return items
        .where((item) => titleOf(item).toLowerCase().contains(q))
        .toList(growable: false);
  }

  /// 全量列表自己的搜索词过滤。不做搜索时直接返回原列表。
  List<T> _filterShowAll<T>(List<T> items, String Function(T) titleOf) {
    if (_showAllQuery.isEmpty) return items;
    final q = _showAllQuery.toLowerCase();
    return items
        .where((item) => titleOf(item).toLowerCase().contains(q))
        .toList(growable: false);
  }

  /// 从全量列表退回 Discover，顺带清掉自己的搜索词。
  void _exitShowAll() {
    _showAllTitle = null;
    _showAllQuery = '';
    _showAllSearchController.clear();
  }

  void _openShowAll(String title) {
    setState(() {
      _showAllTitle = title;
      _showAllQuery = '';
      _showAllSearchController.clear();
    });
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

    // 全量列表自带头部（返回箭头 + 分类 chip + 大标题 + 工具条），
    // 这时不画 "Customize" 标题和标签行，否则两套搜索框会叠在一起。
    if (_showAllTitle != null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: skin.baseBg,
        border: Border(bottom: BorderSide(color: skin.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsGeometry.all(AppSpacing.md),
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
              tabs: PillTabBar(tabs: _buildTabs(l10n)),
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

  /// 页签文案。**全部走 l10n**，不写死字面量 —— 这个页面同时显示
  /// 「自定义」内容（技能/连接器/插件）与 sgcode 的智能体配置页，
  /// 两套文案各有自己的键。
  String _tabLabel(CustomizeTab tab, AppLocalizations l10n) => switch (tab) {
    CustomizeTab.skills => l10n.studioSkill,
    CustomizeTab.connectors => l10n.customizeTabConnectors,
    CustomizeTab.plugins => l10n.customizeTabPlugins,
    CustomizeTab.scenes => l10n.studioScenes,
    CustomizeTab.subagent => l10n.studioSubagent,
    CustomizeTab.mcp => l10n.studioMcp,
    CustomizeTab.tools => l10n.studioTools,
    CustomizeTab.knowledge => l10n.studioKnowledge,
    CustomizeTab.llmRelay => l10n.studioLlmRelay,
    CustomizeTab.apiKey => l10n.studioApiKey,
  };

  List<PillTab> _buildTabs(AppLocalizations l10n) {
    final selectedTab = ref.watch(customizeTabControllerProvider);
    final tabController = ref.read(customizeTabControllerProvider.notifier);

    return [
      // 自定义内容（LobeChat 那套）
      for (final tab in CustomizeTab.values.where((t) => t.isCustomizeContent))
        PillTab(
          label: _tabLabel(tab, l10n),
          selected: selectedTab == tab,
          onTap: () {
            tabController.setTab(tab);
            setState(_exitShowAll);
          },
        ),
      // sgcode 智能体配置页。与上面一组之间加一道分隔 ——
      // 它们读的是完全不同的真源（本地 .sgitai vs 样例数据）。
      for (final tab in CustomizeTab.values.where((t) => !t.isCustomizeContent))
        PillTab(
          label: _tabLabel(tab, l10n),
          selected: selectedTab == tab,
          onTap: () {
            tabController.setTab(tab);
            setState(_exitShowAll);
          },
          dividerBefore: tab == CustomizeTab.scenes,
        ),
      // Yours / Discover 只属于「自定义」内容；智能体配置页没有这两个视角。
      if (selectedTab.isCustomizeContent) ...[
        PillTab(
          label: l10n.customizeTabYours,
          selected: _selectedViewIndex == 3,
          onTap: () => setState(() {
            _selectedViewIndex = 3;
            _exitShowAll();
          }),
          dividerBefore: true,
        ),
        PillTab(
          label: l10n.customizeTabDiscover,
          selected: _selectedViewIndex == 4,
          onTap: () => setState(() {
            _selectedViewIndex = 4;
            _exitShowAll();
          }),
        ),
      ],
    ];
  }

  Widget _buildContent(
    BuildContext context,
    AppSkin skin,
    AppLocalizations l10n,
  ) {
    final selectedTab = ref.watch(customizeTabControllerProvider);

    // sgcode 智能体配置页：直接复用设置弹窗里那几个页面实现
    // （`StudioPage` 内部按 key 分派到资源列表 / 中转站 / 工具页）。
    // 不另写一套：同一份数据、同一套判权，两处实现迟早会对不上。
    // 顶部的搜索框对左边**每一个** Tab 都生效：搜索词原样传进去，
    // 由各页按自己的字段过滤（资源列表 / 工具 / 中转站形状不同）。
    final studioKey = selectedTab.studioPageKey;
    if (studioKey != null) {
      return StudioPage(pageKey: studioKey, query: _query);
    }

    // 判断是 Yours 还是 Discover 视图
    final isYoursView = _selectedViewIndex == 3;

    if (selectedTab == CustomizeTab.connectors) {
      if (isYoursView) {
        return _buildConnectorsYoursContent(context, skin, l10n);
      }
      return _buildConnectorsDiscoverContent(context, skin, l10n);
    }

    // Skills / Plugins
    if (isYoursView) {
      return _buildSkillsYoursContent(context, skin, l10n);
    }
    return _buildSkillsDiscoverContent(context, skin, l10n);
  }

  // Skills/Plugins + Discover 页面：显示 "For you" + "New" 区域
  Widget _buildSkillsDiscoverContent(
    BuildContext context,
    AppSkin skin,
    AppLocalizations l10n,
  ) {
    final isPlugins =
        ref.watch(customizeTabControllerProvider) == CustomizeTab.plugins;

    // Skills 视图 = 与设置弹窗里的技能页**同一份数据**（`SkillLibraryGrid`）。
    // Plugins 仍是 LobeChat 那套样例数据 —— 它没有对应的本地真源。
    //
    // 这里不再套「For you」标题 + 固定高度：技能本身就是这一页的全部内容，
    // 用 Column 让它吃满剩余高度（200+ 条得能在整页里滚），
    // 而不是塞进一个 560px 高的框再套一层外部滚动。
    if (!isPlugins && _showAllTitle == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SkillLibraryGrid(query: _query),
      );
    }

    // 全量列表：Skills 用 buildAllNewSkills，Plugins 用 buildAllNewPlugins。
    if (_showAllTitle != null) {
      final source = isPlugins ? buildAllNewPlugins() : buildAllNewSkills();
      final filtered = _filterShowAll(source, (s) => s.title);
      return CustomizeShowAllView.skills(
        title: _showAllTitle!,
        tabLabel: isPlugins ? l10n.customizeTabPlugins : l10n.studioSkill,
        skin: skin,
        l10n: l10n,
        searchController: _showAllSearchController,
        query: _showAllQuery,
        searchHint: isPlugins
            ? l10n.customizeSearchPluginsHint
            : l10n.customizeSearchSkillsHint,
        onQueryChanged: (v) => setState(() => _showAllQuery = v),
        onBack: () => setState(_exitShowAll),
        onTune: () => _notWired(context, l10n, 'category'),
        onSort: () => _notWired(context, l10n, 'sort'),
        onToolbarAdd: () => _notWired(context, l10n, l10n.commonAdd),
        onAdd: (skill) => _notWired(context, l10n, skill.title),
        skillItems: filtered,
      );
    }

    // Plugins 是样例数据，搜索后「为你推荐」和「最新」可能一起落空。
    // 先算一次，空就整页给空态 —— 否则只剩两个组头和一片空白。
    final forYou = _filterBy(buildForYouSkills(), (s) => s.title);
    final newSkills = _filterBy(buildNewSkills(), (s) => s.title);
    if (forYou.isEmpty && newSkills.isEmpty) {
      return Center(
        child: Text(
          l10n.studioEmpty,
          style: TextStyle(fontSize: 13, color: skin.textTertiary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        CustomizeSectionHeader(l10n.customizeTabForYou),
        const SizedBox(height: AppSpacing.md),
        _buildSkillsWrap(context, forYou, skin, l10n),
        const SizedBox(height: AppSpacing.md),
        CustomizeSectionHeader(
          l10n.customizeTabNew,
          showSeeAll: true,
          onSeeAll: () =>
              _openShowAll(isPlugins ? 'New plugins' : 'New skills'),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildSkillsWrap(context, newSkills, skin, l10n),
      ],
    );
  }

  // Skills/Plugins + Yours 页面：显示列表样式
  Widget _buildSkillsYoursContent(
    BuildContext context,
    AppSkin skin,
    AppLocalizations l10n,
  ) {
    // Skills 的 Yours 与设置弹窗里的技能页**共用同一个空态**：用户自建技能
    // 目前还没有创建入口，列表恒空。Plugins 仍走 LobeChat 那套样例（无本地真源）。
    if (ref.watch(customizeTabControllerProvider) == CustomizeTab.skills) {
      return const SkillsYoursEmpty();
    }

    final filtered = _filterBy(_yoursSkills, (s) => s['title'] as String);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: skin.border, width: 0.5)),
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
              // 搜索未命中与其他子页同一句「暂无内容」—— 同一个搜索框
              // 在不同 Tab 下不该给出两种空态文案。
              ? Center(
                  child: Text(
                    l10n.studioEmpty,
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
                      onTap: () =>
                          _notWired(context, l10n, skill['title'] as String),
                      onRemove: () => _removeYoursSkill(skill),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // Connectors + Discover 页面：显示带轮播图的页面
  Widget _buildConnectorsDiscoverContent(
    BuildContext context,
    AppSkin skin,
    AppLocalizations l10n,
  ) {
    if (_showAllTitle != null) {
      final filtered = _filterShowAll(buildAllConnectors(), (c) => c.title);
      return CustomizeShowAllView.connectors(
        title: _showAllTitle!,
        tabLabel: l10n.customizeTabConnectors,
        skin: skin,
        l10n: l10n,
        searchController: _showAllSearchController,
        query: _showAllQuery,
        searchHint: 'Search connectors...',
        onQueryChanged: (v) => setState(() => _showAllQuery = v),
        onBack: () => setState(_exitShowAll),
        onTune: () => _notWired(context, l10n, 'category'),
        onSort: () => _notWired(context, l10n, 'sort'),
        onToolbarAdd: () => _notWired(context, l10n, l10n.commonAdd),
        connectorItems: filtered,
      );
    }

    final connectors = buildConnectors();
    final filtered = _filterBy(connectors, (c) => c.title);

    // 搜不到时不要把横幅和组头留在页面上 —— 整页就是一句「暂无内容」，
    // 与技能页/各智能体子页同一副样子。
    if (filtered.isEmpty) {
      return Center(
        child: Text(
          l10n.studioEmpty,
          style: TextStyle(fontSize: 13, color: skin.textTertiary),
        ),
      );
    }

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
          onSeeAll: () => _openShowAll('All connectors'),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildConnectorsWrap(context, filtered, skin, l10n),
      ],
    );
  }

  // Connectors + Yours 页面：显示表格样式
  Widget _buildConnectorsYoursContent(
    BuildContext context,
    AppSkin skin,
    AppLocalizations l10n,
  ) {
    final connectors = buildYoursConnectors();
    final filtered = _filterBy(connectors, (c) => c.name);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: filtered.isEmpty
          ? Center(
              child: Text(
                l10n.studioEmpty,
                style: TextStyle(fontSize: 14, color: skin.textSecondary),
              ),
            )
          : YoursConnectorTable(
              skin: skin,
              connectors: filtered,
              onConnect: (connector) =>
                  _notWired(context, l10n, connector.name),
            ),
    );
  }

  Widget _buildConnectorsWrap(
    BuildContext context,
    List<ConnectorItem> items,
    AppSkin skin,
    AppLocalizations l10n,
  ) {
    // 列数按可用宽度自适应，与技能页/插件页同一份逻辑。
    return ResponsiveCardWrap(
      children: [
        for (final connector in items)
          ConnectorCard(
            connector: connector,
            skin: skin,
            l10n: l10n,
            onTap: () => _notWired(context, l10n, connector.title),
          ),
      ],
    );
  }

  Widget _buildSkillsWrap(
    BuildContext context,
    List<SkillItem> items,
    AppSkin skin,
    AppLocalizations l10n,
  ) {
    // 列数按可用宽度自适应，与技能库/连接器页同一份逻辑。
    return ResponsiveCardWrap(
      children: [
        for (final skill in items)
          SkillCard(
            skill: skill,
            skin: skin,
            l10n: l10n,
            onTap: () => _notWired(context, l10n, '点击跳转'),
          ),
      ],
    );
  }
}
