import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/services/theme/theme_controller.dart';

/// 全局 Ctrl+滚轮字号缩放监听(基础能力)。
///
/// 按住 Ctrl 滚动鼠标滚轮:上滚放大、下滚缩小全局字号。包在应用最外层。
/// 也支持 Ctrl + `+/-/0`(放大/缩小/重置)键盘快捷键。
class FontScaleListener extends ConsumerWidget {
  const FontScaleListener({super.key, required this.child});
  final Widget child;

  bool get _ctrlDown {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(themeControllerProvider.notifier);

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && _ctrlDown) {
          // 上滚 dy<0 放大，下滚 dy>0 缩小。
          controller.bumpFontScale(event.scrollDelta.dy < 0 ? 1 : -1);
        }
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent || !_ctrlDown) return KeyEventResult.ignored;
          switch (event.logicalKey) {
            case LogicalKeyboardKey.equal:
            case LogicalKeyboardKey.add:
              controller.bumpFontScale(1);
              return KeyEventResult.handled;
            case LogicalKeyboardKey.minus:
            case LogicalKeyboardKey.numpadSubtract:
              controller.bumpFontScale(-1);
              return KeyEventResult.handled;
            case LogicalKeyboardKey.digit0:
              controller.resetFontScale();
              return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: child,
      ),
    );
  }
}
