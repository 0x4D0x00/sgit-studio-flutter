import 'package:flutter/widgets.dart';

import 'package:sgit_studio_flutter/ui/components/menu/app_menu_entry.dart';

/// 导航项（**纯展示数据**）。
///
/// ⚠️ 这里刻意不含任何业务语义 —— 没有路由、没有权限、没有 studio 的 8 个 key。
/// 业务清单在 `features/<feature>/<feature>_feature.dart` 里注册，由容器组件
/// 映射成 [NavEntry] 再喂给 `NavPanel`。布局层因此不反向依赖 features。
@immutable
class NavEntry {
  const NavEntry({
    required this.id,
    required this.icon,
    required this.label,
    this.menu = const [],
    this.trailingMenu = const [],
    this.onTrailingAdd,
    this.trailingAddTooltip,
    this.isSpecialAction = false,
  });

  /// 选中态比对用的标识。容器自己决定它是路由、是 studio key、还是别的什么。
  final String id;

  final IconData icon;
  final String label;

  /// 特殊操作行（如「查看全部」）：不显示圆点，和顶部导航对齐，
  /// 即使在 chat item 区域里也按普通行渲染。
  final bool isSpecialAction;

  /// 悬停弹出的菜单（智能体行的九个子页）。非空时这一行**不再**触发
  /// `onSelect` —— 它本身没有落地页，只是一组入口的把手。
  ///
  /// 菜单内容（几项、点了去哪）属于业务，由容器声明；布局层只管把它挂上。
  final List<AppMenuEntry> menu;

  /// 行尾「⋯」按钮的菜单（历史对话项：Pin / Rename / Delete 等）。
  ///
  /// 跟 [menu] 不是一回事：这一行**仍然**可点选中（`onSelect` 照常触发），
  /// 「⋯」只是行内独立的第二个热区，悬停才露出来。两者可以同时非空吗？
  /// 目前没有这种行，但字段各管各的，将来要叠加也不用改数据结构。
  final List<AppMenuEntry> trailingMenu;

  /// 行尾悬停显示的操作按钮（如 Projects 行的 + 按钮）。
  ///
  /// 与 [trailingMenu] 类似，但直接触发回调而非弹出菜单。
  /// 这一行**仍然**可点选中，按钮只是独立的第二个热区。
  final VoidCallback? onTrailingAdd;

  /// [onTrailingAdd] 按钮的 tooltip。
  final String? trailingAddTooltip;

  /// 这一行是不是「菜单把手」而非可导航项。
  bool get hasMenu => menu.isNotEmpty;

  /// 是否带行尾「⋯」按钮。
  bool get hasTrailingMenu => trailingMenu.isNotEmpty;

  /// 是否带行尾操作按钮（如 +）。
  bool get hasTrailingAdd => onTrailingAdd != null;

  /// 菜单里有项被勾上 = 当前正停在这一行的某个子页里。
  ///
  /// 把手行的 id 和子页的 id 天生不相等（`nav.agent` vs `scenes`），
  /// 光靠 `activeId == id` 那一比，进了子页反而整行变灰。这里从菜单的
  /// 勾选态反推，不必让容器再传一份「哪些 id 算这一行」的清单。
  bool get menuHasChecked =>
      menu.any((e) => e is AppMenuAction && e.checked);
}

/// 组标题右侧的操作按钮。语义由容器声明，布局层不从标题文案猜。
enum NavSectionAction {
  /// 不放按钮。
  none,

  /// 「+」：新增/置顶一项。
  add,

  /// 弹菜单：具体几项、点了干什么，由 [NavSection.menu] 声明。
  ///
  /// 早先这里叫 `sort`，布局层还顺带管着「分组方式/排序方式」两行的文案参数
  /// （`groupByLabel` 那一串）。菜单内容属于业务，收回容器声明。
  menu,
}

/// 导航分组。[title] 为空时不渲染组标题（整组紧贴上一组）。
@immutable
class NavSection {
  const NavSection({
    this.title,
    required this.entries,
    this.action = NavSectionAction.none,
    this.actionIcon,
    this.menu = const [],
    this.collapsible = false,
    this.onToggleCollapse,
    this.isCollapsed,
    this.emptyHint,
    this.emptyHintIcon,
    this.viewAllTooltip,
    this.actionTooltip,
    this.onViewAll,
    this.searchTooltip,
    this.onSearch,
  });

  final String? title;
  final List<NavEntry> entries;

  /// 组标题右侧的按钮。
  final NavSectionAction action;

  /// 按钮图标。`action == add` 时默认 `Icons.add`；`action == menu` 时
  /// 默认 `Icons.tune`；容器可以传这个参数盖掉默认。
  final IconData? actionIcon;

  /// `action == menu` 时的菜单内容（图2 的 Group by / Sort by 子菜单）。
  final List<AppMenuEntry> menu;

  /// 标题行「查看全部」斜向箭头按钮的 tooltip。跟 [action] 的菜单按钮是**独立的
  /// 第二个按钮**（画在它前面），点击打开该组的全屏列表（历史对话组用）。
  /// 为空则不渲染这颗按钮。
  final String? viewAllTooltip;
  final VoidCallback? onViewAll;

  /// 标题行搜索按钮（画在 [action] 菜单按钮左侧）。[onSearch] 为空则不渲染。
  final String? searchTooltip;
  final VoidCallback? onSearch;

  /// [action] 按钮的 tooltip。
  final String? actionTooltip;

  /// 标题后是否带展开/收起箭头。
  final bool collapsible;

  /// 折叠态回调 —— 用于分组场景。如果提供了这个回调，折叠/展开由容器管理。
  final VoidCallback? onToggleCollapse;

  /// 折叠状态 —— 用于分组场景。如果提供了这个值，使用它来决定显示/隐藏条目。
  final bool? isCollapsed;

  /// [entries] 为空时的占位提示文案。给了就说明「空也要出现」，
  /// 不给才是 studio 原来的「无权限就彻底不出现」。
  final String? emptyHint;

  /// [emptyHint] 前面的图标。
  final IconData? emptyHintIcon;

  /// 整组该不该被跳过：没条目、又没有空态提示、也不是折叠状态，才算真的没有。
  /// 折叠状态的分组即使 entries 为空也应该显示标题。
  bool get isEmpty => entries.isEmpty && emptyHint == null && isCollapsed != true;
}
