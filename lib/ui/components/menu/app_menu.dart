import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu_entry.dart';

export 'package:sgit_studio_flutter/ui/components/menu/app_menu_entry.dart';

/// 菜单触发方式。
enum AppMenuTrigger {
  /// 左键点击（下拉框、按钮菜单）。
  tap,

  /// 鼠标悬停即弹出，左键点击**钉住**（移开也不关，直到点空白或选了一项）。
  hover,
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
class AppMenuAnchor
    extends
        StatefulWidget {
  const AppMenuAnchor({
    super.key,
    required this.entries,
    required this.child,
    this.trigger = AppMenuTrigger.tap,
    this.align = AppMenuAlign.underEnd,
    this.minWidth = AppMenuMetrics.minWidth,
    this.maxWidth,
    this.maxHeight,
    this.semanticLabel,
    this.enabled = true,
    this.onOpenChanged,
  });

  final List<
    AppMenuEntry
  >
  entries;

  /// 触发器外观。菜单不管它长什么样，只负责在它旁边弹出来。
  final Widget child;

  final AppMenuTrigger trigger;
  final AppMenuAlign align;
  final double minWidth;

  /// 限宽。面板默认按内容自适应撑宽，项文案（比如模型名）过长会把菜单
  /// 撑得很宽——给了这个上限后，超宽的项改为省略号截断而不是继续撑宽。
  final double? maxWidth;

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

  /// 菜单开合变化。触发器要跟着变样（比如导航行菜单开着时保持高亮）时用。
  final ValueChanged<
    bool
  >?
  onOpenChanged;

  @override
  State<
    AppMenuAnchor
  >
  createState() => _AppMenuAnchorState();
}

class _AppMenuAnchorState
    extends
        State<
          AppMenuAnchor
        > {
  final _triggerKey = GlobalKey();
  final _controller = MenuController();

  /// 悬停打开的菜单是否被点击「钉住」。钉住后移开鼠标不关。
  bool _pinned = false;

  /// 关闭的防抖。鼠标从触发器移到菜单面板上，中间那道缝会先发一次
  /// `onExit`（面板是 overlay，不是触发器的子树）—— 立刻关就永远点不到菜单项。
  Timer? _closeTimer;

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final skin = AppSkin.of(
      context,
    );

    final anchor = MenuAnchor(
      controller: _controller,
      style: appMenuStyle(
        skin,
        minWidth: widget.minWidth,
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
        alignment:
            widget.align ==
                AppMenuAlign.end
            ? Alignment.topRight
            : null,
      ),
      alignmentOffset: _offset,
      onOpen: () => widget.onOpenChanged?.call(
        true,
      ),
      onClose: () {
        _pinned = false;
        widget.onOpenChanged?.call(
          false,
        );
      },
      menuChildren: _menuChildren(
        context,
        skin,
      ),
      builder:
          (
            context,
            controller,
            child,
          ) {
            void toggle() {
              if (!widget.enabled) return;
              controller.isOpen
                  ? controller.close()
                  : controller.open();
            }

            // hover 模式下点击 = 钉住（已钉住再点则取消钉住并关闭）。
            void pin() {
              if (!widget.enabled) return;
              if (_pinned) {
                controller.close();
                return;
              }
              _pinned = true;
              _closeTimer?.cancel();
              if (!controller.isOpen) controller.open();
            }

            final isHover =
                widget.trigger ==
                AppMenuTrigger.hover;

            return Semantics(
              label: widget.semanticLabel,
              button: true,
              enabled: widget.enabled,
              child: InkWell(
                key: _triggerKey,
                onTap: switch (widget.trigger) {
                  AppMenuTrigger.tap => toggle,
                  AppMenuTrigger.hover => pin,
                },
                onHover: isHover
                    ? _onTriggerHover
                    : null,
                borderRadius: BorderRadius.circular(
                  AppRadius.sm,
                ),
                child: child,
              ),
            );
          },
      child: widget.child,
    );

    return anchor;
  }

  /// 触发器上的进出。进 → 开；出 → 延时关（除非钉住）。
  void _onTriggerHover(
    bool hovering,
  ) {
    if (!widget.enabled) return;
    if (hovering) {
      _closeTimer?.cancel();
      if (!_controller.isOpen) _controller.open();
    } else {
      _scheduleClose();
    }
  }

