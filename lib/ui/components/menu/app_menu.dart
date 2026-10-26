import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu_entry.dart';

import 'package:sgit_studio_flutter/ui/components/menu/app_menu_items.dart';

export 'package:sgit_studio_flutter/ui/components/menu/app_menu_entry.dart';
// 面板与菜单项的渲染在 app_menu_items.dart；对外仍从本文件取，调用方不用改 import。
export 'package:sgit_studio_flutter/ui/components/menu/app_menu_items.dart'
    show appMenuKeepLtr, appMenuStyle, buildAppMenuChildren;

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
class AppMenuAnchor extends StatefulWidget {
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

  final List<AppMenuEntry> entries;

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
  final ValueChanged<bool>? onOpenChanged;

  @override
  State<AppMenuAnchor> createState() => _AppMenuAnchorState();
}

class _AppMenuAnchorState extends State<AppMenuAnchor> {
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
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    final anchor = MenuAnchor(
      controller: _controller,
      style: appMenuStyle(
        skin,
        minWidth: widget.minWidth,
        maxWidth: widget.maxWidth,
        maxHeight: widget.maxHeight,
        alignment: switch (widget.align) {
          AppMenuAlign.end => Alignment.topRight,
          // 锚点的右下角；面板右边缘靠 [_endAligned] 的 rtl 技巧贴上去。
          AppMenuAlign.underEnd => Alignment.bottomRight,
          _ => null,
        },
      ),
      alignmentOffset: _offset,
      onOpen: () => widget.onOpenChanged?.call(true),
      onClose: () {
        _pinned = false;
        submenuPinned.value = false;
        widget.onOpenChanged?.call(false);
      },
      menuChildren: _endAligned
          ? [for (final c in _menuChildren(context, skin)) appMenuKeepLtr(c)]
          : _menuChildren(context, skin),
      builder: (context, controller, child) {
        void toggle() {
          if (!widget.enabled) return;
          controller.isOpen ? controller.close() : controller.open();
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

        final isHover = widget.trigger == AppMenuTrigger.hover;

        final trigger = Semantics(
          label: widget.semanticLabel,
          button: true,
          enabled: widget.enabled,
          child: InkWell(
            key: _triggerKey,
            onTap: switch (widget.trigger) {
              AppMenuTrigger.tap => toggle,
              AppMenuTrigger.hover => pin,
            },
            onHover: isHover ? _onTriggerHover : null,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: child,
          ),
        );
        return _endAligned ? appMenuKeepLtr(trigger) : trigger;
      },
      child: widget.child,
    );

    return _endAligned
        ? Directionality(textDirection: TextDirection.rtl, child: anchor)
        : anchor;
  }

  /// `underEnd`：面板右边缘对齐触发器右边缘。
  ///
  /// `MenuAnchor` 只能把面板的**左上角**摆到锚点上，面板宽度又是按内容撑的、
  /// 事先不可知（早先按「估算触发器宽度」算偏移，必然错位）。但它在 rtl 下会把
  /// 面板**右上角**摆到锚点上 —— 所以锚点外面套 rtl，面板内容与触发器再逐个套回 ltr。
  bool get _endAligned => widget.align == AppMenuAlign.underEnd;

  /// 触发器上的进出。进 → 开；出 → 延时关（除非钉住）。
  void _onTriggerHover(bool hovering) {
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
    _closeTimer = Timer(AppMenuMetrics.hoverCloseDelay, () {
      if (!mounted || _pinned) return;
      _controller.close();
    });
  }

  /// 光标进出的守卫层。
  Widget _hoverMenuGuard({
    required VoidCallback onEnter,
    required VoidCallback onExit,
    required Widget child,
  }) => MouseRegion(
    onEnter: (_) => onEnter(),
    onExit: (_) => onExit(),
    child: child,
  );

  /// 菜单项。hover 模式下每一项都要包一层守卫 —— 面板是 overlay，不在
  /// 触发器子树里，光标进了面板，触发器那边收到的是「移出」。
  ///
  /// 逐项包而不是整块包：`menuChildren` 是由 `MenuAnchor` 自己塞进面板的，
  /// 我们拿不到面板那一层容器。项与项之间的缝靠 [AppMenuMetrics.hoverCloseDelay]
  /// 的防抖吃掉（移出下一瞬就移入了，定时器还没到点就被取消）。
  List<Widget> _menuChildren(BuildContext context, AppSkin skin) {
    final children = buildAppMenuChildren(
      context,
      skin,
      widget.entries,
      maxWidth: widget.maxWidth,
    );
    if (widget.trigger != AppMenuTrigger.hover) {
      return children;
    }
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
        return const Offset(0, AppMenuMetrics.gap);
      case AppMenuAlign.underEnd:
        // 水平对齐由 rtl 技巧完成，见 [_endAligned]。
        return const Offset(0, AppMenuMetrics.gap);
      case AppMenuAlign.above:
        return const Offset(0, -AppMenuMetrics.gap);
      case AppMenuAlign.end:
        return const Offset(AppMenuMetrics.gap, 0);
    }
  }
}
