import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/router/route_names.dart';

/// 新建产物 —— 分类选择页。从「输出物」页点「新建」进来。
class ArtifactsNewPage extends StatelessWidget {
  const ArtifactsNewPage({super.key});

  // TODO:卡片点击跳转功能暂未实现
  void _notWired(BuildContext context, String what) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.commonNotWired(what)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);

    final categories = <_ArtifactCategory>[
      _ArtifactCategory(l10n.artifactsCategoryApps, Icons.public),
      _ArtifactCategory(
          l10n.artifactsCategoryDocs, Icons.description_outlined),
      _ArtifactCategory(
          l10n.artifactsCategoryGames, Icons.videogame_asset_outlined),
      _ArtifactCategory(l10n.artifactsCategoryProductivity, Icons.bolt),
      _ArtifactCategory(
          l10n.artifactsCategoryCreative, Icons.palette_outlined),
      _ArtifactCategory(l10n.artifactsCategoryQuiz, Icons.checklist),
      _ArtifactCategory(
          l10n.artifactsCategoryScratch, Icons.add_circle_outline),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, l10n, skin),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.artifactsNewHeading,
                        style: TextStyle(
                          fontSize: 14,
                          color: skin.text,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        alignment: WrapAlignment.start,
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          for (final c in categories)
                            _CategoryCard(
                              category: c,
                              onTap: () => _notWired(context, c.label),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    AppLocalizations l10n,
    AppSkin skin,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            l10n.artifactsNew,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: skin.text,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.commonClose,
            color: skin.textSecondary,
            onPressed: () => context.go(RouteNames.artifacts),
          ),
        ],
      ),
    );
  }
}

class _ArtifactCategory {
  const _ArtifactCategory(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// 分类卡片 —— 悬停/点击效果与产物卡片（[ArtifactCard]）一致。
class _CategoryCard extends StatefulWidget {
  const _CategoryCard({required this.category, required this.onTap});

  final _ArtifactCategory category;
  final VoidCallback onTap;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

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
            width: 120,
            height: 98,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: skin.containerBg,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: skin.borderSecondary),
              boxShadow: _hovering
                  ? [
                      BoxShadow(
                        color: skin.border.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: skin.text,
                    height: 1.3,
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Icon(
                    widget.category.icon,
                    size: 20,
                    color: skin.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
