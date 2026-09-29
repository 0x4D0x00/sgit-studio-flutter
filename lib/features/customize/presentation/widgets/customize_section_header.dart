import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

/// 分区标题行：标题 + 可选的「See all/Show all」按钮。
class CustomizeSectionHeader extends StatelessWidget {
  const CustomizeSectionHeader(
    this.title, {
    super.key,
    this.seeAllLabel = 'See all',
    this.showSeeAll = false,
    this.onSeeAll,
  });

  final String title;
  final String seeAllLabel;
  final bool showSeeAll;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: skin.text,
          ),
        ),
        const Spacer(),
        if (showSeeAll)
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              foregroundColor: skin.text,
              padding: EdgeInsets.zero,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  seeAllLabel,
                  style: TextStyle(
                    fontSize: 14,
                    color: skin.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: skin.textSecondary,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
