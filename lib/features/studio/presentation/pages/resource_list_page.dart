import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/settings_repository.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/studio/resource_item.dart';
import 'package:sgit_studio_flutter/domain/models/studio/studio_group.dart';
import 'package:sgit_studio_flutter/app/app_providers.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/widgets/grouped_grid.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/widgets/resource_card.dart';
import 'package:sgit_studio_flutter/features/studio/application/resource_list_controller.dart';
import 'package:sgit_studio_flutter/features/studio/studio_page_specs.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/feedback/async_view.dart';

/// 通用资源列表页 —— **7 个 studio 子页共用这一个**，各页只是一份
/// [ResourcePageSpec]（见 memory `flutter-studio-pages-personal-only`）。
///
/// 这是"拒绝重"的兑现：不写 7 个几乎一样的页面。中转站是唯一例外（三级页 + CRUD），
/// 单独在 `relay_page.dart`。
class ResourceListPage extends ConsumerWidget {
  const ResourceListPage({
    super.key,
    required this.spec,
    required this.title,
    this.query = '',
  });

  final ResourcePageSpec spec;
  final String title;

  /// 页面顶部搜索框的词。空串表示不过滤。
  ///
  /// 搜索**在这层做**而不是由外层过滤数据：条目来自 provider，
  /// 外层看不到 spec 的字段映射（name/id/description 各页不同），
  /// 让各页自己按自己的字段过滤才不会搜漏。
  final String query;

  /// 按名称 / id / 描述模糊匹配。与技能库（`SkillLibraryGrid`）同一套判据 ——
  /// 同一个搜索框在不同 Tab 下不该有的搜得到、有的搜不到。
  List<ResourceItem> _filter(List<ResourceItem> items) {
    if (query.isEmpty) return items;
    final q = query.toLowerCase();
    return items
        .where(
          (it) =>
              it.name.toLowerCase().contains(q) ||
              it.id.toLowerCase().contains(q) ||
              it.description.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final s = ref.watch(resourceListProvider(spec));
    final ctrl = ref.read(resourceListProvider(spec).notifier);
    final items = _filter(s.items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, skin, l10n, s, ctrl, items.length),
        Expanded(
          child: AsyncView<ResourceItem>(
            loading: s.loading,
            error: s.error,
            stale: s.stale,
            // 有数据但被搜索滤空 → 走空态（"暂无内容"），
            // 而不是留一片什么都没有的白底。
            isEmpty: items.isEmpty,
            emptyText: l10n.studioEmpty,
            retryText: l10n.commonRetry,
            onRetry: ctrl.reload,
            // 分组卡片网格（照 React studio）：这些条目天然分属四个团队，
            // 目录名就是分组 —— 平铺一列会把"这是渗透的还是防护的"埋掉。
            builder: (_) => GroupedGrid<ResourceItem>(
              buckets: groupByIdPrefix<ResourceItem>(
                items,
                studioGroupsFor(spec.key),
                (it) => it.id,
              ),
              itemBuilder: (ctx, item) => ResourceCard(
                item: item,
                spec: spec,
                group: _groupOf(item),
                unsynced: s.unsyncedIds.contains(item.id),
                onRemove: spec.removePath == null
                    ? null
                    : () => _confirmRemove(context, l10n, ctrl, item),
                // 「从母版重置」桌面端暂不支持（母版只在服务器上，
                // 需要一个新的 Go 接口）—— 没有本地副本的平台（Web）才显示。
                onRefresh: spec.refreshPath == null || _hasLocalCopy(ref)
                    ? null
                    : () => ctrl.refreshOne(item.id),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 条目所属分组（供卡片取色与图标）。与网格的分桶用同一份判据。
  StudioGroup _groupOf(ResourceItem item) {
    final groups = studioGroupsFor(spec.key);
    final seg = item.id.contains('/') ? item.id.split('/').first : item.id;
    return groups.firstWhere(
      (g) => g.key == seg,
      orElse: () => studioGeneralGroup,
    );
  }

  static bool _hasLocalCopy(WidgetRef ref) =>
      ref.read(settingsRepositoryProvider).hasLocalCopy;

  Widget _header(
    BuildContext context,
    AppSkin skin,
    AppLocalizations l10n,
    ResourceListState s,
    ResourceListController ctrl,
    int count,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.md,
      AppSpacing.xs,
    ),
    child: Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: skin.text,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        // 有搜索词时显示的是**命中数**，与下面列表对得上。
        Text(
          '$count',
          style: TextStyle(fontSize: 12, color: skin.textTertiary),
        ),
        const Spacer(),
        // 同步入口只在**有本地副本**的平台出现（桌面/移动）。
        // Web 本身就在服务器上，给它一个"同步"按钮只会让人困惑。
        if (s.unsyncedIds.isNotEmpty || s.syncing)
          IconButton(
            iconSize: 18,
            tooltip: l10n.studioSyncNow,
            color: skin.textSecondary,
            icon: s.syncing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            onPressed: s.syncing ? null : () => _runSync(context, l10n, ctrl),
          ),
        IconButton(
          iconSize: 18,
          tooltip: l10n.studioRefresh,
          color: skin.textSecondary,
          icon: const Icon(Icons.refresh_rounded),
          // force：用户主动点的，必须真跑，不能被合并窗口吞掉。
          onPressed: () => ctrl.reload(force: true),
        ),
      ],
    ),
  );

  Future<void> _runSync(
    BuildContext context,
    AppLocalizations l10n,
    ResourceListController ctrl,
  ) async {
    final out = await ctrl.sync();
    if (!context.mounted) return;

    // 冲突要明确告诉用户，且说清"本地那份还在" —— 否则他会以为自己的改动没了。
    final text = switch (out) {
      SyncOutcome(ok: false, reason: final r) => r,
      SyncOutcome(conflicts: final c) when c.isNotEmpty =>
        l10n.studioSyncConflicts(c.length),
      _ => l10n.studioSyncDone,
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _confirmRemove(
    BuildContext context,
    AppLocalizations l10n,
    ResourceListController ctrl,
    ResourceItem item,
  ) async {
    // 删除不可逆，必须确认 —— 列表里误点一下就没了是最容易挨骂的交互。
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l10n.studioRemoveConfirm(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.studioRemove),
          ),
        ],
      ),
    );
    if (ok == true) await ctrl.remove(item.id);
  }
}
