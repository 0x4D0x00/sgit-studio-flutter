import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'workspace_metrics.dart';

/// 右侧输出物面板内容（对应 studio 的 `OutputPanel`）。
///
/// header：`padding-block: 12px 8px; padding-inline: 14px; font-size 13; weight 600`
/// body：`overflow-y auto; padding 12/14; gap 12`
class OutputPanel extends StatelessWidget {
  const OutputPanel({super.key, required this.title, this.children = const []});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.textDark : AppColors.textLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              WorkspaceMetrics.outputHeaderPaddingInline,
              12,
              WorkspaceMetrics.outputHeaderPaddingInline,
              8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: WorkspaceMetrics.outputTitleFontSize,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ),
        Expanded(
          child: children.isEmpty
              ? _empty(isDark)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: WorkspaceMetrics.outputHeaderPaddingInline,
                  ),
                  itemCount: children.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => children[i],
                ),
        ),
      ],
    );
  }

  Widget _empty(bool isDark) => Center(
        child: Text(
          '暂无产物',
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ),
      );
}
