import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/composer_metrics.dart';

/// 发送键的三种形态。
///
/// **steer 与 stop 是两件事，不许合成一个按钮**：引擎里 `turn/steer` 是把新指示
/// 并进当前 turn（不重来），`turn/interrupt` 是掐掉。合并了用户就没法"补一句话
/// 继续跑"，只能先停再重发 —— 前面那半轮白跑。
enum ComposerSendMode {
  /// 空闲：发送新一轮。
  send,

  /// 跑着且输入框有字：插话改方向。
  steer,

  /// 跑着且输入框是空的：停止。
  stop,
}

/// 圆形发送键 —— studio 的 `shape: 'round'`
/// （`MainChatInput/index.tsx:54`、`home/features/InputArea/index.tsx:203`）。
///
/// ⚠️ 纯展示组件：三态由外部算好传进来（见 [ComposerSendMode]）。
class ComposerSendButton extends StatelessWidget {
  const ComposerSendButton({
    super.key,
    required this.mode,
    required this.tooltip,
    this.onPressed,
  });

  final ComposerSendMode mode;

  /// 悬停提示，随 [mode] 变。
  final String tooltip;

  /// 传 null = 禁用（空闲且输入框为空）。
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;

    final icon = switch (mode) {
      ComposerSendMode.send => Icons.arrow_upward_rounded,
      ComposerSendMode.steer => Icons.reply_rounded,
      ComposerSendMode.stop => Icons.stop_rounded,
    };

    // 停止是**破坏性**动作，用警示色与另外两个分开 —— 跑着的时候误点一下
    // 就是整轮作废，它不该和"发送"长得一模一样。
    final bg = switch ((enabled, mode)) {
      (false, _) => skin.containerBgSecondary,
      (true, ComposerSendMode.stop) => scheme.error,
      (true, _) => scheme.primary,
    };
    final fg = enabled ? scheme.onPrimary : skin.textTertiary;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: ComposerMetrics.sendButtonSize,
            height: ComposerMetrics.sendButtonSize,
            child: Icon(
              icon,
              size: ComposerMetrics.sendButtonIconSize,
              color: mode == ComposerSendMode.stop && enabled
                  ? scheme.onError
                  : fg,
            ),
          ),
        ),
      ),
    );
  }
}
