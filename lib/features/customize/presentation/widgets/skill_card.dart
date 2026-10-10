import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

import 'customize_models.dart';
import 'customize_tag_chip.dart';

class SkillCard extends StatefulWidget {
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
  State<SkillCard> createState() => _SkillCardState();
}

class _SkillCardState extends State<SkillCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.01 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: widget.skin.containerBg,
              border: Border.all(
                color: widget.skin.border,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: widget.skin.border.withValues(alpha: 0.4),
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
                    color: widget.skin.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    widget.skill.icon,
                    size: 20,
                    color: widget.skin.text,
                  ),
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
                              widget.skill.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: widget.skin.text,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          for (final tag in widget.skill.tags) ...[
                            const SizedBox(width: AppSpacing.xxs),
                            CustomizeTagChip(label: tag, skin: widget.skin),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      // 描述区域至少预留两行高度，保证单行/双行描述的卡片等高。
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight:
                              MediaQuery.textScalerOf(context).scale(13) * 1.4 * 2,
                        ),
                        child: Text(
                          widget.skill.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.skin.textSecondary,
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
                              widget.skill.source,
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.skin.textSecondary.withValues(alpha: 0.7),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Text(
                            '·',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.skin.textSecondary.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Flexible(
                            child: Text(
                              widget.skill.installs,
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.skin.textSecondary.withValues(alpha: 0.7),
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
                  icon: Icon(Icons.add, color: widget.skin.text),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(widget.l10n.commonNotWired(widget.skill.title)),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  iconSize: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
