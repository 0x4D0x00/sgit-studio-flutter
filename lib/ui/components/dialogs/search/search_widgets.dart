import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/dialogs/search/search_rows.dart';

/// 搜索框行：已生效的筛选小标签 + 输入框 + 关闭按钮。
class SearchHeader extends StatelessWidget {
  const SearchHeader({
    super.key,
    required this.skin,
    required this.l10n,
    required this.controller,
    required this.filters,
    required this.hintText,
    required this.onChanged,
    required this.onRemoveFilter,
    required this.onClose,
  });

  final AppSkin skin;
  final AppLocalizations l10n;
  final TextEditingController controller;
  final List<SearchAppliedFilter> filters;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<SearchAppliedFilter> onRemoveFilter;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.xs,
      AppSpacing.xxs,
    ),
    child: Row(
      children: [
        for (final f in filters) _filterChip(f),
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            cursorColor: skin.textSecondary,
            onChanged: onChanged,
            style: TextStyle(fontSize: 16, color: skin.text),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              // ⚠️ 三条都要显式置 none：主题的 `inputDecorationTheme` 给了
              // `enabledBorder` / `focusedBorder`，只写 `border` 时它们仍会画出
              // 一圈描边，搜索框会变成一只带框的输入框。
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxs,
                vertical: AppSpacing.xs,
              ),
              hintText: hintText,
              hintStyle: TextStyle(fontSize: 16, color: skin.textTertiary),
            ),
          ),
        ),
        ExcludeFocus(
          child: IconButton(
            icon: const Icon(Icons.close),
            iconSize: 20,
            color: skin.textSecondary,
            tooltip: l10n.commonClose,
            onPressed: onClose,
          ),
        ),
      ],
    ),
  );

  /// 搜索框左侧的已生效筛选，点 × 或在空输入框里退格即可撤掉。
  Widget _filterChip(SearchAppliedFilter f) => Container(
    margin: const EdgeInsets.only(right: AppSpacing.xxs),
    padding: const EdgeInsets.only(left: AppSpacing.xs),
    decoration: BoxDecoration(
      color: skin.textSecondary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppRadius.sm),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(f.label(l10n), style: TextStyle(fontSize: 13, color: skin.text)),
        InkWell(
          canRequestFocus: false,
          onTap: () => onRemoveFilter(f),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.close, size: 12, color: skin.textSecondary),
          ),
        ),
      ],
    ),
  );
}

/// 分类标签行。视觉与 [PillTabBar] 同一套（选中 = 8% 描底色 + w600），
/// 但这里要响应键盘切换并用滚动容器定位，所以不复用那个纯渲染组件。
class SearchTabsBar extends StatelessWidget {
  const SearchTabsBar({
    super.key,
    required this.skin,
    required this.l10n,
    required this.selected,
    required this.onSelect,
  });

  final AppSkin skin;
  final AppLocalizations l10n;
  final SearchTab selected;
  final ValueChanged<SearchTab> onSelect;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      0,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tab in SearchTab.values)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xxs),
            child: _pill(tab),
          ),
      ],
    ),
  );

  Widget _pill(SearchTab tab) {
    final isSelected = tab == selected;
    return InkWell(
      // 不接管焦点：否则方向键会被焦点遍历拿去，把某一行画成焦点灰底。
      canRequestFocus: false,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => onSelect(tab),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? skin.textSecondary.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          tab.label(l10n),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? skin.text : skin.textSecondary,
          ),
        ),
      ),
    );
  }
}

class SearchSectionHeader extends StatelessWidget {
  const SearchSectionHeader({
    super.key,
    required this.skin,
    required this.label,
    required this.first,
  });

  final AppSkin skin;
  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      AppSpacing.md,
      first ? AppSpacing.xs : AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.xxs,
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, color: skin.textTertiary),
    ),
  );
}

/// 行外壳：悬停/选中底色、圆角、键盘滚动锚点。
class SearchRowShell extends StatelessWidget {
  const SearchRowShell({
    super.key,
    required this.skin,
    required this.anchorKey,
    required this.highlighted,
    required this.onTap,
    required this.onHover,
    required this.child,
  });

  final AppSkin skin;

