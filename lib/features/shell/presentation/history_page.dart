import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/chat/application/thread_list_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/router/route_names.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/confirm.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 历史对话「查看全部」页 —— 左栏「历史对话」标题行那颗斜向箭头点开的完整列表。
/// 右上角「选择」进入多选态：整页变成 checkbox 列表 + 全选 + 批量删除；
/// 多选态下右上角 X 退出多选（不关页面），非多选态下 X 才返回工作台。
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  /// 条目 id 的前缀。
  ///
  /// ⚠️ 原先是 `'assistant:'` —— 因为这个页面**列的是场景标签而不是会话**。
  /// 后果不止显示错：那时"删除"调的是 `resourceListProvider(scenes).remove()`，
  /// **删掉的是场景定义本身**。数据源换成真 thread 后前缀跟着换；
  /// 下面每一处 `substring(_threadPrefix.length)` 都必须一起改 ——
  /// 漏一处就会把 threadId 当 sceneId 用。
  static const String _threadPrefix = 'thread:';

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
    final threads = ref.watch(threadListProvider).items;

    final items = [
      for (final t in threads)
        _HistoryItem(
          id: '$_threadPrefix${t.id}',
          // 标题的回落（用户改的名字 > 首条消息摘要 > "新对话"）在 Rust 侧
          // `thread_ops::display_title` 算好了，这边不再自己来一套 ——
          // 两边各算各的必然漂。
          label: t.title,
          updatedAt: t.updatedAt ?? t.createdAt,
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
    final total = ref.watch(threadListProvider).items.length;
    final allSelected = total > 0 && count == total;
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
            l10n.navHistory,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: skin.text,
            ),
          ),
          const Spacer(),
          if (_selecting) ...[
            Text(
              l10n.navSelectedCount(count),
              style: TextStyle(
                fontSize: 14,
                color: skin.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: _toggleSelectAll,
              child: Text(allSelected ? l10n.navDeselectAll : l10n.navSelectAll),
            ),
            const SizedBox(width: AppSpacing.xs),
            if (count > 0)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _delete(context, l10n),
                child: Text(l10n.commonDelete),
              ),
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
            FilledButton(
              onPressed: _newChat,
              child: Text(l10n.navNew),
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
    return _HistoryRow(
      item: item,
      selected: selected,
      selecting: _selecting,
      skin: skin,
      onTap: () => _selecting ? _toggleOne(item.id) : _pick(item.id),
      onToggleSelect: () => _toggleOne(item.id),
      onMenuAction: (action) => _handleMenuAction(context, action, item),
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
    final threads = ref.read(threadListProvider).items;
    setState(() {
      if (_selectedIds.length == threads.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(threads.map((e) => '$_threadPrefix${e.id}'));
      }
    });
  }

  /// 点开一条历史会话：载入它的消息，并让后续发言接在这条 thread 上。
  ///
  /// ⚠️ 原先这里是 `newChatWithScene(sceneId)` —— 开一个**空的新对话**，
  /// 历史消息一条都不载入。点"历史对话"却看不到任何历史，是这个页面
  /// 原先最主要的错。
  /// ⚠️ **先跳页，再载内容**，别反过来。
  ///
  /// 原先是 `await open()` → `context.go(home)`：内容没回来页面就不动，
  /// 长会话下用户反馈「点历史会话要过很久才能进 L2 页面」，期间毫无反馈。
  ///
  /// 现在 `beginOpenThread()` 同步清空并置"正在载入"，立刻跳；载入与错误
  /// 处理归 `ChatController.openThreadById`（本页此刻已卸载，接不住结果，
  /// 也弹不了 SnackBar —— 失败会以故障条的形式出现在工作台）。
  void _pick(String id) {
    final threadId = id.substring(_threadPrefix.length);
    // 不 await：`openThreadById` 的清空与置位在首个 await 之前，也就是**同步**
    // 跑完的，所以下一行跳过去时工作台已经是"正在载入"的干净状态。
    unawaited(
      ref.read(chatControllerProvider.notifier).openThreadById(threadId),
    );
    context.go(RouteNames.home);
  }

  /// 「新建」：等同点左栏「新建对话」—— 清空当前会话并回工作台，
  /// 此时没有 thread，左栏高亮落在「新建对话」行上。
  void _newChat() {
    ref.read(chatControllerProvider.notifier).newChat();
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
    // ⚠️ 删的是**会话**。原先走 `resourceListProvider(scenes).removeMany`，
    // 删掉的是场景定义本身 —— 数据损失级的错接。
    final threadIds = [
      for (final id in ids)
        if (id.startsWith(_threadPrefix)) id.substring(_threadPrefix.length),
    ];
    await ref.read(threadListProvider.notifier).removeMany(threadIds);
    _resetIfCurrentDeleted(threadIds);
    if (!mounted) return;
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _handleMenuAction(BuildContext context, String action, _HistoryItem item) {
    final l10n = AppLocalizations.of(context);
    final threadId = item.id.substring(_threadPrefix.length);

    switch (action) {
      case 'select':
        setState(() {
          _selecting = true;
          _selectedIds.add(item.id);
        });
      case 'pin':
        // sgcode 没有置顶能力（React studio 的「收藏」存在 gateway 自己的
        // per-cid KV 里，客户端这条路还没接）。**不拿别的字段假装** ——
        // 那会变成一个看着能用、实际不保存的功能。
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonNotWired('pin')),
            duration: const Duration(seconds: 1),
          ),
        );
      case 'rename':
        _rename(context, l10n, threadId, item.label);
      case 'delete':
        _deleteSingle(context, l10n, threadId, item.label);
    }
  }

  /// 重命名。走 sgcode 的 `thread/name/set`。
  Future<void> _rename(
    BuildContext context,
    AppLocalizations l10n,
    String threadId,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.navChatRename),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.chatRenameHint),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return; // 取消
    await ref.read(threadListProvider.notifier).rename(threadId, name.trim());
  }

  Future<void> _deleteSingle(
    BuildContext context,
    AppLocalizations l10n,
    String threadId,
    String label,
  ) async {
    final ok = await confirmDanger(
      context,
      title: l10n.studioRemoveConfirm(label),
      confirmText: l10n.commonDelete,
    );
    if (!ok) return;

    // ⚠️ **这里就是"删历史条目删掉场景定义"的修复点。**
    await ref.read(threadListProvider.notifier).remove(threadId);
    _resetIfCurrentDeleted([threadId]);
  }

  /// 删的正是当前打开的会话：工作台不能还挂着它，回到干净的新对话。
  void _resetIfCurrentDeleted(Iterable<String> deletedIds) {
    final current = ref.read(chatControllerProvider).currentThreadId;
    if (current != null && deletedIds.contains(current)) {
      ref.read(chatControllerProvider.notifier).newChat();
    }
  }
}

