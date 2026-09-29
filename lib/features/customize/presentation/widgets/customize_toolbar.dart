import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// Customize 系页面共用的工具条：标签行 + 搜索框 + tune/sort 图标 + Add 按钮。
///
/// 响应式：容器变窄时搜索框收起为一个图标，点开后另起一行展开；更窄时标签和
/// 操作也分两行摆放。断点与 [CustomizePage] 保持一致，这样设置弹窗（较窄）
/// 和顶层 Customize 路由页（较宽）视觉行为统一。
class CustomizeToolbar extends StatefulWidget {
  const CustomizeToolbar({
    super.key,
    required this.tabs,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    this.onTune,
    this.onSort,
    this.onAdd,
    this.searchHint,
  });

  final Widget tabs;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onTune;
  final VoidCallback? onSort;
  final VoidCallback? onAdd;
  final String? searchHint;

  @override
  State<CustomizeToolbar> createState() => _CustomizeToolbarState();
}

class _CustomizeToolbarState extends State<CustomizeToolbar> {
  bool _searchExpanded = false;

  /// 中栏宽度低于此值时，搜索框收窄；低于 [_stackBreakpoint] 时标签和操作分两行
  static const double _compactBreakpoint = 900;
  static const double _stackBreakpoint = 620;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final stacked = width < _stackBreakpoint;
        final showFullSearch = width >= _compactBreakpoint;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: widget.tabs),
                _buildActionsRow(
                  context,
                  skin,
                  l10n,
                  showFullSearch: !stacked && showFullSearch,
                ),
              ],
            ),
            if (_searchExpanded && (stacked || !showFullSearch)) ...[
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
                  widget.onQueryChanged('');
                  widget.searchController.clear();
                }
              });
            },
            tooltip: 'Search',
            padding: const EdgeInsets.all(AppSpacing.xs),
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
        IconButton(
          icon: Icon(Icons.tune, color: skin.text, size: 20),
          onPressed: widget.onTune,
          tooltip: 'Category',
          padding: const EdgeInsets.all(AppSpacing.xs),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        ),
        const SizedBox(width: AppSpacing.xxs),
        IconButton(
          icon: Icon(Icons.sort, color: skin.text, size: 20),
          onPressed: widget.onSort,
          tooltip: 'Sort',
          padding: const EdgeInsets.all(AppSpacing.xs),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
      controller: widget.searchController,
      onChanged: widget.onQueryChanged,
      style: TextStyle(fontSize: 14, color: skin.text),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Icon(Icons.search, size: 20, color: skin.textSecondary),
        hintText: widget.searchHint ?? l10n.customizeSearchHint,
        hintStyle: TextStyle(color: skin.textTertiary, fontSize: 14),
        suffixIcon: widget.query.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.close, size: 18, color: skin.textSecondary),
                onPressed: () {
                  widget.onQueryChanged('');
                  widget.searchController.clear();
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
      onPressed: widget.onAdd,
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
          Text(
            l10n.commonAdd,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white),
        ],
      ),
    );
  }
}