  /// 延时关闭。钉住则不关。
  void _scheduleClose() {
    if (_pinned) return;
    _closeTimer?.cancel();
    _closeTimer = Timer(
      AppMenuMetrics.hoverCloseDelay,
      () {
        if (!mounted ||
            _pinned)
          return;
        _controller.close();
      },
    );
  }

  /// 光标进出的守卫层。
  Widget
  _hoverMenuGuard({
    required VoidCallback onEnter,
    required VoidCallback onExit,
    required Widget child,
  }) => MouseRegion(
    onEnter:
        (_,) => onEnter(),
    onExit:
        (_,) => onExit(),
    child: child,
  );

  /// 菜单项。hover 模式下每一项都要包一层守卫 —— 面板是 overlay，不在
  /// 触发器子树里，光标进了面板，触发器那边收到的是「移出」。
  ///
  /// 逐项包而不是整块包：`menuChildren` 是由 `MenuAnchor` 自己塞进面板的，
  /// 我们拿不到面板那一层容器。项与项之间的缝靠 [AppMenuMetrics.hoverCloseDelay]
  /// 的防抖吃掉（移出下一瞬就移入了，定时器还没到点就被取消）。
  List<
    Widget
  >
  _menuChildren(
    BuildContext context,
    AppSkin skin,
  ) {
    final children = buildAppMenuChildren(
      context,
      skin,
      widget.entries,
      maxWidth: widget.maxWidth,
    );
    if (widget.trigger !=
        AppMenuTrigger.hover)
      return children;
    return [
      for (final c in children)
        _hoverMenuGuard(
          onEnter: () => _closeTimer?.cancel(),
          onExit: _scheduleClose,
          child: c,
        ),
    ];
  }

  /// 偏移量。`underEnd` 需要测量触发器宽度，其余固定。
  Offset get _offset {
    switch (widget.align) {
      case AppMenuAlign.under:
        return const Offset(0,AppMenuMetrics.gap,);
      case AppMenuAlign.underEnd:
        // 菜单**右**边缘对齐触发器**右**边缘。
        //
        // ⚠️ 暂时用估算触发器宽度（筛选框约 90-110px），等验证对了再改成实测。
        const estimatedTriggerWidth = 100.0;
        return const Offset(
          estimatedTriggerWidth -
              AppMenuMetrics.minWidth +
              AppMenuMetrics.gap,
          AppMenuMetrics.gap,
        );
      case AppMenuAlign.above:
        return const Offset(0, -AppMenuMetrics.gap);
      case AppMenuAlign.end:
        return const Offset(
          AppMenuMetrics.gap,
          0,
        );
    }
  }
}

/// 菜单面板样式（底色 / 描边 / 圆角 / 定宽 / 限高）。
///
/// 子菜单复用同一份，这样父菜单和子菜单看起来是一套东西。
MenuStyle
appMenuStyle(
  AppSkin skin, {
  double? minWidth,
  double? maxWidth,
  double? maxHeight,
  AlignmentGeometry? alignment,
}) => MenuStyle(
  // 菜单贴在触发器的哪个角上。默认（null）是下方 —— 下拉框那种。
  // 侧向飞出（`AppMenuAlign.end`）要 `topRight`，这样不用去实测触发器宽度：
  // 左栏是可拖拽的，宽度按估算值写死必然错。
  alignment: alignment,
  backgroundColor: WidgetStatePropertyAll(
    skin.containerBg,
  ),
  surfaceTintColor: const WidgetStatePropertyAll(
    Colors.transparent,
  ),
  elevation: const WidgetStatePropertyAll(
    8,
  ),
  padding: const WidgetStatePropertyAll(
    EdgeInsets.symmetric(
      vertical: AppSpacing.xxs,
    ),
  ),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        AppMenuMetrics.radius,
      ),
      side: BorderSide(
        color: skin.border,
      ),
    ),
  ),
  minimumSize: WidgetStatePropertyAll(
    Size(minWidth ??AppMenuMetrics.minWidth,0,),
  ),
  maximumSize:
      (maxWidth ==null &&
          maxHeight ==null)
      ? null
      : WidgetStatePropertyAll(
          Size(
            maxWidth ?? double.infinity,
            maxHeight ?? double.infinity,
          ),
        ),
);

