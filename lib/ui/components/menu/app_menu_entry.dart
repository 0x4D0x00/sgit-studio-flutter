import 'package:flutter/material.dart';

/// 弹出菜单的一项（**纯数据**，不含业务语义、不引状态库）。
///
/// 为什么用 sealed：菜单形态会长（将来要加输入框项、头像项），
/// `sealed` 让渲染侧的 switch 在漏分支时**编译报错**而不是静默少画一项。
sealed class AppMenuEntry {
  const AppMenuEntry();
}

/// 可点的一项 —— 菜单的主力形态。
///
/// 右侧那一格（trailing）三种填法互斥，按优先级取第一个非空：
/// [shortcut] > [trailingValue] > [checked]。
/// 同时给两个不会崩，但设计上没有这种项，所以按优先级吃掉后面的。
class AppMenuAction extends AppMenuEntry {
  const AppMenuAction({
    required this.label,
    this.icon,
    this.onTap,
    this.shortcut,
    this.trailingValue,
    this.checked = false,
    this.danger = false,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;

  /// 点击回调。传 null 等于该项不可点（与 [enabled] `false` 同效）。
  final VoidCallback? onTap;

  /// 右侧快捷键提示，如 `Ctrl U` / `P` / `D`。**只是提示**，
  /// 真正的键盘绑定不在菜单里做 —— 菜单关掉后快捷键也该生效，
  /// 那是页面级 `Shortcuts` 的事。
  final String? shortcut;

  /// 右侧当前值，如 Group by 的 `None`、Sort by 的 `Last activity`。
  final String? trailingValue;

  /// 右侧对勾（单选/多选态）。
  final bool checked;

  /// 危险项（删除类），文字与图标走警示色。
  final bool danger;

  final bool enabled;
}

/// 子菜单 —— 悬停或点击父项后展开。
///
/// 「鼠标悬停自动展开」是 Material `SubmenuButton` 的原生行为，
/// 所以这一项**必须**由 `SubmenuButton` 渲染，不能退化成 `showMenu`。
class AppMenuSubmenu extends AppMenuEntry {
  const AppMenuSubmenu({
    required this.label,
    required this.entries,
    this.icon,
    this.trailingValue,
  });

  final String label;
  final IconData? icon;

  /// 父项右侧显示的当前值（子菜单选了什么，在父项上就能看到）。
  final String? trailingValue;

  final List<AppMenuEntry> entries;
}

/// 单选组 —— 自己把候选值摊成带对勾的 [AppMenuAction]。
///
/// 省掉调用方那句「for (final v in values) ... if (v == selected) 打勾」的样板，
/// 也保证全站的单选菜单勾在同一侧、同一个图标。
class AppMenuRadioGroup<T> extends AppMenuEntry {
  const AppMenuRadioGroup({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final List<T> values;
  final T? selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelect;

  /// 展开成普通项。渲染侧不必知道单选这回事。
  List<AppMenuEntry> expand() => [
    for (final v in values)
      AppMenuAction(
        label: labelOf(v),
        checked: v == selected,
        onTap: () => onSelect(v),
      ),
  ];
}

/// 带尾部开关的一项（输入框 `+` 菜单的「记忆」「联网搜索」那种）。
///
/// 与 [AppMenuAction] 的区别不只是长相：**点了菜单不关**。开关类的项用户常要
/// 连着拨好几个，每拨一次就把菜单收掉等于逼他重新点开三次。
class AppMenuSwitch extends AppMenuEntry {
  const AppMenuSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
}

/// 带描述的两行项（审批策略四档、沙箱三档那种：标题一行、说明一行）。
///
/// 为什么不让 [AppMenuAction] 多一个 `description` 字段：那一项的高度、
/// 对勾位置、左图标方块全都不一样，塞进同一个渲染函数会变成一堆
/// `if (description != null)` 分叉 —— 正是本文件用 sealed 想避免的。
class AppMenuRichAction extends AppMenuEntry {
  const AppMenuRichAction({
    required this.title,
    required this.description,
    this.icon,
    this.onTap,
    this.checked = false,
    this.enabled = true,
  });

  final String title;
  final String description;

  /// 左侧图标。给了就画成一个带描边的方块（对齐 studio 的 `optionIcon`）。
  final IconData? icon;

  final VoidCallback? onTap;
  final bool checked;
  final bool enabled;
}

/// 不可点的分组标题（模型选择器里的厂商名、用户菜单顶部的账号名）。
class AppMenuLabel extends AppMenuEntry {
  const AppMenuLabel(this.text);

  final String text;
}

/// 分隔线。
class AppMenuDivider extends AppMenuEntry {
  const AppMenuDivider();
}
