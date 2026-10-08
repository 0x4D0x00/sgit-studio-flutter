import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/projects/application/projects_controller.dart';
import 'package:sgit_studio_flutter/features/projects/presentation/widgets/create_project_dialog.dart';
import 'package:sgit_studio_flutter/features/projects/presentation/widgets/edit_project_dialog.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/confirm.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// Projects 页面 - 显示项目列表和创建新项目功能
class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {

  bool _searching = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProjectItem> get _filteredProjects {
    final projects = ref.watch(projectsControllerProvider);
    if (_query.isEmpty) return projects;
    final q = _query.toLowerCase();
    return projects
        .where((p) => p.name.toLowerCase().contains(q))
        .toList(growable: false);
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

  Future<void> _showCreateProjectDialog() async {
    final draft = await showCreateProjectDialog(context);
    if (draft == null || draft.name.isEmpty) return;
    ref.read(projectsControllerProvider.notifier).addProject(
          draft.name,
          draft.description,
        );
  }

  Future<void> _showEditProjectDialog(ProjectItem project) async {
    final edit = await showEditProjectDialog(
      context,
      name: project.name,
      description: project.description,
    );
    if (edit == null || edit.name.isEmpty) return;
    ref.read(projectsControllerProvider.notifier).updateProject(
          project.id,
          edit.name,
          edit.description,
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

  Future<void> _deleteProject(ProjectItem project) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDanger(
      context,
      title: l10n.studioRemoveConfirm(project.name),
      confirmText: l10n.commonDelete,
    );
    if (!ok) return;

    ref.read(projectsControllerProvider.notifier).deleteProject(project.id);
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
            child: _buildProjectList(skin),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppSkin skin) {
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: skin.baseBg,
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
            'Projects',
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
              icon: Icon(Icons.sync, color: skin.text),
              onPressed: () => _notWired(l10n.commonRefresh),
              tooltip: l10n.commonRefresh,
            ),
          const SizedBox(width: AppSpacing.xs),
          ElevatedButton(
            onPressed: _showCreateProjectDialog,
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
            child: const Text(
              'New project',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
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
        hintText: l10n.projectsSearchHint,
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

  Widget _buildProjectList(AppSkin skin) {
    final l10n = AppLocalizations.of(context);
    final projects = _filteredProjects;

    if (projects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          l10n.projectsEmpty,
          style: TextStyle(fontSize: 14, color: skin.textTertiary),
        ),
      );
    }

    // 卡片高度：同一行内的所有卡片高度一致（由该行最高的卡片决定）；宽度足够时两列，否则单列。
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns =
            constraints.maxWidth >= _minCardWidth * 2 + AppSpacing.md;
        final crossAxisCount = twoColumns ? 2 : 1;

        // 将项目分组成行
        final rows = <List<ProjectItem>>[];
        for (var i = 0; i < projects.length; i += crossAxisCount) {
          rows.add(
            projects.sublist(
              i,
              (i + crossAxisCount).clamp(0, projects.length),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, rowIndex) {
            final rowProjects = rows[rowIndex];
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < rowProjects.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ProjectCard(
                        project: rowProjects[i],
                        onTap: () => _notWired(l10n.commonNotWired('点击跳转')),
                        // TODO: 置顶功能暂未实现
                        onPin: () => _notWired(l10n.projectsPin),
                        onEditDetails: () =>
                            _showEditProjectDialog(rowProjects[i]),
                        onDelete: () => _deleteProject(rowProjects[i]),
                      ),
                    ),
                  ],
                  // 最后一行可能不足 crossAxisCount 个，填充空白以保持对齐
                  if (rowProjects.length < crossAxisCount)
                    ...List.generate(
                      crossAxisCount - rowProjects.length,
                      (_) => const Expanded(child: SizedBox()),
                    ).expand((widget) => [
                          const SizedBox(width: AppSpacing.md),
                          widget,
                        ]),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// 一张卡片最少需要这么宽才不显得拥挤，窄于此就退成单列。
  static const double _minCardWidth = 280;
}

class ProjectCard extends StatefulWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    required this.onPin,
    required this.onEditDetails,
    required this.onDelete,
  });

  final ProjectItem project;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onEditDetails;
  final VoidCallback onDelete;

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _hovering = false;
  bool _menuOpen = false;

  String _formatUpdatedAt(AppLocalizations l10n, DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return l10n.projectsUpdatedJustNow;
    if (diff.inMinutes < 60) {
      return l10n.projectsUpdatedMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) return l10n.projectsUpdatedHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.projectsUpdatedDaysAgo(diff.inDays);

    final locale = Localizations.localeOf(context).toString();
    final sameYear = date.year == now.year;
    return sameYear
        ? DateFormat.MMMd(locale).format(date)
        : DateFormat.yMMMd(locale).format(date);
  }

  List<AppMenuEntry> _menuEntries(AppLocalizations l10n) => [
        AppMenuAction(
          icon: Icons.push_pin_outlined,
          label: l10n.projectsPin,
          onTap: widget.onPin,
        ),
        AppMenuAction(
          icon: Icons.edit_outlined,
          label: l10n.projectsEditDetails,
          onTap: widget.onEditDetails,
        ),
        const AppMenuDivider(),
        AppMenuAction(
          icon: Icons.delete_outline,
          label: l10n.commonDelete,
          danger: true,
          onTap: widget.onDelete,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final project = widget.project;
    final showMenuButton = _hovering || _menuOpen;

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
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: skin.containerBg,
              border: Border.all(color: skin.border, width: 1),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: skin.border.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
          child: Stack(
            children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 右侧留出「···」按钮的位置,避免长标题的省略号被按钮压住。
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xl),
                  child: Text(
                    project.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: skin.text,
                    ),
                  ),
                ),
                if (project.description.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    project.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: skin.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
                // 即使没有描述,也留最小间距,避免卡片过于扁平
                const SizedBox(height: AppSpacing.md),
                const Spacer(),
                Text(
                  _formatUpdatedAt(l10n, project.updatedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: skin.textSecondary,
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SizedBox(
                width: 28,
                height: 28,
                child: showMenuButton
                    ? AppMenuAnchor(
                        trigger: AppMenuTrigger.tap,
                        align: AppMenuAlign.underEnd,
                        minWidth: 160,
                        semanticLabel: l10n.projectsMoreActions,
                        onOpenChanged: (open) =>
                            setState(() => _menuOpen = open),
                        entries: _menuEntries(l10n),
                        child: Container(
                          decoration: BoxDecoration(
                            color: skin.textSecondary.withValues(alpha: 0.05),
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

class ProjectItem {
  final String id;
  final String name;
  final String description;
  final DateTime updatedAt;

  ProjectItem({
    required this.id,
    required this.name,
    required this.description,
    required this.updatedAt,
  });
}
