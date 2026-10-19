import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/studio/resource_item.dart';
import 'package:sgit_studio_flutter/domain/models/studio/studio_group.dart';
import 'package:sgit_studio_flutter/features/studio/studio_page_specs.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/hover_lift.dart';

/// 资源卡片 —— 照 React studio 的卡片规格（`sgcodeGlass.ts`）：
/// 圆角 16、内边距 14×16、标题与描述各 2 行截断、底部一排标签。
///
/// 与旧的 `_ResourceTile`（平铺一行）的区别不只是外观：分组网格下
/// **卡片要自己承载分组色**，否则一屏几十张卡看不出归属。
class ResourceCard extends StatelessWidget {
  const ResourceCard({
    super.key,
    required this.item,
    required this.spec,
    required this.group,
    this.unsynced = false,
    this.onTap,
    this.onRemove,
    this.onRefresh,
  });

  final ResourceItem item;
  final ResourcePageSpec spec;
  final StudioGroup group;

  /// 本地已改、尚未上行。桌面/移动才可能为 true。
  final bool unsynced;

  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final accent = group.hue.of(context);

    return HoverLift(
      builder: (_, hovering) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: skin.containerBgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
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
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _titleRow(context, skin, l10n, accent),
                  if (item.description.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: skin.textTertiary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  _tagRow(skin),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titleRow(
    BuildContext context,
    AppSkin skin,
    AppLocalizations l10n,
    Color accent,
  ) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2, right: AppSpacing.xxs),
        child: Icon(group.icon, size: 15, color: accent),
      ),
      Expanded(
        child: Text(
          // name 为空时退回 id 末段 —— 与 React 的
          // `item.name || item.id` 同语义。
          item.name.isNotEmpty ? item.name : item.id.split('/').last,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            height: 1.35,
            color: skin.text,
          ),
        ),
      ),
      // 未同步角标：**不是错误**，所以用中性色不用报错红 ——
      // 用户的改动已经保住了，只是还在队列里。
      if (unsynced)
        Tooltip(
          message: l10n.studioUnsyncedHint,
          child: Icon(
            Icons.cloud_off_rounded,
            size: 13,
            color: skin.textTertiary,
          ),
        ),
      if (onRefresh != null)
        _iconBtn(
          Icons.refresh_rounded,
          l10n.studioRefresh,
          onRefresh!,
          skin.textTertiary,
        ),
      if (onRemove != null)
        _iconBtn(
          Icons.delete_outline_rounded,
          l10n.studioRemove,
          onRemove!,
          skin.textTertiary,
        ),
    ],
  );

  Widget _iconBtn(IconData icon, String tip, VoidCallback onTap, Color color) =>
      Tooltip(
        message: tip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(icon, size: 14, color: color),
          ),
        ),
      );

  /// 底部标签行：开关状态 + spec 登记的附加字段（model、子 Agent 计数等）。
  Widget _tagRow(AppSkin skin) {
    final tags = <Widget>[];

    if (item.enabled != null) {
      tags.add(
        _tag(
          skin,
          item.enabled! ? '已启用' : '已停用',
          color: item.enabled! ? skin.accentChip : skin.textTertiary,
        ),
      );
    }

    for (final f in spec.extraFields) {
      final raw = item.extras[f];
      if (raw == null || raw == false) continue;
      // 数组字段显示条数（子 Agent），其余显示值本身（model 等）。
      final text = raw is List
          ? (raw.isEmpty ? null : '${_labelFor(f)} ${raw.length}')
          : raw.toString();
      if (text == null || text.isEmpty) continue;
      tags.add(_tag(skin, text, color: skin.textSecondary));
    }

    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: AppSpacing.xxs, runSpacing: 2, children: tags);
  }

  static String _labelFor(String field) => switch (field) {
    'subagents' => '子 Agent',
    'toolCount' => '工具',
    _ => field,
  };

  Widget _tag(AppSkin skin, String text, {required Color color}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: skin.containerBg,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: skin.borderSecondary),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 10.5, color: color),
    ),
  );
}
