import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/studio/application/resource_list_controller.dart';
import 'package:sgit_studio_flutter/features/studio/studio_page_specs.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/router/route_names.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/confirm.dart';

/// 历史对话「查看全部」页 —— 左栏「历史对话」标题行那颗斜向箭头点开的完整列表。
///
/// 跟 [ArtifactsPage] 同一种落地方式：在中栏就地渲染整页，不是弹窗覆盖。
/// 顶栏结构也照抄 artifacts 那一套（标题 + 搜索按钮/内嵌搜索框 + 选择/关闭）。
///
/// 右上角「选择」进入多选态：整页变成 checkbox 列表 + 全选 + 批量删除；
/// 多选态下右上角 X 退出多选（不关页面），非多选态下 X 才返回工作台。
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  static const String _assistantPrefix = 'assistant:';

  bool _searchOpen = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  bool _selecting = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final scenes = ref.watch(resourceListProvider(StudioPageSpecs.scenes)).items;

    final items = [
      for (final sc in scenes)
        _HistoryItem(
          id: '$_assistantPrefix${sc.id}',
          label: sc.name.isEmpty ? sc.id : sc.name,
        ),
    ];
    final filtered = _searchQuery.isEmpty
        ? items
        : items
            .where((i) =>
                i.label.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, l10n, skin),
        Divider(height: 1, thickness: 1, color: skin.borderSecondary),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isEmpty
                        ? l10n.commonEmpty
                        : l10n.navSearchDialogEmpty,
                    style: TextStyle(fontSize: 13, color: skin.textTertiary),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _row(skin, filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    AppLocalizations l10n,
    AppSkin skin,
  ) {
    final count = _selectedIds.length;
    final scenesCount =
        ref.watch(resourceListProvider(StudioPageSpecs.scenes)).items.length;
    final allSelected = scenesCount > 0 && count == scenesCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            _selecting ? l10n.navSelectedCount(count) : l10n.navHistory,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: skin.text,
            ),
          ),
          const Spacer(),
          if (_selecting) ...[
            OutlinedButton(
              onPressed: _toggleSelectAll,
              child: Text(allSelected ? l10n.navDeselectAll : l10n.navSelectAll),
            ),
            if (count > 0) ...[
              const SizedBox(width: AppSpacing.xs),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _delete(context, l10n),
                child: Text(l10n.commonDelete),
              ),
            ],
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.commonClose,
              color: skin.textSecondary,
              onPressed: _toggleSelecting,
            ),
          ] else ...[
            _search(l10n, skin),
            const SizedBox(width: AppSpacing.xs),
            OutlinedButton(
              onPressed: _toggleSelecting,
              child: Text(l10n.navSelect),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: l10n.commonClose,
              color: skin.textSecondary,
              onPressed: () => context.go(RouteNames.home),
            ),
          ],
        ],
      ),
    );
  }

  /// 搜索按钮/内嵌搜索框 —— 跟 artifacts 页同一种交互，点击就地展开输入框，
  Widget _search(AppLocalizations l10n, AppSkin skin) {
    if (!_searchOpen) {
      return IconButton(
        icon: const Icon(Icons.search),
        iconSize: 20,
        tooltip: l10n.navSearch,
        color: skin.textSecondary,
        onPressed: () => setState(() => _searchOpen = true),
      );
    }
    return SizedBox(
      width: 240,
      height: 36,
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.navSearchDialogHint,
          prefixIcon: Icon(Icons.search, size: 18, color: skin.textSecondary),
          suffixIcon: IconButton(
            icon: const Icon(Icons.close),
            iconSize: 16,
            tooltip: l10n.commonClose,
            color: skin.textSecondary,
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchOpen = false;
                _searchQuery = '';
              });
            },
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _row(AppSkin skin, _HistoryItem item) {
    final selected = _selectedIds.contains(item.id);
    return Material(
      color: selected ? skin.navItemActive : Colors.transparent,
      child: InkWell(
        onTap: () =>
            _selecting ? _toggleOne(item.id) : _pick(context, item.id),
        hoverColor: skin.text.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              if (_selecting) ...[
                Checkbox(
                  value: selected,
                  onChanged: (_) => _toggleOne(item.id),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: skin.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSelecting() {
    setState(() {
      _selecting = !_selecting;
      _selectedIds.clear();
    });
  }

  void _toggleOne(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _toggleSelectAll() {
    final scenes = ref.read(resourceListProvider(StudioPageSpecs.scenes)).items;
    setState(() {
      if (_selectedIds.length == scenes.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(scenes.map((e) => '$_assistantPrefix${e.id}'));
      }
    });
  }

  void _pick(BuildContext context, String id) {
    final sceneId = id.substring(_assistantPrefix.length);
    ref.read(chatControllerProvider.notifier).newChatWithScene(sceneId);
    context.go(RouteNames.home);
  }

  Future<void> _delete(BuildContext context, AppLocalizations l10n) async {
    final ids = Set<String>.of(_selectedIds);
    if (ids.isEmpty) return;
    final ok = await confirmDanger(
      context,
      title: l10n.studioRemoveConfirmMany(ids.length),
      confirmText: l10n.commonDelete,
    );
    if (!ok) return;
    await ref
        .read(resourceListProvider(StudioPageSpecs.scenes).notifier)
        .removeMany([
      for (final id in ids)
        if (id.startsWith(_assistantPrefix)) id.substring(_assistantPrefix.length),
    ]);
    if (!mounted) return;
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }
}

@immutable
class _HistoryItem {
  const _HistoryItem({required this.id, required this.label});

  final String id;
  final String label;
}
