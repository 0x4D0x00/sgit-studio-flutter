import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu_entry.dart';

export 'package:sgit_studio_flutter/ui/components/menu/app_menu_entry.dart';

/// 菜单触发方式。
enum AppMenuTrigger {
  /// 左键点击（下拉框、按钮菜单）。
  tap,

  /// 右键 / 长按（列表条目的上下文菜单）。
  secondaryTap,
}

/// 菜单相对触发器的位置。
enum AppMenuAlign {
  /// 贴在触发器下方，**左**边缘对齐。
  under,

  /// 贴在触发器下方，**右**边缘对齐。
  ///
  /// 用在菜单比触发器宽的下拉框上（筛选框那种）：左对齐的话菜单会朝右
  /// 支出去一大截，右对齐才跟触发器齐边。
  underEnd,

  /// 贴在触发器上方，左边缘对齐（左栏底部的用户菜单 —— 往下没地方了）。
  above,

  /// 贴在触发器右侧，上边缘对齐（条目「···」按钮）。
  end,
}

/// 弹出菜单 —— **全站唯一的一处菜单实现**。
///
/// 用 `MenuAnchor` 而不是 `PopupMenuButton`，两个原因：
/// 1. 子菜单要能**鼠标悬停展开**，这是 `SubmenuButton` 的原生行为，
///    `PopupMenuButton` 得自己写 overlay + hover 进出容差，那是最容易出 bug 的部分；
/// 2. `MenuAnchor` 自带锚定与屏幕边缘翻转 —— 早先左栏用户菜单是
///    `showDialog` + `Positioned(left: 24, bottom: 80)` 硬编码坐标，
///    左栏一拖宽、窗口一变矮、语言一切换（菜单变高）位置就错。
///
/// ⚠️ **纯展示组件**：不 import 状态管理库、不 import features、不判 `isDark`。
class AppMenuAnchor extends StatefulWidget {
  const AppMenuAnchor({
    super.key,
    required this.entries,
    required this.child,
    this.trigger = AppMenuTrigger.tap,
    this.align = AppMenuAlign.under,
    this.minWidth = AppMenuMetrics.minWidth,
    this.maxHeight,
    this.semanticLabel,
    this.enabled = true,
  });

  final List<AppMenuEntry> entries;

  /// 触发器外观。菜单不管它长什么样，只负责在它旁边弹出来。
  final Widget child;

  final AppMenuTrigger trigger;
  final AppMenuAlign align;
  final double minWidth;

  /// 限高（模型列表这类长菜单要它，超出后内部滚动）。
  final double? maxHeight;

  /// 读屏标签。视觉上不出现。
  final String? semanticLabel;

  /// `false` 时触发器仍然显示（只是点不开）。
  ///
  /// 模型选择器踩过这个坑：取不到模型时整个控件 `SizedBox.shrink()` 消失，
  /// 用户以为功能没做。宁可显示一个灰的 —— 所以这里是 `enabled` 而不是让
  /// 调用方在外面判空。
  final bool enabled;

  @override
  State<AppMenuAnchor> createState() => _AppMenuAnchorState();
}

class _AppMenuAnchorState extends State<AppMenuAnchor> {
  final _triggerKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return MenuAnchor(
      style: appMenuStyle(
        skin,
        minWidth: widget.minWidth,
        maxHeight: widget.maxHeight,
      ),
      alignmentOffset: _offset,
      menuChildren: buildAppMenuChildren(context, skin, widget.entries),
      builder: (context, controller, child) {
        void toggle() {
          if (!widget.enabled) return;
          controller.isOpen ? controller.close() : controller.open();
        }

        return Semantics(
          label: widget.semanticLabel,
          button: true,
          enabled: widget.enabled,
          child: InkWell(
            key: _triggerKey,
            onTap: widget.trigger == AppMenuTrigger.tap ? toggle : null,
            onSecondaryTap:
                widget.trigger == AppMenuTrigger.secondaryTap ? toggle : null,
            onLongPress:
                widget.trigger == AppMenuTrigger.secondaryTap ? toggle : null,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }

  /// 偏移量。`underEnd` 需要测量触发器宽度，其余固定。
  Offset get _offset {
    switch (widget.align) {
      case AppMenuAlign.under:
        return const Offset(0, AppMenuMetrics.gap);
      case AppMenuAlign.underEnd:
        // 菜单**右**边缘对齐触发器**右**边缘。
        //
        // ⚠️ 暂时用估算触发器宽度（筛选框约 90-110px），等验证对了再改成实测。
        const estimatedTriggerWidth = 100.0;
        return const Offset(
          estimatedTriggerWidth - AppMenuMetrics.minWidth + AppMenuMetrics.gap,
          AppMenuMetrics.gap,
        );
      case AppMenuAlign.above:
        return const Offset(0, -AppMenuMetrics.gap);
      case AppMenuAlign.end:
        return const Offset(AppMenuMetrics.gap, 0);
    }
  }
}

/// 菜单面板样式（底色 / 描边 / 圆角 / 定宽 / 限高）。
///
/// 子菜单复用同一份，这样父菜单和子菜单看起来是一套东西。
MenuStyle appMenuStyle(
  AppSkin skin, {
  double? minWidth,
  double? maxHeight,
}) =>
    MenuStyle(
      backgroundColor: WidgetStatePropertyAll(skin.containerBg),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(8),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppMenuMetrics.radius),
          side: BorderSide(color: skin.border),
        ),
      ),
      minimumSize: WidgetStatePropertyAll(
        Size(minWidth ?? AppMenuMetrics.minWidth, 0),
      ),
      maximumSize: maxHeight == null
          ? null
          : WidgetStatePropertyAll(Size(double.infinity, maxHeight)),
    );

