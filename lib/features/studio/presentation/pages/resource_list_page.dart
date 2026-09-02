import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/studio/resource_item.dart';
import 'package:sgit_studio_flutter/features/studio/application/studio_controllers.dart';
import 'package:sgit_studio_flutter/features/studio/studio_page_specs.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/async_view.dart';

/// 通用资源列表页 —— **7 个 studio 子页共用这一个**，各页只是一份
/// [ResourcePageSpec]（见 memory `flutter-studio-pages-personal-only`）。
///
/// 这是"拒绝重"的兑现：不写 7 个几乎一样的页面。中转站是唯一例外（三级页 + CRUD），
/// 单独在 `relay_page.dart`。
class ResourceListPage extends ConsumerWidget {
  const ResourceListPage({super.key, required this.spec, required this.title});

  final ResourcePageSpec spec;
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final s = ref.watch(resourceListProvider(spec));
    final ctrl = ref.read(resourceListProvider(spec).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, skin, l10n, s.items.length, ctrl.reload),
        Expanded(
          child: AsyncView<ResourceItem>(
            loading: s.loading,
            error: s.error,
            stale: s.stale,
            isEmpty: s.items.isEmpty,
            emptyText: l10n.studioEmpty,
            retryText: l10n.commonRetry,
            onRetry: ctrl.reload,
            builder: (_) => ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.xs),
              itemCount: s.items.length,
              itemBuilder: (_, i) => _ResourceTile(
                item: s.items[i],
                spec: spec,
                onRemove: spec.removePath == null
                    ? null
                    : () => _confirmRemove(context, l10n, ctrl, s.items[i]),
                onRefresh: spec.refreshPath == null
                    ? null
                    : () => ctrl.refreshOne(s.items[i].id),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, AppSkin skin, AppLocalizations l10n,
          int count, VoidCallback onReload) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
        child: Row(
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: skin.text)),
            const SizedBox(width: AppSpacing.xs),
            Text('$count',
                style: TextStyle(fontSize: 12, color: skin.textTertiary)),
            const Spacer(),
            IconButton(
              iconSize: 18,
              tooltip: l10n.studioRefresh,
              color: skin.textSecondary,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: onReload,
            ),
          ],
        ),
      );

  Future<void> _confirmRemove(BuildContext context, AppLocalizations l10n,
      ResourceListController ctrl, ResourceItem item) async {
    // 删除不可逆，必须确认 —— 列表里误点一下就没了是最容易挨骂的交互。
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.studioRemoveConfirm(item.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.commonCancel)),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.studioRemove),
          ),
        ],
      ),
    );
    if (ok == true) await ctrl.remove(item.id);
  }
}

class _ResourceTile extends StatelessWidget {
  const _ResourceTile({
    required this.item,
    required this.spec,
    this.onRemove,
    this.onRefresh,
  });

  final ResourceItem item;
  final ResourcePageSpec spec;
  final VoidCallback? onRemove;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: skin.containerBgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: skin.borderSecondary),
      ),
      child: Row(
        children: [
          if (item.enabled != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Icon(
                item.enabled!
                    ? Icons.check_circle_outline_rounded
                    : Icons.remove_circle_outline_rounded,
                size: 16,
                color: item.enabled! ? skin.accentChip : skin.textTertiary,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name.isEmpty ? item.id : item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: skin.text)),
                if (item.description.isNotEmpty)
                  Text(item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(fontSize: 12, color: skin.textTertiary)),
              ],
            ),
          ),
          for (final f in spec.extraFields)
            if ((item.extras[f]?.toString() ?? '').isNotEmpty &&
                item.extras[f] != false)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Text(_fmt(f, item),
                    style:
                        TextStyle(fontSize: 11, color: skin.textTertiary)),
              ),
          if (onRefresh != null)
            IconButton(
              iconSize: 15,
              tooltip: l10n.studioRefresh,
              color: skin.textTertiary,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: onRefresh,
            ),
          if (onRemove != null)
            IconButton(
              iconSize: 15,
              tooltip: l10n.studioRemove,
              color: skin.textTertiary,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }

  /// 附加字段的显示。数组显示条数，其余直显。
  String _fmt(String field, ResourceItem it) => switch (it.extras[field]) {
        final List<Object?> l => '$field ${l.length}',
        final Object v => v.toString(),
        null => '',
      };
}
