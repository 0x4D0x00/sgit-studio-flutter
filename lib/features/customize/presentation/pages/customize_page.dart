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

  bool _searching = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() => _searching = true);
  }

  void _stopSearch() {
    setState(() {
      _searching = false;
      _query = '';
      _searchController.clear();
    });
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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Text(
                  'Customize',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: skin.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                if (!_searching)
                  IconButton(
                    icon: Icon(Icons.search, color: skin.text),
                    onPressed: _startSearch,
                    tooltip: l10n.commonSearch,
                  )
                else
                  SizedBox(
                    width: 280,
                    height: 36,
                    child: _buildSearchField(skin, l10n),
                  ),
                if (!_searching) const SizedBox(width: AppSpacing.xxs),
                if (!_searching)
                  IconButton(
                    icon: Icon(Icons.tune, color: skin.text),
                    // TODO: 这个类别按钮暂未实现
                    onPressed: () => _notWired(context, l10n, 'category'),
                    tooltip: 'Category',
                  ),
                if (!_searching) const SizedBox(width: AppSpacing.xxs),
                const SizedBox(width: AppSpacing.xs),
                _buildAddButton(context, skin, l10n),
              ],
            ),
          ),
          _buildTabs(skin),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppSkin skin, AppLocalizations l10n) {
    return TextField(
      controller: _searchController,
      autofocus: true,
      onChanged: (v) => setState(() => _query = v),
      style: TextStyle(fontSize: 14, color: skin.text),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Icon(Icons.search, size: 18, color: skin.textSecondary),
        hintText: l10n.customizeSearchHint,
        hintStyle: TextStyle(color: skin.textTertiary),
        suffixIcon: IconButton(
          icon: Icon(Icons.close, size: 18, color: skin.textSecondary),
          onPressed: _stopSearch,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
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
          borderSide: BorderSide(color: skin.accentChip, width: 2),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    return ElevatedButton(
      // TODO: 这个 Add 按钮暂未实现
      onPressed: () => _notWired(context, l10n, l10n.commonAdd),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Add',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
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
    final tabs = ['Skills', 'Connectors', 'Plugins', 'Yours', 'Discover'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? skin.textSecondary.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  tabs[index],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? skin.text : skin.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _buildSection(context, 'For you', skin, l10n),
        const SizedBox(height: AppSpacing.lg),
        _buildSkillsGrid(context, skin, l10n),
        const SizedBox(height: AppSpacing.xl),
        _buildSection(context, 'New', skin, l10n, showSeeAll: true),
        const SizedBox(height: AppSpacing.lg),
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
        source: 'from Anthropic',
        installs: '1.3M installs',
      ),
      SkillItem(
        icon: Icons.store,
        title: 'Small Business',
        description: 'Pre-built small business workflows to help you run and grow your business. Supports a majority of the...',
        source: 'from Anthropic',
        installs: '931.4K installs',
      ),
      SkillItem(
        icon: Icons.science,
        title: 'Bio Research',
        description: 'Connect to preclinical research tools and databases (literature search, genomics analysis, target...',
        source: 'from Anthropic',
        installs: '487.3K installs',
      ),
      SkillItem(
        icon: Icons.videocam,
        title: 'Zoom',
        description: 'Plan, build, and debug Zoom integrations across REST APIs, Meeting SDK, Video SDK, webhooks, bots, an...',
        source: 'from Zoom',
        installs: '243.1K installs',
      ),
      SkillItem(
        icon: Icons.bar_chart,
        title: 'Bright Data',
        description: 'Web scraping, Google search, structured data extraction, and MCP server integration powered by...',
        source: 'from Bright Data',
        installs: '237.9K installs',
      ),
      SkillItem(
        icon: Icons.shopping_bag,
        title: 'Product Tracking',
        description: 'AI agent skills that make SaaS products data-ready for product analytics — from codebase scan to...',
        source: 'from Accoll',
        installs: '211K installs',
      ),
      SkillItem(
        icon: Icons.code,
        title: 'Zapier',
        description: 'Connect 8,000+ apps to your AI workflow. Discover, enable, and execute Zapier actions directly from yo...',
        source: 'from Zapier',
        installs: '149.7K installs',
      ),
      SkillItem(
        icon: Icons.table_chart,
        title: 'Airtable',
        description: 'Airtable is the database and operations layer for your agents — whether running product, marketing, sale...',
        source: 'from Airtable',
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
        source: 'from Wingspan Engineering',
        installs: 'added 2 days ago',
      ),
      SkillItem(
        icon: Icons.warning,
        title: 'incident.io',
        description: 'Work with incident.io from Claude: respond to and investigate incidents, check on-call schedules and...',
        source: 'from incident.io',
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

class SkillCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: skin.containerBg,
          border: Border.all(
            color: skin.border,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: skin.textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              skill.icon,
              size: 20,
              color: skin.text,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: skin.text,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  skill.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: skin.textSecondary,
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
                        skill.source,
                        style: TextStyle(
                          fontSize: 12,
                          color: skin.textSecondary.withValues(alpha: 0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      '·',
                      style: TextStyle(
                        fontSize: 12,
                        color: skin.textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Flexible(
                      child: Text(
                        skill.installs,
                        style: TextStyle(
                          fontSize: 12,
                          color: skin.textSecondary.withValues(alpha: 0.7),
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
            icon: Icon(Icons.add, color: skin.text),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.commonNotWired(skill.title)),
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
    );
  }
}
