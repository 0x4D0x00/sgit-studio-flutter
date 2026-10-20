import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';

/// 工具调用卡。折叠态显示工具名 + 入参摘要 + 耗时，展开看输出。
///
/// ⚠️ 输出**必须限高**。内核那边已经栽过一次超大输出打满 CPU（memory
/// `chat-wont-stop-thread-read-oversized-rollout`），前端同样扛不住：
/// native 侧已按 256KB 截断，这里再限 240px 可滚区，双保险。
/// [ToolItem.outputTruncated] 为真时必须把「已截断」显式告诉用户 ——
/// 让人以为看到的是全部，比不显示更糟。
class ToolCard extends StatefulWidget {
  const ToolCard({
    super.key,
    required this.item,
    required this.runningLabel,
    required this.truncatedLabel,
    required this.elapsedLabel,
  });

  final ToolItem item;
  final String runningLabel;
  final String truncatedLabel;

  /// 已格式化好的耗时文案（`null` = 还在跑）。
  final String? elapsedLabel;

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final item = widget.item;

    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: item.revision,
        builder: (context, _, _) => Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          decoration: BoxDecoration(
            color: skin.containerBgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: skin.borderSecondary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(() => _open = !_open),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      Icon(
                        item.done
                            ? Icons.check_circle_outline_rounded
                            : Icons.pending_outlined,
                        size: 16,
                        color: item.done ? skin.accentChip : skin.textTertiary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      // ⚠️ 工具名也要能截断。原先是裸 Text，窄屏下长工具名
                      // 直接把这一行顶出去（`RenderFlex overflowed`）。
                      Flexible(
                        child: Text(item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: skin.text)),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          item.argsSummary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: skin.textTertiary),
                        ),
                      ),
                      Text(
                        widget.elapsedLabel ?? widget.runningLabel,
                        style:
                            TextStyle(fontSize: 11, color: skin.textTertiary),
                      ),
                      Icon(
                        _open
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 16,
                        color: skin.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
              if (_open) _output(skin, item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _output(AppSkin skin, ToolItem item) => Container(
        constraints: const BoxConstraints(maxHeight: 240),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: skin.borderSecondary)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 普通 [Text]：选区归外层 `SelectionArea` 管（见 `ChatTranscript`），
              // 只有这样 Ctrl+A 才不会被工具输出这一小块截住。
              Text(
                item.output ?? '',
                style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontFamily: 'monospace',
                    color: skin.textSecondary),
              ),
              if (item.outputTruncated)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    widget.truncatedLabel,
                    style: TextStyle(fontSize: 11, color: skin.textTertiary),
                  ),
                ),
            ],
          ),
        ),
      );
}
