import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/studio/studio_group.dart';

/// 分组卡片网格 —— studio 各资源页的骨架。
///
/// 照 React studio 的规格（`sgcodeGlass.ts`）：
/// - 组头：图标（分组色）+ 标签 + `· N` 计数；
/// - 网格：`minmax(340px, 1fr)` + gap 16 → Flutter 用 [SliverGridDelegate]
///   的 `maxCrossAxisExtent` 近似（Flutter 没有 CSS 的 auto-fill）。
///
/// 为什么不是平铺列表：这些页的条目天然分属四个团队（目录名就是分组），
/// 一列铺下来会把「这是渗透的还是防护的」这个最重要的信息埋掉。
class GroupedGrid<T> extends StatelessWidget {
  const GroupedGrid({
    super.key,
    required this.buckets,
    required this.itemBuilder,
  });

  final List<StudioGroupBucket<T>> buckets;
  final Widget Function(BuildContext, T) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        for (final b in buckets) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
            sliver: SliverToBoxAdapter(
              child: _GroupHeader(group: b.group, count: b.items.length),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                // React 是 minmax(340px)；Flutter 用 max 近似 ——
                // 窄窗口下会自动降到一列，与 auto-fill 的观感一致。
                maxCrossAxisExtent: 420,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                // 卡片高度固定：内容行数不定（有无描述、有无标签），
                // 用 extent 而不是 aspectRatio，窄窗口下才不会被压扁。
                mainAxisExtent: 116,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => itemBuilder(ctx, b.items[i]),
                childCount: b.items.length,
              ),
            ),
          ),
        ],
        // 底部留白，最后一组的卡片不贴边。
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
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
    final color = group.hue.of(context);

    return Row(
      children: [
        Icon(group.icon, size: 17, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          group.label,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: skin.text),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text('· $count',
            style: TextStyle(fontSize: 12, color: skin.textTertiary)),
      ],
    );
  }
}
