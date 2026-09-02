import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/studio/application/studio_scope.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 个人 / 管理 切换器。放在各 studio 子页的页头。
///
/// ⚠️ 管理版**写的是全平台配置**，所以视觉上要有区别（选中管理时用警示色），
/// 不能让用户以为自己还在改个人设置。React studio 那边只是个素色 Segmented，
/// 这点我们做得更明确一些。
///
/// 门控：暂无管理员判权（与 React studio 一致，见 memory
/// `studio-scope-manage-personal-toggle`）—— 能进「智能体」菜单即可切。
class ScopeToggle extends ConsumerWidget {
  const ScopeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(studioScopeProvider);
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: skin.containerBgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in StudioScope.values)
            _seg(
              context: context,
              skin: skin,
              label: switch (s) {
                StudioScope.personal => l10n.studioScopePersonal,
                StudioScope.master => l10n.studioScopeMaster,
              },
              selected: scope == s,
              // 管理版选中时用警示色 —— 它改的是全平台数据。
              danger: s.isMaster,
              onTap: () => ref.read(studioScopeProvider.notifier).set(s),
            ),
        ],
      ),
    );
  }

  Widget _seg({
    required BuildContext context,
    required AppSkin skin,
    required String label,
    required bool selected,
    required bool danger,
    required VoidCallback onTap,
  }) {
    final accent =
        danger ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary;
    return Material(
      color: selected ? accent.withValues(alpha: 0.16) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? accent : skin.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 管理版警示条。放在页面内容顶部，提醒当前改动影响所有用户。
class ScopeBanner extends ConsumerWidget {
  const ScopeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(studioScopeProvider).isMaster) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      color: scheme.error.withValues(alpha: 0.10),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Icon(Icons.public_rounded, size: 13, color: scheme.error),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(l10n.studioScopeMasterHint,
                style: TextStyle(fontSize: 11, color: scheme.error)),
          ),
        ],
      ),
    );
  }
}
