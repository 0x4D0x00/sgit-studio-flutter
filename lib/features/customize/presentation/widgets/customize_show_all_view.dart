import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

import 'connector_card.dart';
import 'customize_models.dart';
import 'customize_show_all_row.dart';
import 'customize_tag_chip.dart';
import 'customize_toolbar.dart';
import 'responsive_card_wrap.dart';

/// Discover 页面里点「Show all」之后的全量列表页。
///
/// 顶部是「← + 分类 chip」一行，下面一行左边是标题（All connectors / New skills /
/// New plugins）、右边是搜索与操作按钮——标题借 [CustomizeToolbar] 的左侧槽位
/// 摆放，这样窄宽度下搜索框收起、标题与按钮换行的行为和 Discover 页一致。
/// 最下面是全量内容。
///
/// 两种内容形态：
/// - [connectorItems] 非空 —— 连接器卡片网格（两列）；
/// - [skillItems] 非空 —— 行列表，右侧一个 Add 按钮（没有 Try in Cowork）。
///
/// 本组件只负责渲染，搜索状态由各页自己持有（和 [CustomizeToolbar] 一致），
/// 这样从列表退回 Discover 时搜索词不会串台。
class CustomizeShowAllView extends StatelessWidget {
  const CustomizeShowAllView.connectors({
    super.key,
    required this.title,
    required this.tabLabel,
    required this.skin,
    required this.l10n,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.onBack,
    this.onTune,
    this.onSort,
    this.onToolbarAdd,
    required List<ConnectorItem> this.connectorItems,
    this.searchHint,
  }) : skillItems = null,
       onAdd = null;

  const CustomizeShowAllView.skills({
    super.key,
    required this.title,
    required this.tabLabel,
    required this.skin,
    required this.l10n,
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.onBack,
    required this.onAdd,
    this.onTune,
    this.onSort,
    this.onToolbarAdd,
    required List<SkillItem> this.skillItems,
    this.searchHint,
  }) : connectorItems = null;

  /// 标题，例如 "All connectors"。
  final String title;

  /// 标题左边的 chip 文案，例如 "Connectors"。
  final String tabLabel;

  final AppSkin skin;
  final AppLocalizations l10n;
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;

  /// 左上角返回箭头：退回 Discover。
  final VoidCallback onBack;

  /// 工具条上的 category / sort / Add 按钮，和 Discover 页保持一致。
  final VoidCallback? onTune;
  final VoidCallback? onSort;
  final VoidCallback? onToolbarAdd;

  /// 行列表右侧 Add 按钮的点击回调。连接器网格没有这个按钮，构造时传 null。
  final void Function(SkillItem skill)? onAdd;

  final String? searchHint;
  final List<ConnectorItem>? connectorItems;
  final List<SkillItem>? skillItems;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBackRow(context),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: CustomizeToolbar(
            tabs: _buildTitle(),
            searchController: searchController,
            query: query,
            searchHint: searchHint,
            onQueryChanged: onQueryChanged,
            onTune: onTune,
            onSort: onSort,
            onAdd: onToolbarAdd,
          ),
        ),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  /// 最上面一行：返回箭头 + 分类 chip。
  Widget _buildBackRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxs,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back, size: 20, color: skin.text),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: AppSpacing.xxs),
          CustomizeTagChip(label: tabLabel, skin: skin),
        ],
      ),
    );
  }

  /// 标题交给工具条的左侧槽位，和搜索 + 操作按钮同处一行。
  Widget _buildTitle() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: skin.text,
          letterSpacing: -0.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final connectors = connectorItems;
    if (connectors != null) {
      if (connectors.isEmpty) return _buildEmpty();
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        children: [_buildConnectorGrid(connectors)],
      );
    }

    final skills = skillItems ?? const <SkillItem>[];
    if (skills.isEmpty) return _buildEmpty();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      itemCount: skills.length,
      itemBuilder: (context, index) {
        final skill = skills[index];
        return CustomizeShowAllRow(
          skill: skill,
          skin: skin,
          onAdd: () => onAdd?.call(skill),
        );
      },
    );
  }

  Widget _buildEmpty() {
    // 与 Discover / 各智能体子页同一句空态文案。
    return Center(
      child: Text(
        l10n.studioEmpty,
        style: TextStyle(fontSize: 14, color: skin.textSecondary),
      ),
    );
  }

  Widget _buildConnectorGrid(List<ConnectorItem> items) {
    // 列数按可用宽度自适应，与技能页/连接器页同一份逻辑。
    return ResponsiveCardWrap(
      children: [
        for (final connector in items)
          ConnectorCard(
            connector: connector,
            skin: skin,
            l10n: l10n,
            onTap: () {},
          ),
      ],
    );
  }
}
