import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

/// 用于分组相关设置行的部分标题。
/// 在设置对话框的“常规 / 账户 / 隐私”页面中共享，以便它们呈现一致的内部结构。
class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

/// 用于分组相关设置行的分隔线。
class SettingsSectionDivider extends StatelessWidget {
  const SettingsSectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4);
    return Divider(height: 1, thickness: 0.5, color: color);
  }
}

/// 用于分组相关设置行的单行。
class SettingsSectionRow extends StatelessWidget {
  const SettingsSectionRow({
    super.key,
    required this.title,
    required this.trailing,
    this.onTap,
  });

  final String title;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(title, style: theme.textTheme.bodyLarge),
          ),
          trailing,
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// 设置行的扩展版本，带有说明文字。 
/// 说明文字二选一：直接给 [description] 字符串，或给 [descriptionWidget]
/// 自己拼一段富文本（例如句子里嵌一个可点的「了解更多」）。
/// 后者是给 [description] 不够用的场合留的口子 —— 链接要在句中的位置随语言
/// 而变，纯字符串拼不出来。
class SettingsSectionRowWithDesc extends StatelessWidget {
  const SettingsSectionRowWithDesc({
    super.key,
    required this.title,
    this.description,
    this.descriptionWidget,
    required this.trailing,
  }) : assert(
          (description == null) != (descriptionWidget == null),
          'description 与 descriptionWidget 必须且只能给一个',
        );

  final String title;
  final String? description;
  final Widget? descriptionWidget;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xxs),
                descriptionWidget ??
                    Text(
                      description!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          trailing,
        ],
      ),
    );
  }
}
