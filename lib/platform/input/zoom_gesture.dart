import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/services/theme/theme_controller.dart';

/// 全局 Ctrl+滚轮字号缩放监听(基础能力)。
///
/// 按住 Ctrl 滚动鼠标滚轮:上滚放大、下滚缩小全局字号。包在应用最外层。
/// 也支持 Ctrl + `+/-/0`(放大/缩小/重置)键盘快捷键。
///
/// ⚠️ 键盘部分走 [HardwareKeyboard] 全局 handler，**不要**改回
/// `Focus(autofocus: true)`：那样这个包在 `MaterialApp.builder` 最外层的 Focus 会在
/// 首帧 mount(layout 之前)就抢到焦点 → 触发 view focus 事件 →
/// `FocusTraversalPolicy.findFirstFocus` → `_sortAllDescendants` 去读全树
/// `FocusNode.rect`，而此时没有任何 RenderBox 完成 layout，直接抛
/// `RenderBox was not laid out`。全局快捷键本就不该占用焦点。
class FontScaleListener extends ConsumerStatefulWidget {
  const FontScaleListener({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<FontScaleListener> createState() => _FontScaleListenerState();
}

class _FontScaleListenerState extends ConsumerState<FontScaleListener> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    super.dispose();
  }

  bool get _ctrlDown {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
  }

  /// 返回 true = 已消费，不再往焦点链分发。
  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || !_ctrlDown) return false;
    final controller = ref.read(themeControllerProvider.notifier);
    switch (event.logicalKey) {
      case LogicalKeyboardKey.equal:
      case LogicalKeyboardKey.add:
        controller.bumpFontScale(1);
        return true;
      case LogicalKeyboardKey.minus:
      case LogicalKeyboardKey.numpadSubtract:
        controller.bumpFontScale(-1);
        return true;
      case LogicalKeyboardKey.digit0:
        controller.resetFontScale();
        return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && _ctrlDown) {
          // 上滚 dy<0 放大，下滚 dy>0 缩小。
          ref
              .read(themeControllerProvider.notifier)
              .bumpFontScale(event.scrollDelta.dy < 0 ? 1 : -1);
        }
      },
      child: widget.child,
    );
  }
}
