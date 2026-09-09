import 'package:flutter/widgets.dart';

/// 导航项（**纯展示数据**）。
///
/// ⚠️ 这里刻意不含任何业务语义 —— 没有路由、没有权限、没有 studio 的 8 个 key。
/// 业务清单在 `features/<feature>/<feature>_feature.dart` 里注册，由容器组件
/// 映射成 [NavEntry] 再喂给 `NavPanel`。布局层因此不反向依赖 features。
@immutable
class NavEntry {
  const NavEntry({required this.id, required this.icon, required this.label});

  /// 选中态比对用的标识。容器自己决定它是路由、是 studio key、还是别的什么。
  final String id;

  final IconData icon;
  final String label;
}

/// 组标题右侧的操作按钮。语义由容器声明，布局层不从标题文案猜。
enum NavSectionAction {
  /// 不放按钮。
  none,

  /// 「+」：新增/置顶一项。
  add,

  /// 排序：切换列表排序方式。
  sort,
}

/// 导航分组。[title] 为空时不渲染组标题（整组紧贴上一组）。
@immutable
class NavSection {
  const NavSection({
    this.title,
    required this.entries,
    this.action = NavSectionAction.none,
    this.collapsible = false,
    this.emptyHint,
    this.emptyHintIcon,
  });

  final String? title;
  final List<NavEntry> entries;

  /// 组标题右侧的按钮。
  final NavSectionAction action;

  /// 标题后是否带展开/收起箭头。
  final bool collapsible;

  /// [entries] 为空时的占位提示文案。给了就说明「空也要出现」，
  /// 不给才是 studio 原来的「无权限就彻底不出现」。
  final String? emptyHint;

  /// [emptyHint] 前面的图标。
  final IconData? emptyHintIcon;

  /// 整组该不该被跳过：没条目、又没有空态提示，才算真的没有。
  bool get isEmpty => entries.isEmpty && emptyHint == null;
}
