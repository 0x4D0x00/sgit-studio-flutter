import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

import 'customize_models.dart';

/// 单个连接器卡片。视觉与交互（悬停缩放 + 阴影）对齐 [SkillCard]，
/// 保证 Skills / Connectors 两个 Tab 下的卡片手感一致。
class ConnectorCard extends StatefulWidget {
  const ConnectorCard({
    super.key,
    required this.connector,
    required this.skin,
    required this.l10n,
    required this.onTap,
  });

  final ConnectorItem connector;
  final AppSkin skin;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  State<ConnectorCard> createState() => _ConnectorCardState();
}

class _ConnectorCardState extends State<ConnectorCard> {
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
                    widget.connector.icon,
                    size: 20,
                    color: widget.connector.color,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.connector.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: widget.skin.text,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xxs),
                          Icon(
                            Icons.verified,
                            size: 14,
                            color: widget.skin.textSecondary.withValues(alpha: 0.5),
                          ),
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
                          widget.connector.description,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.skin.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
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
                        content: Text(widget.l10n.commonNotWired(widget.connector.title)),
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
