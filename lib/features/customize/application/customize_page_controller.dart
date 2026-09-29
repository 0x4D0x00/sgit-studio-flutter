import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Customize 页面顶部的内容类型标签。
enum CustomizeTab { skills, connectors, plugins }

/// Customize 页面当前选中的标签，放到 provider 而不是页面内部 State ——
/// 这样设置弹窗里的 Skills/Connectors/Plugins 项在用户已经停在 Customize
/// 页面时，能直接切换这个 provider 再关掉弹窗，而不是在弹窗里再渲染一份重复内容。
class CustomizeTabController extends StateNotifier<CustomizeTab> {
  CustomizeTabController() : super(CustomizeTab.skills);

  void setTab(CustomizeTab tab) => state = tab;
}

final customizeTabControllerProvider =
    StateNotifierProvider<CustomizeTabController, CustomizeTab>(
  (ref) => CustomizeTabController(),
);
