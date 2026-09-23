import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// Yours 页面的列表项样式（图1）
class YoursListItem extends StatefulWidget {
  const YoursListItem({
    super.key,
    required this.icon,
    required this.title,
    required this.source,
    required this.description,
    required this.timeAgo,
    required this.skin,
    required this.onTap,
    required this.onRemove,
  });

  final IconData icon;
  final String title;
  final String source;
  final String description;
  final String timeAgo;
  final AppSkin skin;
  final VoidCallback onTap;

  /// 「···」菜单里的 Remove 项。
  final VoidCallback onRemove;

  @override
  State<YoursListItem> createState() => _YoursListItemState();
}

class _YoursListItemState extends State<YoursListItem> {
  bool _hovering = false;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _hovering
                ? widget.skin.textSecondary.withValues(alpha: 0.05)
                : Colors.transparent,
            border: Border(
              bottom: BorderSide(
                color: widget.skin.border.withValues(alpha: 0.5),
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
                  color: widget.skin.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  widget.icon,
                  size: 16,
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
                          widget.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.skin.text,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: widget.skin.textSecondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            'Data',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.skin.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'from ${widget.source}',
                          style: TextStyle(
                            fontSize: 12,
                            color: widget.skin.textSecondary,
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
                        Expanded(
                          child: Text(
                            widget.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.skin.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                widget.timeAgo,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.skin.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppMenuAnchor(
                trigger: AppMenuTrigger.tap,
                align: AppMenuAlign.underEnd,
                minWidth: 160,
                semanticLabel: l10n.projectsMoreActions,
                onOpenChanged: (open) => setState(() => _menuOpen = open),
                entries: [
                  AppMenuAction(
                    icon: Icons.delete_outline,
                    label: l10n.studioRemove,
                    danger: true,
                    onTap: widget.onRemove,
                  ),
                ],
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _menuOpen
                        ? widget.skin.textSecondary.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.more_horiz,
                    size: 20,
                    color: widget.skin.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
