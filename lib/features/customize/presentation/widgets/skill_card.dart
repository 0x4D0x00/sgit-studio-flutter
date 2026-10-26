import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/primitives/hover_lift.dart';

import '../../data/customize_models.dart';
import 'customize_tag_chip.dart';

/// 单个技能卡片。悬停手感与 [ConnectorCard] 一致 —— 两者共用 [HoverLift]。
class SkillCard extends StatelessWidget {
  const SkillCard({
    super.key,
    required this.skill,
    required this.skin,
    required this.l10n,
    required this.onTap,
  });

  final SkillItem skill;
  final AppSkin skin;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      builder: (_, hovering) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: skin.containerBg,
            border: Border.all(color: skin.border, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.md),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: skin.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(skill.icon, size: 20, color: skin.text),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  // 与 [ConnectorCard] 一致：外层高度由内容决定，卡片等高由下面描述的 minHeight 保证
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题固定单行 + 省略号
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            skill.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: skin.text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        for (final tag in skill.tags) ...[
                          const SizedBox(width: AppSpacing.xxs),
                          CustomizeTagChip(label: tag, skin: skin),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    // 描述区域至少预留两行高度，保证单行/双行描述的卡片等高。
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            MediaQuery.textScalerOf(context).scale(12) *
                            1.4 *
                            2,
                      ),
                      child: Text(
                        skill.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: skin.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            skill.source,
                            style: TextStyle(
                              fontSize: 12,
                              color: skin.textSecondary.withValues(alpha: 0.7),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          '·',
                          style: TextStyle(
                            fontSize: 12,
                            color: skin.textSecondary.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Flexible(
                          child: Text(
                            skill.installs,
                            style: TextStyle(
                              fontSize: 12,
                              color: skin.textSecondary.withValues(alpha: 0.7),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: Icon(Icons.add, color: skin.text),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(l10n.commonNotWired(skill.title)),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                iconSize: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
