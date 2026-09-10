import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/artifact/artifact.dart';
import 'package:sgit_studio_flutter/features/artifacts/application/artifacts_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 输出产物页 —— 点左栏「输出物」进来的主页。
///
/// 顶栏：标题（左）+ 搜索 + 日期范围筛选（右）
/// 主区：产物卡片网格（无数据时显示空态）
class ArtifactsPage
    extends
        ConsumerStatefulWidget {
  const ArtifactsPage({
    super.key,
  });

  @override
  ConsumerState<
    ArtifactsPage
  >
  createState() => _ArtifactsPageState();
}

class _ArtifactsPageState
    extends
        ConsumerState<
          ArtifactsPage
        > {
  bool _searchOpen = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final l10n = AppLocalizations.of(
      context,
    );
    final skin = AppSkin.of(
      context,
    );
    final state = ref.watch(
      artifactsControllerProvider,
    );
    final ctrl = ref.read(
      artifactsControllerProvider.notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(
          context,
          l10n,
          skin,
          state,
          ctrl,
        ),
        Expanded(
          child: state.filtered.isEmpty
              ? _emptyState(
                  l10n,
                  skin,
                )
              : _grid(
                  context,
                  l10n,
                  skin,
                  state.filtered,
                ),
        ),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    AppLocalizations l10n,
    AppSkin skin,
    ArtifactsState state,
    ArtifactsController ctrl,
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
            l10n.artifactsTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: skin.text,
            ),
          ),
          const Spacer(),
          if (_searchOpen)
            SizedBox(
              width: 240,
              height: 36,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.artifactsSearchHint,
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: skin.textSecondary,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    iconSize: 16,
                    tooltip: l10n.artifactsSearchClose,
                    color: skin.textSecondary,
                    onPressed: () {
                      setState(
                        () => _searchOpen = false,
                      );
                      _searchController.clear();
                      ctrl.setSearchQuery(
                        '',
                      );
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppRadius.sm,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                ),
                onChanged: ctrl.setSearchQuery,
              ),
            )
          else
            IconButton(
              icon: const Icon(
                Icons.search,
              ),
              iconSize: 20,
              tooltip: l10n.artifactsSearch,
              color: skin.textSecondary,
              onPressed: () => setState(
                () => _searchOpen = true,
              ),
            ),
          const SizedBox(width: AppSpacing.xs),
          _rangeMenu(l10n, skin, state.range, ctrl),
        ],
      ),
    );
  }

  Widget _rangeMenu(
    AppLocalizations l10n,
    AppSkin skin,
    ArtifactDateRange current,
    ArtifactsController ctrl,
  ) {
    String
    label(
      ArtifactDateRange r,
    ) => switch (r) {
      ArtifactDateRange.today => l10n.artifactsRangeToday,
      ArtifactDateRange.week => l10n.artifactsRangeWeek,
      ArtifactDateRange.month => l10n.artifactsRangeMonth,
      ArtifactDateRange.year => l10n.artifactsRangeYear,
      ArtifactDateRange.all => l10n.artifactsRangeAll,
    };

    return AppMenuAnchor(
      semanticLabel: l10n.artifactsRange,
      entries: [
        AppMenuRadioGroup<ArtifactDateRange>(
          values: ArtifactDateRange.values,
          selected: current,
          labelOf: label,
          onSelect: ctrl.setRange,
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: skin.borderSecondary),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label(current),
              style: TextStyle(fontSize: 14, color: skin.text),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 20, color: skin.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget
  _emptyState(
    AppLocalizations l10n,
    AppSkin skin,
  ) => Padding(
    padding: const EdgeInsets.all(
      AppSpacing.lg,
    ),
    child: Text(
      l10n.artifactsEmpty,
      style: TextStyle(
        fontSize: 14,
        color: skin.textTertiary,
      ),
    ),
  );

  Widget _grid(
    BuildContext context,
    AppLocalizations l10n,
    AppSkin skin,
    List<
      Artifact
    >
    items,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 1200,
          ),
          child: Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final a in items)
                _card(
                  context,
                  l10n,
                  skin,
                  a,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context,
    AppLocalizations l10n,
    AppSkin skin,
    Artifact a,
  ) {
    final locale = Localizations.localeOf(
      context,
    );
    final fmt = DateFormat.MMMd(
      locale.toString(),
    );
    final now = DateTime.now();
    final sameYear =
        a.updatedAt.year ==
        now.year;
    final when = sameYear
        ? fmt.format(
            a.updatedAt,
          )
        : DateFormat.yMMMd(
            locale.toString(),
          ).format(
            a.updatedAt,
          );

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: skin.containerBg,
        borderRadius: BorderRadius.circular(
          AppRadius.md,
        ),
        border: Border.all(
          color: skin.borderSecondary,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 代码预览区
          Container(
            height: 120,
            padding: const EdgeInsets.all(
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: skin.containerBgSecondary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(
                  AppRadius.md,
                ),
              ),
            ),
            child: Text(
              a.preview,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: skin.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: skin.text,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                Text(
                  l10n.artifactsEdited(
                    when,
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: skin.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
