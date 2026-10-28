import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/brand/brand_config.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu_entry.dart';

/// 键盘快捷键弹窗：只读列出当前已绑定的快捷键，按分组展示。
///
/// 清单与 `AppShellContainer` 的 `CallbackShortcuts`、菜单提示保持一致；
/// 那边新增 / 改键时，这里要同步。
Future<void> showKeyboardShortcutsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _KeyboardShortcutsDialog(),
  );
}

class _ShortcutItem {
  const _ShortcutItem(this.label, this.keys);

  final String label;

  /// 一项可有多个等价组合（如放大 Ctrl+= / Ctrl+Shift+=）。
  final List<String> keys;
}

class _ShortcutGroup {
  const _ShortcutGroup(this.title, this.items);

  final String title;
  final List<_ShortcutItem> items;
}

List<_ShortcutGroup> _groups(AppLocalizations l10n) => [
  _ShortcutGroup(l10n.shortcutsGroupChat, [
    _ShortcutItem(l10n.shortcutsSendMessage, const ['Enter']),
    _ShortcutItem(l10n.navSearch, const ['Ctrl+K']),
    _ShortcutItem(l10n.navChatPin, const [kMenuPinShortcutLabel]),
    _ShortcutItem(l10n.navChatRename, const [kMenuRenameShortcutLabel]),
  ]),
  _ShortcutGroup(l10n.menuFile, [
    _ShortcutItem(l10n.navNewChat, const ['Ctrl+N']),
    _ShortcutItem(l10n.menuOpenFolder, const ['Ctrl+O']),
    _ShortcutItem(l10n.navSettings, const ['Ctrl+,']),
    _ShortcutItem(l10n.menuClose, const ['Ctrl+W']),
    _ShortcutItem(l10n.menuQuitBrand(BrandConfig.instance.name), const [
      'Ctrl+Q',
    ]),
  ]),
  _ShortcutGroup(l10n.menuEdit, [
    _ShortcutItem(l10n.editUndo, const ['Ctrl+Z']),
    _ShortcutItem(l10n.editRedo, const ['Ctrl+Y', 'Ctrl+Shift+Z']),
    _ShortcutItem(l10n.editCut, const ['Ctrl+X']),
    _ShortcutItem(l10n.editCopy, const ['Ctrl+C']),
    _ShortcutItem(l10n.editPaste, const ['Ctrl+V']),
    _ShortcutItem(l10n.editSelectAll, const ['Ctrl+A']),
  ]),
  _ShortcutGroup(l10n.menuView, [
    _ShortcutItem(l10n.menuToggleSidebar, const ['Ctrl+Shift+S']),
    _ShortcutItem(l10n.menuOpenTerminal, const ['Ctrl+`']),
    _ShortcutItem(l10n.menuSwitchChatTabs, const ['Ctrl+Alt+B']),
    _ShortcutItem(l10n.menuFind, const ['Ctrl+F']),
    _ShortcutItem(l10n.toolbarBack, const ['Ctrl+[']),
    _ShortcutItem(l10n.menuZoomIn, const ['Ctrl+=', 'Ctrl+Shift+=']),
    _ShortcutItem(l10n.menuZoomOut, const ['Ctrl+-']),
    _ShortcutItem(l10n.menuActualSize, const ['Ctrl+0']),
    _ShortcutItem(l10n.menuFullScreen, const ['F11']),
    _ShortcutItem(l10n.navKeyboardShortcuts, const ['Ctrl+/']),
  ]),
];

class _KeyboardShortcutsDialog extends StatefulWidget {
  const _KeyboardShortcutsDialog();

  @override
  State<_KeyboardShortcutsDialog> createState() =>
      _KeyboardShortcutsDialogState();
}

class _KeyboardShortcutsDialogState extends State<_KeyboardShortcutsDialog> {
  String _query = '';

  /// 按名称或按键匹配（忽略大小写与空格）；整组无命中就不显示该组。
  List<_ShortcutGroup> _filter(List<_ShortcutGroup> groups) {
    final q = _query.trim().toLowerCase().replaceAll(' ', '');
    if (q.isEmpty) return groups;
    bool hit(_ShortcutItem i) =>
        i.label.toLowerCase().contains(q) ||
        i.keys.any((k) => k.toLowerCase().contains(q));
    return [
      for (final g in groups)
        if (g.items.any(hit))
          _ShortcutGroup(g.title, g.items.where(hit).toList()),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final groups = _filter(_groups(l10n));

    return Dialog(
      backgroundColor: skin.containerBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: skin.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.navKeyboardShortcuts,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: skin.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.commonClose,
                    icon: Icon(Icons.close, size: 18, color: skin.text),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(color: skin.text, fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: l10n.shortcutsSearchHint,
                  hintStyle: TextStyle(color: skin.textSecondary),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: skin.textSecondary,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(color: skin.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                children: [
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          l10n.shortcutsEmpty,
                          style: TextStyle(color: skin.textSecondary),
                        ),
                      ),
                    ),
                  for (final g in groups) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 4),
                      child: Text(
                        g.title,
                        style: TextStyle(
                          color: skin.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    for (final item in g.items) _row(skin, item),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(AppSkin skin, _ShortcutItem item) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: skin.borderSecondary)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(color: skin.text, fontSize: 14),
            ),
          ),
          for (final k in item.keys)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                k,
                style: TextStyle(color: skin.textSecondary, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}
