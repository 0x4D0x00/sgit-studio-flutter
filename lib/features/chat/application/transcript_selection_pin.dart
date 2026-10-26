import 'package:flutter/widgets.dart';

/// 选区「钉住」开关（会话正文、输入框各一个）。
///
/// 正文的 `SelectableRegion` 一失焦就清选区，输入框一失焦就不画选中底色，
/// 而点顶部菜单必然让焦点离开它们 —— 「全选 → 再点编辑菜单」选区当场没了。
/// 钉住期间 [PinnableFocusNode] 对外谎称自己还有焦点，选区便留着，
/// 直到粘贴 / 焦点去了别处才放开。
class SelectionPin extends ValueNotifier<bool> {
  SelectionPin() : super(false);

  /// 被钉的控件的焦点节点；由控件挂载时登记。
  FocusNode? node;
}

final transcriptSelectionPin = SelectionPin();
final composerSelectionPin = SelectionPin();

class PinnableFocusNode extends FocusNode {
  PinnableFocusNode(this.pin, {super.debugLabel}) {
    pin.addListener(notifyListeners);
  }

  final SelectionPin pin;

  @override
  bool get hasFocus => pin.value || super.hasFocus;

  @override
  void dispose() {
    pin.removeListener(notifyListeners);
    super.dispose();
  }
}
