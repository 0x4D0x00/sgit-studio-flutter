import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/artifact/artifact.dart';
import 'package:sgit_studio_flutter/features/artifacts/application/artifacts_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 视图模式：网格 / 列表。
enum ArtifactViewMode { grid, list }

/// 输出产物页 —— 点左栏「输出物」进来的主页。
///
/// 顶栏：标题（左）+ tabs（All/Yours/Shared） + 搜索 + 视图切换 + 类型筛选 + 新建按钮（右）
/// 主区：产物卡片网格或列表（无数据时显示空态）
class ArtifactsPage extends ConsumerStatefulWidget {
  const ArtifactsPage({
    super.key,
  });

  @override
  ConsumerState<ArtifactsPage> createState() => _ArtifactsPageState();
}

class _ArtifactsPageState extends ConsumerState<ArtifactsPage> {
  bool _searchOpen = false;
  final _searchController = TextEditingController();
  int _selectedTab = 0; // 0=All, 1=Yours, 2=Shared（仅视觉切换）
  ArtifactViewMode _viewMode = ArtifactViewMode.grid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final state = ref.watch(artifactsControllerProvider);
    final ctrl = ref.read(artifactsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, l10n, skin, state, ctrl),
        Expanded(
          child: state.filtered.isEmpty
              ? _emptyState(l10n, skin)
              : _viewMode == ArtifactViewMode.grid
                  ? _grid(context, l10n, skin, state.filtered)
                  : _list(context, l10n, skin, state.filtered),
        ),
      ],
    );
  }

  void _notWired(String what) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.commonNotWired(what)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    AppLocalizations l10n,
    AppSkin skin,
    ArtifactsState state,
    ArtifactsController ctrl,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：标题
          Text(
            l10n.artifactsTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: skin.text,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // 第二行：tabs（左）+ 搜索/视图切换/类型筛选/新建按钮（右）
          // 当搜索打开且空间不足时，折行显示搜索框
          if (_searchOpen) ...[
            Row(
              children: [
                _buildTabs(l10n, skin),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _viewMode == ArtifactViewMode.grid
                        ? Icons.view_list
                        : Icons.grid_view,
                  ),
                  iconSize: 20,
                  tooltip: _viewMode == ArtifactViewMode.grid
                      ? l10n.artifactsViewList
                      : l10n.artifactsViewGrid,
                  color: skin.textSecondary,
                  onPressed: () {
                    setState(() {
                      _viewMode = _viewMode == ArtifactViewMode.grid
                          ? ArtifactViewMode.list
                          : ArtifactViewMode.grid;
                    });
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                _typeMenu(l10n, skin, state.typeFilter, state.availableTypes, ctrl),
                const SizedBox(width: AppSpacing.xs),
                ElevatedButton(
                  onPressed: () => _notWired(l10n.artifactsNew),
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
                  child: Text(
                    l10n.artifactsNew,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.artifactsSearchHint,
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: skin.textSecondary,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 16,
                    tooltip: l10n.artifactsSearchClose,
                    color: skin.textSecondary,
                    onPressed: () {
                      setState(() => _searchOpen = false);
                      _searchController.clear();
                      ctrl.setSearchQuery('');
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                onChanged: ctrl.setSearchQuery,
              ),
            ),
          ] else
            Row(
              children: [
                _buildTabs(l10n, skin),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.search),
                  iconSize: 20,
                  tooltip: l10n.artifactsSearch,
                  color: skin.textSecondary,
                  onPressed: () => setState(() => _searchOpen = true),
                ),
                const SizedBox(width: AppSpacing.xs),
                // 视图切换按钮
                IconButton(
                  icon: Icon(
                    _viewMode == ArtifactViewMode.grid
                        ? Icons.view_list
                        : Icons.grid_view,
                  ),
                  iconSize: 20,
                  tooltip: _viewMode == ArtifactViewMode.grid
                      ? l10n.artifactsViewList
                      : l10n.artifactsViewGrid,
                  color: skin.textSecondary,
                  onPressed: () {
                    setState(() {
                      _viewMode = _viewMode == ArtifactViewMode.grid
                          ? ArtifactViewMode.list
                          : ArtifactViewMode.grid;
                    });
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                _typeMenu(l10n, skin, state.typeFilter, state.availableTypes, ctrl),
                const SizedBox(width: AppSpacing.xs),
                ElevatedButton(
                  onPressed: () => _notWired(l10n.artifactsNew),
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
                  child: Text(
                    l10n.artifactsNew,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTabs(AppLocalizations l10n, AppSkin skin) {
    final tabs = [
      l10n.artifactsTabAll,
      l10n.artifactsTabYours,
      l10n.artifactsTabShared,
    ];

    return Row(
      children: List.generate(tabs.length, (index) {
        final isSelected = _selectedTab == index;
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedTab = index;
              });
            },
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
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
    );
  }

  Widget _typeMenu(
    AppLocalizations l10n,
    AppSkin skin,
    String? current,
    List<String> availableTypes,
    ArtifactsController ctrl,
  ) {
    String label(String? type) =>
        type == null ? l10n.artifactsTypeAll : _capitalizeLanguage(type);

    // 构建选项：null（全部类型）+ 实际的语言类型
    final values = <String?>[null, ...availableTypes];

    return AppMenuAnchor(
      semanticLabel: l10n.artifactsTypeAll,
      entries: [
        AppMenuRadioGroup<String?>(
          values: values,
          selected: current,
          labelOf: label,
          onSelect: ctrl.setTypeFilter,
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: skin.borderSecondary),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label(current),
              style: TextStyle(fontSize: 14, color: skin.text),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 20, color: skin.textSecondary),
          ],
        ),
      ),
    );
  }

  String _capitalizeLanguage(String lang) {
    // 常见语言名称的首字母大写
    final common = {
      'dart': 'Dart',
      'javascript': 'JavaScript',
      'typescript': 'TypeScript',
      'python': 'Python',
      'java': 'Java',
      'markdown': 'Markdown',
      'json': 'JSON',
      'yaml': 'YAML',
      'html': 'HTML',
      'css': 'CSS',
      'bash': 'Bash',
      'shell': 'Shell',
    };
    return common[lang.toLowerCase()] ??
        lang[0].toUpperCase() + lang.substring(1);
  }

  Widget _emptyState(AppLocalizations l10n, AppSkin skin) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          l10n.artifactsEmpty,
          style: TextStyle(
            fontSize: 14,
            color: skin.textTertiary,
          ),
        ),
      );

  Widget _grid(
    BuildContext context,
    AppLocalizations l10n,
    AppSkin skin,
    List<Artifact> items,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Align(
            alignment: Alignment.topLeft,
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final a in items)
                  ArtifactCard(
                    artifact: a,
                    onTap: () => _notWired(l10n.commonNotWired('点击跳转')),
                    onCopyLink: () => _notWired(l10n.artifactsCopyLink),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    AppLocalizations l10n,
    AppSkin skin,
    List<Artifact> items,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, index) => Divider(
              height: 1,
              thickness: 1,
              color: skin.borderSecondary,
            ),
            itemBuilder: (context, index) {
              return ArtifactListRow(
                artifact: items[index],
                onTap: () => _notWired(l10n.commonNotWired('点击跳转')),
                onCopyLink: () => _notWired(l10n.artifactsCopyLink),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 产物卡片 —— 网格视图中的单个卡片，悬停显示"⋮"菜单。
class ArtifactCard extends StatefulWidget {
  const ArtifactCard({
    super.key,
    required this.artifact,
    required this.onTap,
    required this.onCopyLink,
  });

  final Artifact artifact;
  final VoidCallback onTap;
  final VoidCallback onCopyLink;

  @override
  State<ArtifactCard> createState() => _ArtifactCardState();
}

class _ArtifactCardState extends State<ArtifactCard> {
  bool _hovering = false;
  bool _menuOpen = false;

  List<AppMenuEntry> _menuEntries(AppLocalizations l10n) => [
        AppMenuAction(
          icon: Icons.link,
          label: l10n.artifactsCopyLink,
          onTap: widget.onCopyLink,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final artifact = widget.artifact;
    final showMenuButton = _hovering || _menuOpen;

    final locale = Localizations.localeOf(context);
    final fmt = DateFormat.MMMd(locale.toString());
    final now = DateTime.now();
    final sameYear = artifact.updatedAt.year == now.year;
    final when = sameYear
        ? fmt.format(artifact.updatedAt)
        : DateFormat.yMMMd(locale.toString()).format(artifact.updatedAt);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: 220,
          decoration: BoxDecoration(
            color: skin.containerBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: skin.borderSecondary),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                // 代码预览区
                Container(
                  height: 120,
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: skin.containerBgSecondary,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppRadius.md),
                    ),
                  ),
                  child: Text(
                    artifact.preview,
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: skin.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artifact.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: skin.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.artifactsEdited(when),
                        style: TextStyle(
                          fontSize: 11,
                          color: skin.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // 悬停菜单按钮
            Positioned(
              top: 4,
              right: 4,
              child: SizedBox(
                width: 28,
                height: 28,
                child: showMenuButton
                    ? AppMenuAnchor(
                        trigger: AppMenuTrigger.tap,
                        align: AppMenuAlign.underEnd,
                        minWidth: 160,
                        semanticLabel: l10n.artifactsMoreActions,
                        onOpenChanged: (open) =>
                            setState(() => _menuOpen = open),
                        entries: _menuEntries(l10n),
                        child: Container(
                          decoration: BoxDecoration(
                            color: skin.containerBg.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Icon(
                            Icons.more_vert,
                            size: 18,
                            color: skin.textSecondary,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// 产物列表行 —— 列表视图中的单行，悬停显示"⋮"菜单。
class ArtifactListRow extends StatefulWidget {
  const ArtifactListRow({
    super.key,
    required this.artifact,
    required this.onTap,
    required this.onCopyLink,
  });

  final Artifact artifact;
  final VoidCallback onTap;
  final VoidCallback onCopyLink;

  @override
  State<ArtifactListRow> createState() => _ArtifactListRowState();
}

class _ArtifactListRowState extends State<ArtifactListRow> {
  bool _hovering = false;
  bool _menuOpen = false;

  List<AppMenuEntry> _menuEntries(AppLocalizations l10n) => [
        AppMenuAction(
          icon: Icons.link,
          label: l10n.artifactsCopyLink,
          onTap: widget.onCopyLink,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final artifact = widget.artifact;
    final showMenuButton = _hovering || _menuOpen;

    final locale = Localizations.localeOf(context);
    final fmt = DateFormat.MMMd(locale.toString());
    final now = DateTime.now();
    final sameYear = artifact.updatedAt.year == now.year;
    final when = sameYear
        ? fmt.format(artifact.updatedAt)
        : DateFormat.yMMMd(locale.toString()).format(artifact.updatedAt);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: _hovering
              ? skin.text.withValues(alpha: 0.03)
              : Colors.transparent,
          child: Row(
            children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artifact.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: skin.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    artifact.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: skin.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              l10n.artifactsEdited(when),
              style: TextStyle(
                fontSize: 12,
                color: skin.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 28,
              height: 28,
              child: showMenuButton
                  ? AppMenuAnchor(
                      trigger: AppMenuTrigger.tap,
                      align: AppMenuAlign.underEnd,
                      minWidth: 160,
                      semanticLabel: l10n.artifactsMoreActions,
                      onOpenChanged: (open) => setState(() => _menuOpen = open),
                      entries: _menuEntries(l10n),
                      child: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: skin.textSecondary,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
