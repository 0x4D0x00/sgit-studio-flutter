import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/customize/presentation/widgets/customize_toolbar.dart';
import 'package:sgit_studio_flutter/ui/primitives/pill_tab_bar.dart';
import 'package:sgit_studio_flutter/features/customize/presentation/widgets/skill_library.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 设置弹窗里的 Skills 页面 —— 内容与 Customize 的 Skills 是**同一份**。
///
/// 数据源、分组与卡片全部来自 [SkillLibraryGrid]，这里只多一层「Discover / Yours」
/// 的切换外壳。两处复用同一个组件而不是各写一遍：它们读的是同一个目录
/// `~/.sgitai/skills`，分开实现必然漂成两套内容（先前 Customize 用假数据、
/// 设置用真源，就是这么裂开的）。
class SkillsSettingsPage extends StatefulWidget {
  const SkillsSettingsPage({super.key});

  @override
  State<SkillsSettingsPage> createState() => _SkillsSettingsPageState();
}

class _SkillsSettingsPageState extends State<SkillsSettingsPage> {
  bool _isYoursView = false; // 默认 Discover
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _notWired(AppLocalizations l10n, String what) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.commonNotWired(what)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
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
            onQueryChanged: (v) => setState(() => _query = v),
            onTune: () => _notWired(l10n, 'category'),
            onSort: () => _notWired(l10n, 'sort'),
            onAdd: () => _notWired(l10n, l10n.commonAdd),
          ),
        ),
        Expanded(
          child: _isYoursView
              ? const SkillsYoursEmpty()
              : SkillLibraryGrid(query: _query),
        ),
      ],
    );
  }
}
