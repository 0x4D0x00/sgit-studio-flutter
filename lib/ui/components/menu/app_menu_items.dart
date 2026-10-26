import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu_entry.dart';

/// 把子树的文字方向恢复成 ltr。配合外层 rtl 的 `MenuAnchor` 使用，见
/// `_AppMenuAnchorState._endAligned`。
Widget appMenuKeepLtr(Widget child) =>
    Directionality(textDirection: TextDirection.ltr, child: child);

/// 子菜单是否被点击「钉住」。钉住后悬停同级项不再收起子菜单。
///
/// 同一时刻只会开一个菜单，所以用模块级单例；菜单关闭时在
/// `AppMenuAnchor` 的 `onClose` 里复位。
final ValueNotifier<bool> submenuPinned = ValueNotifier<bool>(false);

/// 菜单面板样式（底色 / 描边 / 圆角 / 定宽 / 限高）。
///
/// 子菜单复用同一份，这样父菜单和子菜单看起来是一套东西。
MenuStyle appMenuStyle(
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
  maximumSize: (maxWidth == null && maxHeight == null)
      ? null
      : WidgetStatePropertyAll(
          Size(maxWidth ?? double.infinity, maxHeight ?? double.infinity),
        ),
);

/// 把 [AppMenuEntry] 列表摊成 `MenuAnchor.menuChildren`。
///
/// ⚠️ 面板用 `IntrinsicWidth` 自己按内容撑宽，项用 `Expanded` 推 trailing
/// 到右边 —— 两边一配合，文案短的菜单窄、文案长的菜单宽，trailing 始终
/// 贴右边且不会有一大段空档。
///
/// [maxWidth] 传给 [_action] 用于限制 label 宽度，防止超长文案撑破菜单。
List<Widget> buildAppMenuChildren(
  BuildContext context,
  AppSkin skin,
  List<AppMenuEntry> entries, {
  double? maxWidth,
}) {
  final out = <Widget>[];
  for (final e in entries) {
    switch (e) {
      case AppMenuAction():
        out.add(
          ValueListenableBuilder<bool>(
            valueListenable: submenuPinned,
            builder: (_, pinned, _) => _action(
              skin,
              e,
              maxWidth: maxWidth,
              requestFocusOnHover: !pinned,
            ),
          ),
        );
      case AppMenuSubmenu():
        out.add(_submenu(context, skin, e));
      case AppMenuRadioGroup():
        out.addAll(
          buildAppMenuChildren(context, skin, e.expand(), maxWidth: maxWidth),
        );
      case AppMenuSwitch():
        out.add(_switchItem(skin, e));
      case AppMenuRichAction():
        out.add(_richAction(skin, e));
      case AppMenuLabel():
        out.add(_label(skin, e));
      case AppMenuDivider():
        out.add(Divider(height: 1, thickness: 1, color: skin.borderSecondary));
    }
  }
  return out;
}

/// 可点的一项。
///
/// ⚠️ [maxWidth] 防文案过长撑破菜单：从外部传 `maxWidth` 进来,给 label 的容器硬限宽（扣掉左右内边距 + icon + trailing 的占位）,触发 `overflow: ellipsis`。
Widget _action(
  AppSkin skin,
  AppMenuAction e, {
  double? maxWidth,
  bool requestFocusOnHover = true,
}) {
  final scheme = ThemeData().colorScheme;
  // 禁用项没有 onPressed，Material 不会自己变灰 —— 标题和快捷键都得由这里压色。
  // 只压标题不压快捷键，看着像「能点但没写快捷键」。
  final disabledFg = skin.textTertiary.withValues(alpha: 0.6);
  final fg = !e.enabled
      ? disabledFg
      : e.danger
      ? scheme.error
      : skin.text;

  // Label 可用的最大宽度：菜单面板总宽 - 左右内边距 - icon - trailing 占位。
  // icon 16 + gap 12 ≈ 28,trailing（shortcut/value/checkmark）预留 60。
  final labelMaxWidth = maxWidth == null
      ? double.infinity
      : maxWidth -
            AppMenuMetrics.itemPadStart -
            AppMenuMetrics.itemPadEnd -
            (e.icon == null ? 0 : 28) -
            (e.shortcut != null
                ? 60
                : e.trailingValue != null
                ? // trailingValue 是任意长度的文案（如「上下文 131072」），
                  // 固定 60 会让 label + trailing 超出 maxWidth 被右侧裁掉。
                  // 按字符数粗估（中文 ≈ 13px/字）并加上间距。
                  e.trailingValue!.length * 13.0 + AppMenuMetrics.trailingGap
                : e.checked
                ? 60
                : 0);

  return MenuItemButton(
    style: _itemStyle(skin, minHeight: AppMenuMetrics.itemHeight),
    // 默认悬停同级项会夺走焦点并收起已展开的子菜单（悬停展开 → 移开即收）。
    // 子菜单被点击钉住后传 false，同级项悬停就不再收起它。
    requestFocusOnHover: requestFocusOnHover,
    onPressed: e.enabled ? e.onTap : null,
    leadingIcon: e.icon == null
        ? null
        : Icon(e.icon, size: AppMenuMetrics.iconSize, color: fg),
    child: Row(
      children: [
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: labelMaxWidth),
            child: Text(
              e.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: fg),
            ),
          ),
        ),
        if (e.shortcut != null)
          Padding(
            padding: const EdgeInsets.only(left: AppMenuMetrics.trailingGap),
            child: Text(
              e.shortcut!,
              style: TextStyle(
                fontSize: 12,
                color: e.enabled ? skin.textTertiary : disabledFg,
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
  // 悬停展开、移开即收；点击后「钉住」（见 [submenuPinned]）。
  return Listener(
    onPointerDown: (_) => submenuPinned.value = true,
    child: SubmenuButton(
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
            child: Text(
              e.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: skin.text),
            ),
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
            child: Icon(
              Icons.chevron_right,
              size: 16,
              color: skin.textSecondary,
            ),
          ),
        ],
      ),
    ),
  );
}

/// 带尾部开关的一项。
///
/// ⚠️ `closeOnActivate: false` 是这一项存在的理由之一 —— 见 [AppMenuSwitch]。
/// 整行可点（不只是开关本身）：菜单行里那个 Switch 只有 ~40px 宽，
/// 逼用户瞄准它而不是点整行是纯粹的刁难。
Widget _switchItem(AppSkin skin, AppMenuSwitch e) {
  void toggle() => e.onChanged(!e.value);

  return MenuItemButton(
    style: _itemStyle(skin, minHeight: AppMenuMetrics.itemHeight),
    closeOnActivate: false,
    onPressed: e.enabled ? toggle : null,
    leadingIcon: e.icon == null
        ? null
        : Icon(e.icon, size: AppMenuMetrics.iconSize, color: skin.text),
    child: Row(
      children: [
        Expanded(
          child: Text(
            e.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: skin.text),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppMenuMetrics.trailingGap),
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
Widget _richAction(AppSkin skin, AppMenuRichAction e) {
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
              padding: const EdgeInsets.only(left: AppMenuMetrics.trailingGap),
              child: Icon(Icons.check, size: 16, color: skin.accentChip),
            ),
        ],
      ),
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
        return skin.text.withValues(alpha: 0.06);
      }
      return null;
    }),
  );
}