/// 把 [AppMenuEntry] 列表摊成 `MenuAnchor.menuChildren`。
///
/// ⚠️ 面板用 `IntrinsicWidth` 自己按内容撑宽，项用 `Expanded` 推 trailing
/// 到右边 —— 两边一配合，文案短的菜单窄、文案长的菜单宽，trailing 始终
/// 贴右边且不会有一大段空档。
///
/// [maxWidth] 传给 [_action] 用于限制 label 宽度，防止超长文案撑破菜单。
List<
  Widget
>
buildAppMenuChildren(
  BuildContext context,
  AppSkin skin,
  List<
    AppMenuEntry
  >
  entries, {
  double? maxWidth,
}) {
  final out =<Widget>[];
  for (final e in entries) {
    switch (e) {
      case AppMenuAction():
        out.add(
          _action(
            skin,
            e,
            maxWidth: maxWidth,
          ),
        );
      case AppMenuSubmenu():
        out.add(
          _submenu(
            context,
            skin,
            e,
          ),
        );
      case AppMenuRadioGroup():
        out.addAll(
          buildAppMenuChildren(
            context,
            skin,
            e.expand(),
            maxWidth: maxWidth,
          ),
        );
      case AppMenuSwitch():
        out.add(
          _switchItem(
            skin,
            e,
          ),
        );
      case AppMenuRichAction():
        out.add(
          _richAction(
            skin,
            e,
          ),
        );
      case AppMenuLabel():
        out.add(
          _label(
            skin,
            e,
          ),
        );
      case AppMenuDivider():
        out.add(
          Divider(
            height: 1,
            thickness: 1,
            color: skin.borderSecondary,
          ),
        );
    }
  }
  return out;
}

/// 可点的一项。
///
/// ⚠️ [maxWidth] 防文案过长撑破菜单：从外部传 `maxWidth` 进来,给 label 的容器硬限宽（扣掉左右内边距 + icon + trailing 的占位）,触发 `overflow: ellipsis`。
Widget
_action(
  AppSkin skin,
  AppMenuAction e, {
  double? maxWidth,
}) {
  final scheme = ThemeData().colorScheme;
  final fg = e.danger
      ? scheme.error
      : skin.text;

  // Label 可用的最大宽度：菜单面板总宽 - 左右内边距 - icon - trailing 占位。
  // icon 16 + gap 12 ≈ 28,trailing（shortcut/value/checkmark）预留 60。
  final labelMaxWidth =
      maxWidth ==
          null
      ? double.infinity
      : maxWidth -
            AppMenuMetrics.itemPadStart -
            AppMenuMetrics.itemPadEnd -
            (e.icon ==null? 0: 28) -
            (e.shortcut !=null ||e.trailingValue !=null ||
            e.checked
                ? 60: 0);

  return MenuItemButton(
    style: _itemStyle(
      skin,
      minHeight: AppMenuMetrics.itemHeight,
    ),
    onPressed: e.enabled? e.onTap: null,
    leadingIcon:
        e.icon ==null
        ? null
        : Icon(
            e.icon,
            size: AppMenuMetrics.iconSize,
            color: fg,
          ),
    child: Row(
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: labelMaxWidth,
            ),
            child: Text(
              e.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: fg,
              ),
            ),
          ),
        ),
        if (e.shortcut !=
            null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppMenuMetrics.trailingGap,
            ),
            child: Text(
              e.shortcut!,
              style: TextStyle(
                fontSize: 12,
                color: skin.textTertiary,
                fontFeatures: const [
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          )
        else if (e.trailingValue !=
            null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppMenuMetrics.trailingGap,
            ),
            child: Text(
              e.trailingValue!,
              style: TextStyle(
                fontSize: 13,
                color: skin.textSecondary,
              ),
            ),
          )
        else if (e.checked)
          Padding(
            padding: const EdgeInsets.only(
              left: AppMenuMetrics.trailingGap,
            ),
            child: Icon(
              Icons.check,
              size: 16,
              color: skin.accentChip,
            ),
          ),
      ],
    ),
  );
}

