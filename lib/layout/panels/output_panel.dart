import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';

/// 右侧输出物面板（对应 studio 的 `OutputPanel`）。
///
/// header：`padding-block: 12px 8px; padding-inline: 14px; font-size 13; weight 600`
/// body：`overflow-y auto; padding 12/14; gap 12`
///
/// ⚠️ 纯展示组件：文案由调用方传入（走 l10n），配色走 [AppSkin]。
class OutputPanel extends StatelessWidget {
  const OutputPanel({
    super.key,
    required this.title,
    required this.emptyText,
    this.children = const [],
  });

  final String title;
  final String emptyText;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

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
              color: skin.text,
            ),
          ),
        ),
        Expanded(
          child: children.isEmpty
              ? Center(
                  child: Text(
                    emptyText,
                    style: TextStyle(fontSize: 13, color: skin.textTertiary),
                  ),
                )
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
}
