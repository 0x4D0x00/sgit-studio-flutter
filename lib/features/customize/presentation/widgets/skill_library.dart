import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/studio/resource_item.dart';
import 'package:sgit_studio_flutter/domain/models/studio/studio_group.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/studio_group_style.dart';
import 'package:sgit_studio_flutter/features/studio/application/resource_list_controller.dart';
import 'package:sgit_studio_flutter/app/app_providers.dart';
import 'package:sgit_studio_flutter/features/studio/studio_page_specs.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/feedback/async_view.dart';
import 'package:sgit_studio_flutter/ui/feedback/confirm.dart';
import 'package:sgit_studio_flutter/ui/primitives/hover_lift.dart';

import 'package:sgit_studio_flutter/ui/primitives/responsive_card_wrap.dart';

/// 技能库 —— **设置弹窗与 Customize 页共用这一份**。
///
/// ## 为什么抽出来
///
/// 这两处是同一件事的两种入口：都读 `~/.sgitai/skills/**\/SKILL.md`。
/// 先前 Customize 用的是 `buildForYouSkills()` / `buildNewSkills()` 那套**假数据**
/// （Anthropic 的 analyze、build-dashboard …），设置页用的是真源，
/// 于是同一个「Skills」两个入口内容完全不同 —— 用户看到的是两个故事。
///
/// 现在两边都走 [`StudioPageSpecs.skill`] → `sgit_studio_read("skill")`
/// （桌面 FFI 直读，零网络）。任何一处改了分组/卡片样式，另一处自动跟上。
///
/// ## Discover / Yours 的分工
///
/// - **Discover**：目录里已有的技能（= 母版下发到本机的那份）。
/// - **Yours**：用户自己新建的。目前**没有新建入口**，所以恒为空态。
///   ⚠️ 不要拿「基线账本之外的文件」反推自建 —— 账本只覆盖少数目录
///   （本机实测 209 个技能里只有 5 个在账本），那样分会把母版来的技能
///   误判成用户自建。
class SkillLibraryGrid extends ConsumerWidget {
  const SkillLibraryGrid({super.key, this.query = ''});

  /// 外部搜索词（工具条的搜索框）。空串表示不过滤。
  final String query;

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

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    ResourceItem item,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(settingsRepositoryProvider);
    final ctrl = ref.read(resourceListProvider(StudioPageSpecs.skill).notifier);
    final title = item.name.isNotEmpty ? item.name : item.id.split('/').last;

    final ok = await confirmDanger(
      context,
      title: l10n.studioRemoveConfirm(title),
      confirmText: l10n.studioRemove,
    );
    if (!ok) return;

    try {
      await repo.removeFromPage('skill', item.id);
      await ctrl.reload(force: true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.commonDeleted)));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const spec = StudioPageSpecs.skill;
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(resourceListProvider(spec));
    final ctrl = ref.read(resourceListProvider(spec).notifier);
    final items = _filter(s.items);

    return AsyncView<ResourceItem>(
      loading: s.loading,
      error: s.error,
      stale: s.stale,
      isEmpty: items.isEmpty,
      emptyText: l10n.studioEmpty,
      retryText: l10n.commonRetry,
      onRetry: ctrl.reload,
      builder: (_) => _SkillGroups(
        items: items,
        onRemove: (item) => _remove(context, ref, item),
      ),
    );
  }
}

/// Yours 空态。两处共用同一句文案 —— 分开写迟早会各说各话。
class SkillsYoursEmpty extends StatelessWidget {
  const SkillsYoursEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_outlined, size: 32, color: skin.textTertiary),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.skillsYoursEmptyTitle,
            style: TextStyle(fontSize: 14, color: skin.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            l10n.skillsYoursEmptyHint,
            style: TextStyle(fontSize: 12, color: skin.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// 按 id 首段分组铺卡片。
///
/// 分组用 [studioGroupsFor]（技能页 = 团队分组 + Web/设计/研发三组），
/// 与 Rust 侧 `read_skills` 给出的 id 形状一致 —— 未匹配的落「通用」。
class _SkillGroups extends StatelessWidget {
  const _SkillGroups({required this.items, required this.onRemove});

  final List<ResourceItem> items;
  final void Function(ResourceItem) onRemove;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final buckets = groupByIdPrefix<ResourceItem>(
      items,
      studioGroupsFor('skill'),
      (it) => it.id,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      children: [
        for (final b in buckets) ...[
          _GroupHeader(group: b.group, count: b.items.length),
          // 列数由 [ResponsiveCardWrap] 按可用宽度算 —— 与连接器/插件页同一份逻辑。
          ResponsiveCardWrap(
            children: [
              for (final it in b.items)
                _SkillCard(
                  item: it,
                  skin: skin,
                  l10n: l10n,
                  onRemove: () => onRemove(it),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.count});

  final StudioGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(group.icon, size: 15, color: group.hue.of(context)),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            group.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: skin.text,
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            '· $count',
            style: TextStyle(fontSize: 12, color: skin.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// 一张技能卡：名称 + 路径 + 描述 + 删除。
///
/// 悬停手感与 [ConnectorCard] 一致：轻微放大 + 阴影浮起（共用 [HoverLift]）。
class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.item,
    required this.skin,
    required this.l10n,
    required this.onRemove,
  });

  final ResourceItem item;
  final AppSkin skin;
  final AppLocalizations l10n;
  final VoidCallback onRemove;

  /// 描述固定占位高度 = 12px 字号 × 1.5 行高 × 3 行。
  static const double _descMinHeight = 12 * 1.5 * 3;

  @override
  Widget build(BuildContext context) {
    final title = item.name.isNotEmpty ? item.name : item.id.split('/').last;
    return HoverLift(
      builder: (_, hovering) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: skin.containerBg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: skin.borderSecondary),
          boxShadow: hovering
              ? [
                  BoxShadow(
                    color: skin.border.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: skin.text,
                    ),
                  ),
                ),
                Tooltip(
                  message: l10n.studioRemove,
                  child: InkWell(
                    onTap: onRemove,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 15,
                        color: skin.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              item.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: skin.textTertiary),
            ),
            const SizedBox(height: AppSpacing.xs),
            // 描述区固定占三行高度：一行/空描述的卡片不会矮一截，
            // 同一行的卡片底边始终对齐。
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _descMinHeight),
              child: Text(
                item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: skin.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
