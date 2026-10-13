import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/design/tokens/app_typography.dart';
import 'package:sgit_studio_flutter/design/tokens/bubble_metrics.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/chat/bubble_actions_row.dart';

/// 围栏代码块：圆角卡 + 等宽字体 + 横向滚动 + 复制按钮。
///
/// ⚠️ 这里**必须用 `Container`**，因为代码块本身就是视觉上的一个"容器"——
/// 圆角+底色+描边。如果为了通过 `chat_bubble_style_test.dart` 的"零 Container"
/// 断言而强行去掉，代码块就只能是一段等宽纯文本，没有背景与边框，看不出它是
/// 一整块代码。那个测试断言的真正语义是「**纯段落不该有 Container**」，
/// 代码块出现时当然可以有。
class CodeBlockCard extends StatefulWidget {
  const CodeBlockCard({
    super.key,
    required this.code,
    required this.language,
  });

  final String code;
  final String language;

  @override
  State<CodeBlockCard> createState() => _CodeBlockCardState();
}

class _CodeBlockCardState extends State<CodeBlockCard> {
  /// 鼠标是否停在复制按钮上。只影响那一枚按钮的长相，不涉及卡片本身。
  bool _copyHovering = false;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final code = widget.code;
    final language = widget.language;

    return Container(
      padding: const EdgeInsets.all(ChatBubbleMetrics.codeBlockPadding),
      decoration: BoxDecoration(
        color: skin.containerBgSecondary,
        border: Border.all(color: skin.borderSecondary),
        borderRadius: BorderRadius.circular(ChatBubbleMetrics.codeBlockRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题行：语言标签 + 复制按钮
          Row(
            children: [
              if (language.isNotEmpty)
                Text(
                  language,
                  style: TextStyle(
                    fontSize: 12,
                    color: skin.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              const Spacer(),
              Tooltip(
                message: l10n.chatCopy,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _copyHovering = true),
                  onExit: (_) => setState(() => _copyHovering = false),
                  child: AnimatedContainer(
                    duration: ChatBubbleMetrics.hoverFade,
                    curve: Curves.easeOut,
                    decoration: BoxDecoration(
                      color: _copyHovering
                          ? skin.text.withValues(
                              alpha: ChatBubbleMetrics.hoverAlpha)
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                    ),
                    child: InkWell(
                      onTap: () => copyToClipboard(context, code, l10n.chatCopied),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      hoverColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxs),
                        child: Icon(
                          Icons.content_copy,
                          size: 14,
                          color: _copyHovering ? skin.text : skin.textTertiary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // 代码正文：等宽 + 横向滚动
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              code,
              style: TextStyle(
                fontFamily: AppTypography.monospace,
                fontSize: 13,
                height: 1.5,
                color: skin.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
