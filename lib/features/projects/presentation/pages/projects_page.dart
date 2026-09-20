import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/projects/presentation/widgets/create_project_dialog.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// Projects 页面 - 显示项目列表和创建新项目功能
class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  // 临时数据
  final List<ProjectItem> _projects = [
    ProjectItem(
      id: '1',
      name: 'PotAGI',
      updatedAt: DateTime(2025, 11, 4),
    ),
  ];

  bool _searching = false;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProjectItem> get _filteredProjects {
    if (_query.isEmpty) return _projects;
    final q = _query.toLowerCase();
    return _projects
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
    setState(() {
      _projects.add(
        ProjectItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: draft.name,
          updatedAt: DateTime.now(),
        ),
      );
    });
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
              fontSize: 28,
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
              onPressed: () {},
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
    final projects = _filteredProjects;
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        return ProjectCard(project: projects[index]);
      },
    );
  }
}

class ProjectCard extends StatelessWidget {
  const ProjectCard({
    super.key,
    required this.project,
  });

  final ProjectItem project;

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: skin.containerBg,
        border: Border.all(
          color: skin.border,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            project.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: skin.text,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            _formatDate(project.updatedAt),
            style: TextStyle(
              fontSize: 14,
              color: skin.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class ProjectItem {
  final String id;
  final String name;
  final DateTime updatedAt;

  ProjectItem({
    required this.id,
    required this.name,
    required this.updatedAt,
  });
}
