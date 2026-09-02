import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';

/// 文本气泡。**流式期间只有它自己重建。**
///
/// 订阅的是 [TextItem.revision] 这一条 `ValueListenable`，不是整个列表的状态 ——
/// 所以 native 推来一条 delta，重建范围就是这一个气泡，而不是 `ListView` 全体。
/// 这是长回答不掉帧的关键，改之前先读 `docs/KERNEL_FFI.md` §4。
class TextBubble extends StatelessWidget {
  const TextBubble({super.key, required this.item, required this.truncatedHint});

  final TextItem item;

  /// 「内容可能不完整」提示文案（native 背压丢过 delta 时显示）。
  final String truncatedHint;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final isUser = item.role == ChatRole.user;

    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: item.revision,
        builder: (context, _, _) => Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: isUser ? skin.navItemActive : skin.containerBgSecondary,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: skin.borderSecondary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    item.text,
                    style: TextStyle(
                        fontSize: 14, height: 1.6, color: skin.text),
                  ),
                  if (item.truncated)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: Text(
                        truncatedHint,
                        style: TextStyle(
                            fontSize: 11, color: skin.textTertiary),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
