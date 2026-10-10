import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

import 'customize_models.dart';
import 'customize_tag_chip.dart';

/// 全量列表（New skills / New plugins）里的一行。
///
/// 排版照着参考图：图标 → 标题 + 标签 chip → 右侧 Add 按钮。来源和描述各占
/// 一列，桌面宽度下并排，窄到这个宽度以下就叠成上下两行，免得两列都被挤成
/// 省略号。
class CustomizeShowAllRow extends StatefulWidget {
  const CustomizeShowAllRow({
    super.key,
    required this.skill,
    required this.skin,
    required this.onAdd,
  });

  final SkillItem skill;
  final AppSkin skin;
  final VoidCallback onAdd;

  @override
  State<CustomizeShowAllRow> createState() => _CustomizeShowAllRowState();
}

class _CustomizeShowAllRowState extends State<CustomizeShowAllRow> {
  /// 低于此宽度，来源与描述改为上下两行。
  static const double _sideBySideBreakpoint = 560;

  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: _hovering
              ? skin.textSecondary.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: skin.border.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: skin.textSecondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(widget.skill.icon, size: 16, color: skin.text),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _buildTexts(context)),
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton(
              onPressed: widget.onAdd,
              style: OutlinedButton.styleFrom(
                foregroundColor: skin.text,
                side: BorderSide(color: skin.border, width: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                minimumSize: const Size(0, 32),
              ),
              child: const Text(
                'Add',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTexts(BuildContext context) {
    final skin = widget.skin;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxWidth >= _sideBySideBreakpoint;

        final source = Text(
          'from ${widget.skill.source}',
          style: TextStyle(fontSize: 12, color: skin.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
        final description = Text(
          widget.skill.description,
          style: TextStyle(fontSize: 12, color: skin.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    widget.skill.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: skin.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final tag in widget.skill.tags) ...[
                  const SizedBox(width: AppSpacing.xxs),
                  CustomizeTagChip(label: tag, skin: skin),
                ],
              ],
            ),
            const SizedBox(height: 2),
            if (sideBySide)
              Row(
                children: [
                  Flexible(child: source),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: description),
                ],
              )
            else ...[
              source,
              description,
            ],
          ],
        );
      },
    );
  }
}