/// 把 [AppMenuEntry] 列表摊成 `MenuAnchor.menuChildren`。
///
/// ⚠️ 面板用 `IntrinsicWidth` 自己按内容撑宽，项用 `Expanded` 推 trailing
/// 到右边 —— 两边一配合，文案短的菜单窄、文案长的菜单宽，trailing 始终
/// 贴右边且不会有一大段空档。
List<Widget> buildAppMenuChildren(
  BuildContext context,
  AppSkin skin,
  List<AppMenuEntry> entries,
) {
  final out = <Widget>[];
  for (final e in entries) {
    switch (e) {
      case AppMenuAction():
        out.add(_action(skin, e));
      case AppMenuSubmenu():
        out.add(_submenu(context, skin, e));
      case AppMenuRadioGroup():
        out.addAll(buildAppMenuChildren(context, skin, e.expand()));
      case AppMenuLabel():
        out.add(_label(skin, e));
      case AppMenuDivider():
        out.add(Divider(height: 1, thickness: 1, color: skin.borderSecondary));
    }
  }
  return out;
}

/// 可点的一项。
Widget _action(AppSkin skin, AppMenuAction e) {
  final scheme = ThemeData().colorScheme;
  final fg = e.danger ? scheme.error : skin.text;

  return MenuItemButton(
    style: _itemStyle(skin, minHeight: AppMenuMetrics.itemHeight),
    onPressed: e.enabled ? e.onTap : null,
    leadingIcon: e.icon == null
        ? null
        : Icon(e.icon, size: AppMenuMetrics.iconSize, color: fg),
    child: Row(
      children: [
        Expanded(
          child: Text(e.label, style: TextStyle(fontSize: 14, color: fg)),
        ),
        if (e.shortcut != null)
          Padding(
            padding: const EdgeInsets.only(left: AppMenuMetrics.trailingGap),
            child: Text(
              e.shortcut!,
              style: TextStyle(
                fontSize: 12,
                color: skin.textTertiary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          )
        else if (e.trailingValue != null)
          Padding(
            padding: const EdgeInsets.only(left: AppMenuMetrics.trailingGap),
            child: Text(
              e.trailingValue!,
              style: TextStyle(fontSize: 13, color: skin.textSecondary),
            ),
          )
        else if (e.checked)
          Padding(
            padding: const EdgeInsets.only(left: AppMenuMetrics.trailingGap),
            child: Icon(Icons.check, size: 16, color: skin.accentChip),
          ),
      ],
    ),
  );
}

/// 子菜单项。
Widget _submenu(BuildContext context, AppSkin skin, AppMenuSubmenu e) {
  return SubmenuButton(
    style: _itemStyle(skin, minHeight: AppMenuMetrics.itemHeight),
    // 子菜单**面板**的样式。不给这一份，展开出来的那一层会掉回 Material
    // 默认 surface（比 containerBg 偏灰），父子两层看着不是一套东西。
    menuStyle: appMenuStyle(skin),
    submenuIcon: const WidgetStatePropertyAll(SizedBox.shrink()),
    leadingIcon: e.icon == null
        ? null
        : Icon(e.icon, size: AppMenuMetrics.iconSize, color: skin.text),
    menuChildren: buildAppMenuChildren(context, skin, e.entries),
    child: Row(
      children: [
        Expanded(
          child: Text(e.label, style: TextStyle(fontSize: 14, color: skin.text)),
        ),
        if (e.trailingValue != null)
          Padding(
            padding: const EdgeInsets.only(left: AppMenuMetrics.trailingGap),
            child: Text(
              e.trailingValue!,
              style: TextStyle(fontSize: 13, color: skin.textSecondary),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(Icons.chevron_right, size: 16, color: skin.textSecondary),
        ),
      ],
    ),
  );
}

/// 分组标题（不可点）。
Widget _label(AppSkin skin, AppMenuLabel e) {
  return MenuItemButton(
    style: _itemStyle(skin, minHeight: 28),
    onPressed: null,
    child: Text(
      e.text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: skin.textTertiary,
      ),
    ),
  );
}

/// 项的样式（高度 / 内边距 / 悬停态）。
ButtonStyle _itemStyle(AppSkin skin, {required double minHeight}) {
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, minHeight)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.only(
        left: AppMenuMetrics.itemPadStart,
        right: AppMenuMetrics.itemPadEnd,
      ),
    ),
    overlayColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered)) {
        return skin.navItemActive;
      }
      return null;
    }),
  );
}
