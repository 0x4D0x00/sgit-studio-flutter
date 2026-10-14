import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/bubble_metrics.dart';

/// 「回到最新」圆钮 —— 对话流滚离底部时浮在输入框上方。
///
/// ⚠️ **纯展示组件**，只有那颗圆钮本身。定位（浮在哪）、显隐（淡入淡出）、
/// 命中（看不见时不吃点击）全部归 [ChatTranscript] —— 那里才是"用户滚到哪了"
/// 的知情者。本组件不做可见性判断，也**不许**自己去听滚动通知：同一处状态
/// 有两个主人，必然出现"按钮画着但点不动"这类只在某个顺序下复现的毛病。
class JumpToLatestButton extends StatelessWidget {
  const JumpToLatestButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
  });

  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: skin.containerBg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        // 一层阴影把圆钮从它压住的正文里托起来 —— 底色与对话区相近，
        // 不给影子会像一块贴纸糊在字上。
        elevation: 3,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: ChatBubbleMetrics.jumpButtonSize,
            height: ChatBubbleMetrics.jumpButtonSize,
            child: Icon(
              Icons.arrow_downward_rounded,
              size: ChatBubbleMetrics.jumpButtonIconSize,
              color: scheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
