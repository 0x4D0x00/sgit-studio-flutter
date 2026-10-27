import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';

/// 页内查找框：输入框 + 「当前/总数」+ 上一个 / 下一个 + 关闭。
///
/// **纯展示组件**：文本、焦点、回调都由宿主（`FindHost`）持有。
/// Enter = 下一个，Shift+Enter = 上一个，Esc = 关闭。
class FindBar extends StatelessWidget {
  const FindBar({
    super.key,
    required this.textController,
    required this.focusNode,
    required this.hint,
    required this.countText,
    required this.hasMatches,
    required this.onChanged,
    required this.onNext,
    required this.onPrevious,
    required this.onClose,
    required this.previousTooltip,
    required this.nextTooltip,
    required this.closeTooltip,
  });

  final TextEditingController textController;
  final FocusNode focusNode;
  final String hint;

  /// 「2/3」。没在查找时为空串。
  final String countText;

  /// 有没有可跳转的匹配 —— 没有就把上下箭头置灰。
  final bool hasMatches;

  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onClose;
  final String previousTooltip;
  final String nextTooltip;
  final String closeTooltip;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    Widget iconButton(
      IconData icon,
      String tip,
      VoidCallback? onTap,
    ) => IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tip,
      onPressed: onTap,
      color: skin.text,
      disabledColor: skin.textTertiary,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      padding: EdgeInsets.zero,
      splashRadius: 16,
    );

    return Material(
      color: skin.containerBg,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 360,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: skin.borderSecondary),
        ),
        child: Row(
          children: [
            Expanded(
              // Esc 关闭。挂在 TextField 外层：输入框不处理 Esc，事件会冒上来。
              child: Focus(
                onKeyEvent: (_, event) {
                  if (event is KeyDownEvent &&
                      event.logicalKey == LogicalKeyboardKey.escape) {
                    onClose();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: textController,
                  focusNode: focusNode,
                  autofocus: true,
                  onChanged: onChanged,
                  // 重写 onEditingComplete 才能在回车后**保持焦点**
                  // （默认的 done 动作会失焦，连按回车就跳不下去了）。
                  onEditingComplete: () =>
                      HardwareKeyboard.instance.isShiftPressed
                      ? onPrevious()
                      : onNext(),
                  style: TextStyle(fontSize: 14, color: skin.text),
                  cursorColor: primary,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: hint,
                    hintStyle: TextStyle(color: skin.textTertiary),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    filled: false,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: skin.borderSecondary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: primary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            if (countText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  countText,
                  style: TextStyle(fontSize: 13, color: skin.textSecondary),
                ),
              ),
            iconButton(
              Icons.arrow_upward,
              previousTooltip,
              hasMatches ? onPrevious : null,
            ),
            iconButton(
              Icons.arrow_downward,
              nextTooltip,
              hasMatches ? onNext : null,
            ),
            iconButton(Icons.close, closeTooltip, onClose),
          ],
        ),
      ),
    );
  }
}