class _HistoryRow extends StatefulWidget {
  const _HistoryRow({
    required this.item,
    required this.selected,
    required this.selecting,
    required this.skin,
    required this.onTap,
    required this.onToggleSelect,
    required this.onMenuAction,
  });

  final _HistoryItem item;
  final bool selected;
  final bool selecting;
  final AppSkin skin;
  final VoidCallback onTap;
  final VoidCallback onToggleSelect;
  final ValueChanged<String> onMenuAction;

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _hovering = false;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final showMenu = !widget.selecting && (_hovering || _menuOpen);
    final date = _formatDate(context, widget.item.updatedAt);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        color: (_hovering && !_menuOpen)
            ? widget.skin.text.withValues(alpha: 0.06)
            : Colors.transparent,
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (widget.selecting) ...[
                  Checkbox(
                    value: widget.selected,
                    onChanged: (_) => widget.onToggleSelect(),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: Text(
                    widget.item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: widget.skin.text),
                  ),
                ),
                if (!widget.selecting && !showMenu && date != null)
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 13,
                      color: widget.skin.textTertiary,
                    ),
                  ),
                if (showMenu)
                  AppMenuAnchor(
                    entries: [
                      AppMenuAction(
                        icon: Icons.check,
                        label: l10n.navSelect,
                        onTap: () => widget.onMenuAction('select'),
                      ),
                      AppMenuAction(
                        icon: Icons.push_pin_outlined,
                        label: l10n.navChatPin,
                        shortcut: 'P',
                        onTap: () => widget.onMenuAction('pin'),
                      ),
                      AppMenuAction(
                        icon: Icons.edit_outlined,
                        label: l10n.navChatRename,
                        shortcut: 'R',
                        onTap: () => widget.onMenuAction('rename'),
                      ),
                      AppMenuAction(
                        icon: Icons.delete_outline,
                        label: l10n.commonDelete,
                        shortcut: 'D',
                        danger: true,
                        onTap: () => widget.onMenuAction('delete'),
                      ),
                    ],
                    trigger: AppMenuTrigger.tap,
                    align: AppMenuAlign.underEnd,
                    onOpenChanged: (open) => setState(() => _menuOpen = open),
                    child: Icon(
                      Icons.more_horiz,
                      size: 18,
                      color: widget.skin.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
    )
    );
  }
}

/// 列表项末尾的最后会话日期：今年内「Sep 28 / 9月28日」，跨年带年份。
String? _formatDate(BuildContext context, DateTime? t) {
  if (t == null) return null;
  final locale = Localizations.localeOf(context).toString();
  final fmt = t.year == DateTime.now().year
      ? DateFormat.MMMd(locale)
      : DateFormat.yMMMd(locale);
  return fmt.format(t);
}

@immutable
class _HistoryItem {
  const _HistoryItem({
    required this.id,
    required this.label,
    required this.updatedAt,
  });

  final String id;
  final String label;
  final DateTime? updatedAt;
}
