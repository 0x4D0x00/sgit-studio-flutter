import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 搜索弹窗里的一行 —— 展示用，选中后回传 [id] 给调用方。
@immutable
class SearchChatsDialogItem {
  const SearchChatsDialogItem({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

/// 居中搜索弹窗：顶部搜索框 + 下方历史会话列表，随输入实时过滤。
///
/// **纯展示组件**：数据（[items]）与选中后的动作（[onSelect]）都由调用方注入，
/// 弹窗本身只管过滤文案和渲染列表 —— 和 `confirm.dart` 一样的分工。
///
/// 选中一项会先关闭弹窗，再调用 [onSelect]。
Future<void> showSearchChatsDialog(
  BuildContext context, {
  required List<SearchChatsDialogItem> items,
  required ValueChanged<String> onSelect,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SearchChatsDialog(items: items, onSelect: onSelect),
  );
}

class _SearchChatsDialog extends StatefulWidget {
  const _SearchChatsDialog({required this.items, required this.onSelect});

  final List<SearchChatsDialogItem> items;
  final ValueChanged<String> onSelect;

  @override
  State<_SearchChatsDialog> createState() => _SearchChatsDialogState();
}

class _SearchChatsDialogState extends State<_SearchChatsDialog> {
  final _ctl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  List<SearchChatsDialogItem> get _filtered {
    if (_query.isEmpty) return widget.items;
    final q = _query.toLowerCase();
    return widget.items
        .where((e) => e.label.toLowerCase().contains(q))
        .toList(growable: false);
  }

  void _pick(String id) {
    Navigator.of(context).pop();
    widget.onSelect(id);
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final results = _filtered;

    return Dialog(
      backgroundColor: skin.containerBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: skin.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _searchField(skin, l10n),
            Divider(height: 1, thickness: 1, color: skin.borderSecondary),
            Flexible(
              child: results.isEmpty
                  ? _emptyHint(skin, l10n)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xxs,
                      ),
                      shrinkWrap: true,
                      itemCount: results.length,
                      itemBuilder: (_, i) => _row(skin, results[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchField(AppSkin skin, AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: TextField(
      controller: _ctl,
      autofocus: true,
      onChanged: (v) => setState(() => _query = v),
      style: TextStyle(fontSize: 15, color: skin.text),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        border: InputBorder.none,
        prefixIcon: Icon(Icons.search, color: skin.textSecondary),
        hintText: l10n.navSearchDialogHint,
        hintStyle: TextStyle(color: skin.textTertiary),
        suffixIcon: IconButton(
          icon: Icon(Icons.close, size: 18, color: skin.textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    ),
  );

  Widget _emptyHint(AppSkin skin, AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Text(
      l10n.navSearchDialogEmpty,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 13, color: skin.textTertiary),
    ),
  );

  Widget _row(AppSkin skin, SearchChatsDialogItem item) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => _pick(item.id),
      hoverColor: skin.navItemActive,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
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