  /// 键盘滚动到该行用的锚点。
  final GlobalKey anchorKey;
  final bool highlighted;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;
  final Widget child;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: anchorKey,
    child: MouseRegion(
      // onHover 而非 onEnter：键盘滚动时行从静止的指针下滑过会误触发 onEnter，抢走键盘选中。
      onHover: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Material(
          color: highlighted
              ? skin.textSecondary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: InkWell(
            canRequestFocus: false,
            // 行底色由 [highlighted] 单独控制；InkWell 自带的 hover / focus / highlight / splash 蒙层一律关掉，避免叠出第二层灰。
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            hoverColor: Colors.transparent,
            onTap: onTap,
            child: Container(
              height: 40,
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              alignment: Alignment.centerLeft,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
}

/// 行尾的小图标按钮。
///
/// ⚠️ **必须把所有 overlay 关掉**：按钮浮在已经上过色的行底之上，
/// `IconButton` 默认的 hover / highlight / splash 蒙层会再叠一层灰，
/// 看上去就是一深一浅两块灰摞在一起。行的底色本身已经是反馈了。
class SearchRowTrailingButton extends StatelessWidget {
  const SearchRowTrailingButton({
    super.key,
    required this.skin,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final AppSkin skin;
  final IconData icon;
  final String? tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    height: 40,
    child: IconButton(
      icon: Icon(icon),
      iconSize: 15,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      color: skin.textSecondary,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        overlayColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: Colors.transparent,
      ),
      onPressed: onPressed,
    ),
  );
}

/// 行右侧「↵」提示，仅高亮行显示。
class _ReturnHint extends StatelessWidget {
  const _ReturnHint(this.skin);

  final AppSkin skin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.xs),
    child: Icon(Icons.keyboard_return, size: 14, color: skin.textTertiary),
  );
}

/// 命令行：`[图标] 文案`。
class SearchActionTile extends StatelessWidget {
  const SearchActionTile({
    super.key,
    required this.skin,
    required this.anchorKey,
    required this.highlighted,
    required this.onTap,
    required this.onHover,
    required this.label,
    required this.icon,
  });

  final AppSkin skin;
  final GlobalKey anchorKey;
  final bool highlighted;
  final VoidCallback onTap;
  final ValueChanged<bool> onHover;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SearchRowShell(
    skin: skin,
    anchorKey: anchorKey,
    highlighted: highlighted,
    onTap: onTap,
    onHover: onHover,
    child: Row(
      children: [
        Icon(icon, size: 16, color: skin.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: skin.text),
          ),
        ),
        if (highlighted) _ReturnHint(skin),
        const SizedBox(width: AppSpacing.xxs),
      ],
    ),
  );
}

/// 筛选候选行：`[图标] 筛选 [药丸]`，或只有文字的候选值。
class SearchSuggestionTile extends StatelessWidget {
  const SearchSuggestionTile({
    super.key,
    required this.skin,
    required this.anchorKey,
    required this.highlighted,
    required this.onHover,
    required this.row,
  });

  final AppSkin skin;
  final GlobalKey anchorKey;
  final bool highlighted;
  final ValueChanged<bool> onHover;
  final SearchSuggestionRow row;

  @override
  Widget build(BuildContext context) => SearchRowShell(
    skin: skin,
    anchorKey: anchorKey,
    highlighted: highlighted,
    onTap: row.onPick,
    onHover: onHover,
    child: Row(
      children: [
        if (row.icon != null) ...[
          Icon(row.icon, size: 16, color: skin.textSecondary),
          const SizedBox(width: AppSpacing.xs),
        ],
        Text(row.text, style: TextStyle(fontSize: 14, color: skin.text)),
        if (row.pill != null) ...[
          const SizedBox(width: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: skin.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              row.pill!,
              style: TextStyle(fontSize: 12, color: skin.textSecondary),
            ),
          ),
        ],
        const Spacer(),
        if (highlighted) _ReturnHint(skin),
        const SizedBox(width: AppSpacing.xxs),
      ],
    ),
  );
}

/// 当前标签 / 筛选下没有结果。
class SearchEmptyView extends StatelessWidget {
  const SearchEmptyView({
    super.key,
    required this.skin,
    required this.l10n,
    required this.tab,
    required this.onSearchAll,
  });

  final AppSkin skin;
  final AppLocalizations l10n;
  final SearchTab tab;

  /// 「搜索全部」：回到 All 标签并清掉筛选。
  final VoidCallback onSearchAll;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.searchNoResultsIn(tab.label(l10n)),
          style: TextStyle(fontSize: 14, color: skin.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: onSearchAll,
          style: OutlinedButton.styleFrom(
            foregroundColor: skin.text,
            side: BorderSide(color: skin.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            minimumSize: Size.zero,
            // ⚠️ 字号写在子 Text 上，别用 `styleFrom(textStyle:)` ——
            // 那会把主题里带 fontFamily / fontFamilyFallback 的按钮文字样式整个
            // 替换掉，中文没了随包 CJK 兜底，直接渲染成方框。
          ),
          child: Text(
            l10n.searchSearchAll,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );
}

/// 底栏快捷键提示。
class SearchFooter extends StatelessWidget {
  const SearchFooter({super.key, required this.skin, required this.l10n});

  final AppSkin skin;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    child: Row(
      children: [
        _hint(l10n.searchFooterClose, const ['Esc']),
        _hint(l10n.searchFooterChangeType, const ['←', '→']),
        // 「Filters /」—— 键帽仅作提示，不可点击；在搜索框里输入 `/` 才会列出筛选项。
        _hint(l10n.searchFooterFilters, const ['/']),
        _hint(l10n.searchFooterActions, const ['Alt', '↵']),
        const Spacer(),
        _hint(l10n.searchFooterCompose, const ['Tab']),
      ],
    ),
  );

  Widget _hint(String label, List<String> keys) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.md),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: skin.textTertiary)),
        const SizedBox(width: AppSpacing.xxs),
        for (final k in keys) _keycap(k),
      ],
    ),
  );

  Widget _keycap(String text) => Container(
    margin: const EdgeInsets.only(left: 2),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: skin.border),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: skin.textSecondary),
    ),
  );
}
