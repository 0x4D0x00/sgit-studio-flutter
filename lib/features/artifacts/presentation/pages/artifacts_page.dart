import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/artifact/artifact.dart';
import 'package:sgit_studio_flutter/features/artifacts/application/artifacts_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/router/route_names.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/services/layout/layout_controller.dart';
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
  int? _hoveredTab;
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

  /// 点开一条输出物：回到它所在的会话，并在右侧面板打开这份文件。
  ///
  /// 三件事的顺序有讲究：
  /// 1. **先开面板** —— 内容已经存在列表里，不必等会话载完，点完立刻有反馈；
  /// 2. 不是当前会话才载入（当前会话已在内存里，重载会白闪一次、丢滚动位置）。
  ///    `openThreadById` 的清空与置"载入中"是同步的，下一行跳页时是干净的载入态；
  /// 3. 发定位请求，由对话流在内容到齐后把文件卡滚进视野（见 `ChatTranscript`）。
  void _open(Artifact a) {
    final threadId = a.threadId;
    if (a.content.isNotEmpty) {
      ref.read(layoutControllerProvider.notifier).showArtifact(a.toChatArtifact());
    }
    if (threadId == null) return;

    final chat = ref.read(chatControllerProvider.notifier);
    if (ref.read(chatControllerProvider).currentThreadId != threadId) {
      unawaited(chat.openThreadById(threadId));
    }
    ref.read(artifactFocusProvider.notifier).request(a);
    context.go(RouteNames.home);
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
          LayoutBuilder(
            builder: (context, constraints) {
              // 估算一行所需最小宽度：tabs + 按钮们
              // tabs约150px，搜索20px，视图20px，类型筛选80px，新建按钮100px，间距40px = 410px
              final hasSpaceForInlineSearch = constraints.maxWidth >= 700;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildTabs(l10n, skin),
                      const Spacer(),
                      if (!_searchOpen || !hasSpaceForInlineSearch)
                        IconButton(
                          icon: const Icon(Icons.search),
                          iconSize: 20,
                          tooltip: l10n.artifactsSearch,
                          color: skin.textSecondary,
                          onPressed: () => setState(() => _searchOpen = true),
                        )
                      else
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.md),
                            child: SizedBox(
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
                          ),
                        ),
                      const SizedBox(width: AppSpacing.xs),
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
                      _typeMenu(l10n, skin, state.typeFilter, ctrl),
                      const SizedBox(width: AppSpacing.xs),
                      ElevatedButton(
                        onPressed: () => context.go(RouteNames.artifactsNew),
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
                  // 当空间不足且搜索打开时，另起一行显示搜索框
                  if (_searchOpen && !hasSpaceForInlineSearch) ...[
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
                  ],
                ],
              );
            },
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
        final isHovered = _hoveredTab == index;
        return Padding(
          padding: const EdgeInsets.only(right: AppSpacing.xs),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hoveredTab = index),
            onExit: (_) => setState(() => _hoveredTab = null),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedTab = index;
                });
              },
              borderRadius: BorderRadius.circular(AppRadius.sm),
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isSelected || isHovered
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
          ),
        );
      }),
    );
  }

  Widget _typeMenu(
    AppLocalizations l10n,
    AppSkin skin,
    String? current,
    ArtifactsController ctrl,
  ) {
    String label(String? type) {
      if (type == null) return l10n.artifactsTypeAll;
      if (type == 'other') return 'Other';
      return l10n.artifactsTypeAll;
    }

    // 构建选项：null（全部类型）+ 'other'（其他）
    final values = <String?>[null, 'other'];

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
                    key: ValueKey(a.id),
                    artifact: a,
                    onTap: () => _open(a),
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
                key: ValueKey(items[index].id),
                artifact: items[index],
                onTap: () => _open(items[index]),
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
            width: 220,
            decoration: BoxDecoration(
              color: skin.containerBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: skin.borderSecondary),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: skin.border.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
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
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.xs,
          ),
          color: _hovering
              ? skin.text.withValues(alpha: 0.05)
              : Colors.transparent,
          child: Row(
            children: [
              // 左侧统一图标
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: skin.containerBgSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: skin.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // 标题
              Expanded(
                child: Text(
                  artifact.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: skin.text,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // 编辑时间
              Text(
                l10n.artifactsEdited(when),
                style: TextStyle(
                  fontSize: 12,
                  color: skin.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // 三点菜单。列表视图里常驻显示
              SizedBox(
                width: 28,
                height: 28,
                child: AppMenuAnchor(
                  trigger: AppMenuTrigger.tap,
                  align: AppMenuAlign.underEnd,
                  minWidth: 160,
                  semanticLabel: l10n.artifactsMoreActions,
                  entries: _menuEntries(l10n),
                  child: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: skin.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
