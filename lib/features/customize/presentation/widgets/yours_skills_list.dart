import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

import 'customize_models.dart';

/// "Yours" view for Skills/Plugins - list layout with "From Anthropic & Partners" header
class YoursSkillsList extends StatelessWidget {
  const YoursSkillsList({
    super.key,
    required this.items,
    required this.skin,
    required this.onItemTap,
    required this.onMenuTap,
  });

  final List<YourSkillItem> items;
  final AppSkin skin;
  final Function(YourSkillItem) onItemTap;
  final Function(YourSkillItem) onMenuTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _buildSectionHeader(skin),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: skin.containerBg,
            border: Border.all(color: skin.border, width: 1),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                _YourSkillItemRow(
                  item: items[i],
                  skin: skin,
                  onTap: () => onItemTap(items[i]),
                  onMenuTap: () => onMenuTap(items[i]),
                ),
                if (i < items.length - 1)
                  Divider(height: 1, thickness: 1, color: skin.border),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(AppSkin skin) {
    return Row(
      children: [
        Text(
          'From Anthropic & Partners',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: skin.text,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          items.length.toString(),
          style: TextStyle(
            fontSize: 14,
            color: skin.textSecondary,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(Icons.close, size: 18, color: skin.textSecondary),
          onPressed: () {},
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}

class _YourSkillItemRow extends StatefulWidget {
  const _YourSkillItemRow({
    required this.item,
    required this.skin,
    required this.onTap,
    required this.onMenuTap,
  });

  final YourSkillItem item;
  final AppSkin skin;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  @override
  State<_YourSkillItemRow> createState() => _YourSkillItemRowState();
}

class _YourSkillItemRowState extends State<_YourSkillItemRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.md),
          color: _hovering
              ? widget.skin.textSecondary.withValues(alpha: 0.03)
              : Colors.transparent,
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
                  Icons.description,
                  size: 20,
                  color: widget.skin.text,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.item.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: widget.skin.text,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: widget.skin.textSecondary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            widget.item.badge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: widget.skin.textSecondary,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.item.time,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.skin.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'from ${widget.item.source}',
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.skin.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      widget.item.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.skin.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                icon: Icon(Icons.more_horiz, color: widget.skin.textSecondary),
                onPressed: widget.onMenuTap,
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
