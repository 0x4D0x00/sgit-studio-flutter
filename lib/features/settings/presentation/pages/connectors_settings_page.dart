import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/pill_tab_bar.dart';
import 'package:sgit_studio_flutter/ui/components/responsive_card_wrap.dart';

import 'package:sgit_studio_flutter/features/customize/data/customize_models.dart';
import 'package:sgit_studio_flutter/features/customize/data/customize_sample_data.dart';
import 'package:sgit_studio_flutter/features/customize/presentation/widgets/connector_card.dart';
import 'package:sgit_studio_flutter/features/customize/presentation/widgets/customize_section_header.dart';
import 'package:sgit_studio_flutter/features/customize/presentation/widgets/customize_show_all_view.dart';
import 'package:sgit_studio_flutter/features/customize/presentation/widgets/customize_toolbar.dart';
import 'package:sgit_studio_flutter/features/customize/presentation/widgets/yours_connector_table.dart';

/// 设置弹窗里的 Connectors 页面：Yours 是表格样式，Discover 是卡片网格。
/// 弹窗比顶层 Customize 路由页窄，故不放推荐轮播图，直接从 "Top connectors" 开始。
class ConnectorsSettingsPage extends StatefulWidget {
  const ConnectorsSettingsPage({super.key});

  @override
  State<ConnectorsSettingsPage> createState() => _ConnectorsSettingsPageState();
}

class _ConnectorsSettingsPageState extends State<ConnectorsSettingsPage> {
  bool _isYoursView = false; // 默认 Discover
  final _searchController = TextEditingController();
  String _query = '';

  /// 「Show all」全量列表是否打开，以及它自己的搜索词。
  bool _showAll = false;
  final _showAllSearchController = TextEditingController();
  String _showAllQuery = '';

  List<T> _filterBy<T>(List<T> items, String Function(T) titleOf) {
    if (_query.isEmpty) return items;
    final q = _query.toLowerCase();
    return items.where((item) => titleOf(item).toLowerCase().contains(q)).toList(growable: false);
  }

  List<T> _filterShowAll<T>(List<T> items, String Function(T) titleOf) {
    if (_showAllQuery.isEmpty) return items;
    final q = _showAllQuery.toLowerCase();
    return items.where((item) => titleOf(item).toLowerCase().contains(q)).toList(growable: false);
  }

  void _exitShowAll() {
    _showAll = false;
    _showAllQuery = '';
    _showAllSearchController.clear();
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        // 全量列表自带头部和搜索框，这里就不再画一遍工具条。
        if (!_showAll)
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
              searchHint: 'Search connectors...',
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
    final filtered = _filterBy(buildYoursConnectors(), (c) => c.name);

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'No connectors found',
          style: TextStyle(fontSize: 14, color: skin.textSecondary),
        ),
      );
    }

    return YoursConnectorTable(
      skin: skin,
      connectors: filtered,
      onConnect: (connector) => _notWired(context, l10n, connector.name),
    );
  }

  Widget _buildDiscoverContent(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    if (_showAll) {
      return CustomizeShowAllView.connectors(
        title: 'All connectors',
        tabLabel: 'Connectors',
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
        connectorItems: _filterShowAll(buildAllConnectors(), (c) => c.title),
      );
    }

    final filtered = _filterBy(buildConnectors(), (c) => c.title);

    return ListView(
      children: [
        CustomizeSectionHeader(
          'Top connectors',
          showSeeAll: true,
          onSeeAll: () => setState(() => _showAll = true),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildWrap(context, filtered, skin, l10n),
      ],
    );
  }

  Widget _buildWrap(
    BuildContext context,
    List<ConnectorItem> items,
    AppSkin skin,
    AppLocalizations l10n,
  ) {
    // 弹窗比顶层页面窄，最多两列；列数逻辑仍复用同一份组件。
    return ResponsiveCardWrap(
      minWidth: 260,
      maxColumns: 2,
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
}