/// 子菜单项。
Widget
_submenu(
  BuildContext context,
  AppSkin skin,
  AppMenuSubmenu e,
) {
  return SubmenuButton(
    style: _itemStyle(
      skin,
      minHeight: AppMenuMetrics.itemHeight,
    ),
    // 子菜单**面板**的样式。不给这一份，展开出来的那一层会掉回 Material
    // 默认 surface（比 containerBg 偏灰），父子两层看着不是一套东西。
    menuStyle: appMenuStyle(
      skin,
    ),
    submenuIcon: const WidgetStatePropertyAll(
      SizedBox.shrink(),
    ),
    leadingIcon:
        e.icon ==
            null
        ? null
        : Icon(
            e.icon,
            size: AppMenuMetrics.iconSize,
            color: skin.text,
          ),
    menuChildren: buildAppMenuChildren(
      context,
      skin,
      e.entries,
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            e.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: skin.text,
            ),
          ),
        ),
        if (e.trailingValue !=
            null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppMenuMetrics.trailingGap,
            ),
            child: Text(
              e.trailingValue!,
              style: TextStyle(
                fontSize: 13,
                color: skin.textSecondary,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(
            left: 4,
          ),
          child: Icon(
            Icons.chevron_right,
            size: 16,
            color: skin.textSecondary,
          ),
        ),
      ],
    ),
  );
}

/// 带尾部开关的一项。
///
/// ⚠️ `closeOnActivate: false` 是这一项存在的理由之一 —— 见 [AppMenuSwitch]。
/// 整行可点（不只是开关本身）：菜单行里那个 Switch 只有 ~40px 宽，
/// 逼用户瞄准它而不是点整行是纯粹的刁难。
Widget _switchItem(
  AppSkin skin,
  AppMenuSwitch e,
) {
  void toggle() => e.onChanged(!e.value);

  return MenuItemButton(
    style: _itemStyle(
      skin,
      minHeight: AppMenuMetrics.itemHeight,
    ),
    closeOnActivate: false,
    onPressed: e.enabled ? toggle : null,
    leadingIcon: e.icon == null
        ? null
        : Icon(
            e.icon,
            size: AppMenuMetrics.iconSize,
            color: skin.text,
          ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            e.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              color: skin.text,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: AppMenuMetrics.trailingGap,
          ),
          // Switch 自己也能点 —— 但它与整行走同一个回调，不会双触发
          // （点在 Switch 上时 MenuItemButton 收不到 onPressed）。
          child: Switch(
            value: e.value,
            onChanged: e.enabled ? (_) => toggle() : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    ),
  );
}

/// 带描述的两行项。
Widget _richAction(
  AppSkin skin,
  AppMenuRichAction e,
) {
  return MenuItemButton(
    style: _itemStyle(
      skin,
      // 两行内容装不进 36 —— 标题 20 + 描述 17 + 上下 8 ≈ 56。
      minHeight: AppMenuMetrics.richItemHeight,
    ),
    onPressed: e.enabled ? e.onTap : null,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (e.icon != null) ...[
            Container(
              width: AppMenuMetrics.richItemIconBox,
              height: AppMenuMetrics.richItemIconBox,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: skin.containerBg,
                borderRadius: BorderRadius.circular(AppMenuMetrics.radius),
                border: Border.all(color: skin.borderSecondary),
              ),
              child: Icon(
                e.icon,
                size: AppMenuMetrics.richItemIconSize,
                color: skin.text,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  e.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    color: skin.text,
                  ),
                ),
                Text(
                  e.description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: skin.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (e.checked)
            Padding(
              padding: const EdgeInsets.only(
                left: AppMenuMetrics.trailingGap,
              ),
              child: Icon(
                Icons.check,
                size: 16,
                color: skin.accentChip,
              ),
            ),
        ],
      ),
    ),
  );
}

/// 分组标题（不可点）。
Widget
_label(
  AppSkin skin,
  AppMenuLabel e,
) {
  return MenuItemButton(
    style: _itemStyle(
      skin,
      minHeight: 28,
    ),
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
ButtonStyle
_itemStyle(
  AppSkin skin, {
  required double minHeight,
}) {
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll(
      Size(
        0,
        minHeight,
      ),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.only(
        left: AppMenuMetrics.itemPadStart,
        right: AppMenuMetrics.itemPadEnd,
      ),
    ),
    overlayColor: WidgetStateProperty.resolveWith((
      states,
    ) {
      if (states.contains(
        WidgetState.hovered,
      )) {
        return skin.text.withValues(alpha: 0.06);
      }
      return null;
    }),
  );
}
