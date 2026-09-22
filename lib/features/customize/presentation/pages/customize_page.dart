import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// Customize 页面 - Skills, Connectors, Plugins 等自定义内容
class CustomizePage extends StatefulWidget {
  const CustomizePage({super.key});

  @override
  State<CustomizePage> createState() => _CustomizePageState();
}

class _CustomizePageState extends State<CustomizePage> {
  int _selectedTabIndex = 0;
  int? _hoveredTabIndex;
  bool _searchExpanded = false;

  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SkillItem> _filter(List<SkillItem> items) {
    if (_query.isEmpty) return items;
    final q = _query.toLowerCase();
    return items
        .where((s) => s.title.toLowerCase().contains(q))
        .toList(growable: false);
  }

// TODO: 这个网格区域右上角+按钮暂未实现
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
            child: _buildTabsAndActions(context, skin, l10n),
          ),
        ],
      ),
    );
  }

  /// 中栏宽度低于此值时，搜索框收窄；低于 [_stackBreakpoint] 时标签和操作分两行
  static const double _compactBreakpoint = 900;
  static const double _stackBreakpoint = 620;

  Widget _buildTabsAndActions(
    BuildContext context,
    AppSkin skin,
    AppLocalizations l10n,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final stacked = width < _stackBreakpoint;
        final showFullSearch = width >= _compactBreakpoint;

        if (!stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildTabs(skin),
                  const Spacer(),
                  _buildActionsRow(
                    context,
                    skin,
                    l10n,
                    showFullSearch: showFullSearch,
                  ),
                ],
              ),
              if (_searchExpanded && !showFullSearch) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildExpandedSearchField(skin, l10n),
              ],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildTabs(skin),
                const Spacer(),
                _buildActionsRow(
                  context,
                  skin,
                  l10n,
                  showFullSearch: false,
                ),
              ],
            ),
            if (_searchExpanded) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildExpandedSearchField(skin, l10n),
            ],
          ],
        );
      },
    );
  }

  Widget _buildActionsRow(
    BuildContext context,
    AppSkin skin,
    AppLocalizations l10n, {
    required bool showFullSearch,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFullSearch) ...[
          SizedBox(
            width: 300,
            height: 40,
            child: _buildSearchField(skin, l10n),
          ),
          const SizedBox(width: AppSpacing.xs),
        ] else ...[
          IconButton(
            icon: Icon(Icons.search, color: skin.text, size: 20),
            onPressed: () {
              setState(() {
                _searchExpanded = !_searchExpanded;
                if (!_searchExpanded) {
                  _query = '';
                  _searchController.clear();
                }
              });
            },
            tooltip: 'Search',
            padding: const EdgeInsets.all(AppSpacing.xs),
            constraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
        IconButton(
          icon: Icon(Icons.tune, color: skin.text, size: 20),
          onPressed: () => _notWired(context, l10n, 'category'),
          tooltip: 'Category',
          padding: const EdgeInsets.all(AppSpacing.xs),
          constraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        IconButton(
          icon: Icon(Icons.sort, color: skin.text, size: 20),
          onPressed: () => _notWired(context, l10n, 'sort'),
          tooltip: 'Sort',
          padding: const EdgeInsets.all(AppSpacing.xs),
          constraints: const BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        _buildAddButton(context, skin, l10n),
      ],
    );
  }

  Widget _buildExpandedSearchField(AppSkin skin, AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: _buildSearchField(skin, l10n),
    );
  }

  Widget _buildSearchField(AppSkin skin, AppLocalizations l10n) {
    return TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _query = v),
      style: TextStyle(fontSize: 14, color: skin.text),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Icon(Icons.search, size: 20, color: skin.textSecondary),
        hintText: l10n.customizeSearchHint,
        hintStyle: TextStyle(color: skin.textTertiary, fontSize: 14),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close, size: 18, color: skin.textSecondary),
                onPressed: () {
                  setState(() {
                    _query = '';
                    _searchController.clear();
                  });
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: skin.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: skin.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: skin.accentChip, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    return ElevatedButton.icon(
      onPressed: () => _notWired(context, l10n, l10n.commonAdd),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: AppSpacing.xxs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        elevation: 0,
      ),
      icon: const Icon(Icons.add, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Add',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(AppSkin skin) {
    final tabs = [
      {'label': 'Skills'},
      {'label': 'Connectors'},
      {'label': 'Plugins'},
      {'label': 'Yours'},
      {'label': 'Discover'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...List.generate(tabs.length, (index) {
            final tab = tabs[index];
            final isSelected = _selectedTabIndex == index;

            // 在 Plugins 之后插入分割线
            if (index == 3) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 1,
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    color: skin.border,
                  ),
                  _buildTabItem(tab, isSelected, index, skin),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                right: index < tabs.length - 1 ? AppSpacing.xs : 0,
              ),
              child: _buildTabItem(tab, isSelected, index, skin),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTabItem(Map<String, dynamic> tab, bool isSelected, int index, AppSkin skin) {
    final isHovered = _hoveredTabIndex == index;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredTabIndex = index),
      onExit: (_) => setState(() => _hoveredTabIndex = null),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(AppRadius.sm),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: isSelected || isHovered
                ? skin.textSecondary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab['label'] as String,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? skin.text : skin.textSecondary,
              ),
            ),
            if (tab['badge'] != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: skin.textSecondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  tab['badge'] as String,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: skin.textSecondary,
                  ),
                ),
              ),
            ],
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _buildSection(context, 'For you', skin, l10n),
        const SizedBox(height: AppSpacing.md),
        _buildSkillsGrid(context, skin, l10n),
        const SizedBox(height: AppSpacing.md),
        _buildSection(context, 'New', skin, l10n, showSeeAll: true),
        const SizedBox(height: AppSpacing.md),
        _buildNewSkillsRow(context, skin, l10n),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    AppSkin skin,
    AppLocalizations l10n, {
    bool showSeeAll = false,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: skin.text,
          ),
        ),
        const Spacer(),
        if (showSeeAll)
          TextButton(
            // TODO: 这个 See all 按钮暂未实现
            onPressed: () => _notWired(context, l10n, 'See all'),
            style: TextButton.styleFrom(
              foregroundColor: skin.text,
              padding: EdgeInsets.zero,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 14,
                    color: skin.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: skin.textSecondary,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSkillsGrid(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    final skills = [
      SkillItem(
        icon: Icons.list_alt,
        title: 'Operations',
        description: 'Optimize business operations — vendor management, process documentation, change...',
        source: 'Anthropic',
        installs: '1.3M installs',
      ),
      SkillItem(
        icon: Icons.store,
        title: 'Small Business',
        description: 'Pre-built small business workflows to help you run and grow your business. Supports a majority of the...',
        source: 'Anthropic',
        installs: '931.4K installs',
      ),
      SkillItem(
        icon: Icons.science,
        title: 'Bio Research',
        description: 'Connect to preclinical research tools and databases (literature search, genomics analysis, target...',
        source: 'Anthropic',
        installs: '487.3K installs',
      ),
      SkillItem(
        icon: Icons.videocam,
        title: 'Zoom',
        description: 'Plan, build, and debug Zoom integrations across REST APIs, Meeting SDK, Video SDK, webhooks, bots, an...',
        source: 'Zoom',
        installs: '243.1K installs',
      ),
      SkillItem(
        icon: Icons.bar_chart,
        title: 'Bright Data',
        description: 'Web scraping, Google search, structured data extraction, and MCP server integration powered by...',
        source: 'Bright Data',
        installs: '237.9K installs',
      ),
      SkillItem(
        icon: Icons.shopping_bag,
        title: 'Product Tracking',
        description: 'AI agent skills that make SaaS products data-ready for product analytics — from codebase scan to...',
        source: 'Accoll',
        installs: '211K installs',
      ),
      SkillItem(
        icon: Icons.code,
        title: 'Zapier',
        description: 'Connect 8,000+ apps to your AI workflow. Discover, enable, and execute Zapier actions directly from yo...',
        source: 'Zapier',
        installs: '149.7K installs',
      ),
      SkillItem(
        icon: Icons.table_chart,
        title: 'Airtable',
        description: 'Airtable is the database and operations layer for your agents — whether running product, marketing, sale...',
        source: 'Airtable',
        installs: '117.3K installs',
      ),
    ];

    final filtered = _filter(skills);
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
    final newSkills = [
      SkillItem(
        icon: Icons.apartment,
        title: 'Wingspan',
        description: 'Ask Claude about the contractors you pay through Wingspan, what you owe them, and what is holding...',
        source: 'Wingspan Engineering',
        installs: 'added 2 days ago',
      ),
      SkillItem(
        icon: Icons.warning,
        title: 'incident.io',
        description: 'Work with incident.io from Claude: respond to and investigate incidents, check on-call schedules and...',
        source: 'incident.io',
        installs: 'added 2 days ago',
      ),
    ];

    final filtered = _filter(newSkills);
    return _buildSkillsWrap(context, filtered, skin, l10n);
  }
}

class SkillItem {
  final IconData icon;
  final String title;
  final String description;
  final String source;
  final String installs;

  SkillItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.source,
    required this.installs,
  });
}

class SkillCard extends StatefulWidget {
  const SkillCard({
    super.key,
    required this.skill,
    required this.skin,
    required this.l10n,
    required this.onTap,
  });

  final SkillItem skill;
  final AppSkin skin;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  State<SkillCard> createState() => _SkillCardState();
}

class _SkillCardState extends State<SkillCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: widget.skin.containerBg,
              border: Border.all(
                color: widget.skin.border,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: widget.skin.border.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.skin.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  widget.skill.icon,
                  size: 20,
                  color: widget.skin.text,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.skill.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: widget.skin.text,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      widget.skill.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.skin.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.skill.source,
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.skin.textSecondary.withValues(alpha: 0.7),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          '·',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.skin.textSecondary.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Flexible(
                          child: Text(
                            widget.skill.installs,
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.skin.textSecondary.withValues(alpha: 0.7),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: Icon(Icons.add, color: widget.skin.text),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(widget.l10n.commonNotWired(widget.skill.title)),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
                iconSize: 20,
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
