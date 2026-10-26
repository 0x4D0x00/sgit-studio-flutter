import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/dialogs/search/search_models.dart';
import 'package:sgit_studio_flutter/ui/components/dialogs/search/search_row_menu.dart';
import 'package:sgit_studio_flutter/ui/components/dialogs/search/search_rows.dart';
import 'package:sgit_studio_flutter/ui/components/dialogs/search/search_widgets.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

// 对外 API 不变：调用方仍只 import 这一个文件。
export 'package:sgit_studio_flutter/ui/components/dialogs/search/search_models.dart';

/// 居中命令面板：搜索框 + 分类标签 + 结果列表 + 底栏快捷键。
///
/// **纯展示组件**：数据（[items]）与动作（[onSelect] / [onRowAction] /
/// [commands] / [onCompose]）都由调用方注入，弹窗本身只管过滤、选择和渲染 ——
/// 和 `confirm.dart` 一样的分工。
///
/// 选中一项会先关闭弹窗，再调用回调。
Future<void> showSearchChatsDialog(
  BuildContext context, {
  required List<SearchDialogItem> items,
  required ValueChanged<String> onSelect,
  required Future<SearchRowResult?> Function(
    String id,
    SearchDialogRowAction action,
  )
  onRowAction,
  required List<SearchDialogCommand> commands,
  required VoidCallback onCompose,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SearchChatsDialog(
      items: items,
      onSelect: onSelect,
      onRowAction: onRowAction,
      commands: commands,
      onCompose: onCompose,
    ),
  );
}

class _SearchChatsDialog extends StatefulWidget {
  const _SearchChatsDialog({
    required this.items,
    required this.onSelect,
    required this.onRowAction,
    required this.commands,
    required this.onCompose,
  });

  final List<SearchDialogItem> items;
  final ValueChanged<String> onSelect;
  final Future<SearchRowResult?> Function(
    String id,
    SearchDialogRowAction action,
  )
  onRowAction;
  final List<SearchDialogCommand> commands;
  final VoidCallback onCompose;

  @override
  State<_SearchChatsDialog> createState() => _SearchChatsDialogState();
}

class _SearchChatsDialogState extends State<_SearchChatsDialog> {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  final List<SearchAppliedFilter> _filters = [];
  String _query = '';
  SearchTab _tab = SearchTab.all;

  /// 键盘选中的行。指向 [_rows] 的下标；-1 = 没有可选项。
  ///
  /// 初值必须是 -1：`All` 标签的第一行是「最近」分组标题，不是条目。
  /// 真正的初始选中在 [didChangeDependencies] 里算（要用 l10n 才能摊出 [_rows]）。
  int _selected = -1;

  bool _selectionInitialized = false;

  /// 鼠标悬停的行。和 [_selected] 分开：悬停移开后要回到键盘选中的那一行。
  int? _hovered;

  /// 灰底是否是键盘导航点亮的。
  ///
  /// 打开弹窗时 [_selected] 就落在第一条上（直接按 `↵` 要能开第一条），但那只是
  /// 看不见的预备状态 —— 一进来就把第一行涂灰，会让人误以为它已经被选中。
  /// 所以只有按过方向键才置 true；鼠标一进来就置 false，灰底只跟着指针走。
  bool _keyboardMode = false;

  /// 每条目一个菜单控制器（按 id），供 `Alt+↵` 直接展开、也供「⋯」按钮开合。
  final Map<String, MenuController> _menuControllers = {};

  /// 当前展开着菜单的条目 id。
  ///菜单开着的期间由它把灰底锁住；菜单关闭（选项被点、点到外面的空白、按 Esc）时 `onClose` 会把它清掉，锁定随之解除。
  String? _menuOpenId;

  /// 行动作（改名 / 删除…）不关弹窗，结果就地叠在传入的 `items` 上。
  final Set<String> _removed = {};
  final Map<String, String> _labels = {};

  /// 滚动到选中行用。
  final Map<int, GlobalKey> _rowKeys = {};

  @override
  void initState() {
    super.initState();
    // 键盘处理挂在 `HardwareKeyboard` 而不是焦点链上 —— 理由见 [_onKey]。
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_selectionInitialized) return;
    _selectionInitialized = true;
    _selected = _firstSelectable(_rows(AppLocalizations.of(context)));
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---- 数据 ----

  List<SearchDialogItem> get _visibleItems {
    final q = _query.toLowerCase();
    final cats = _tab.categories;
    final list = widget.items
        .where((e) => !_removed.contains(e.id))
        .map(
          (e) => _labels.containsKey(e.id)
              ? SearchDialogItem(
                  id: e.id,
                  label: _labels[e.id]!,
                  category: e.category,
                  updatedAt: e.updatedAt,
                )
              : e,
        )
        .where((e) => cats.contains(e.category))
        .where((e) => q.isEmpty || e.label.toLowerCase().contains(q))
        .where((e) => searchMatchesFilters(_filters, e))
        .toList();
    // 有时间戳的排前面并按时间倒序；缺时间戳的沉到末尾且保持原顺序。
    list.sort((a, b) {
      final x = a.updatedAt;
      final y = b.updatedAt;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });
    // 无搜索词时只展示最近的若干条；有搜索词则返回全部匹配。
    final limit = _tab.recentLimit;
    if (q.isEmpty && limit != null && list.length > limit) {
      return list.sublist(0, limit);
    }
    return list;
  }

  bool _has(SearchFilterKind kind) => _filters.any((f) => f.kind == kind);

  /// 当前标签下摊平后的行（含分组标题）。
  List<SearchRow> _rows(AppLocalizations l10n) {
    final suggestions = _suggestionRows(l10n);
    if (suggestions != null) return suggestions;
    if (_has(SearchFilterKind.actions)) {
      final q = _query.trim().toLowerCase();
      return [
        for (final c in widget.commands)
          if (q.isEmpty || c.label.toLowerCase().contains(q))
            SearchActionRow.of(c),
      ];
    }
    final items = _visibleItems;
    if (_tab != SearchTab.all) {
      return [for (final i in items) SearchItemRow(i)];
    }
    return [
      if (items.isNotEmpty) ...[
        SearchSectionRow(l10n.searchSectionRecents),
        for (final i in items) SearchItemRow(i),
      ],
      // 带着筛选时只看筛选结果，不再夹带命令。
      if (_filters.isEmpty) ...[
        SearchSectionRow(l10n.searchSectionActions),
        for (final c in widget.commands)
          if (c.featured) SearchActionRow.of(c),
      ],
    ];
  }

  /// 输入框里的筛选语法对应的候选行；不在筛选语法里时返回 null。
  ///
  /// - `/` 开头、没有冒号：列出筛选键（可按已输入的字过滤）
  /// - `键:`（可带 `/`）：列出该键的候选值（可按冒号后的字过滤）
  List<SearchRow>? _suggestionRows(AppLocalizations l10n) {
    if (_has(SearchFilterKind.actions)) return null;
    final slash = _query.startsWith('/');
    final body = (slash ? _query.substring(1) : _query).toLowerCase();
    final colon = body.indexOf(':');

    if (colon >= 0) {
      final key = body.substring(0, colon).trim();
      final kind = SearchFilterKind.values
          .where((k) => k.hasValues)
          .where((k) => k.name == key || k.label(l10n).toLowerCase() == key)
          .firstOrNull;
      if (kind == null) return null;
      final text = body.substring(colon + 1).trim();
      final labels = kind.valueLabels(l10n);
      return [
        SearchSectionRow(kind.label(l10n)),
        for (var i = 0; i < labels.length; i++)
          if (text.isEmpty || labels[i].toLowerCase().contains(text))
            SearchSuggestionRow(
              text: labels[i],
              onPick: () => _applyFilter(kind, i),
            ),
      ];
    }

    if (!slash) return null;
    final text = body.trim();
    return [
      for (final kind in SearchFilterKind.values)
        if (!_has(kind) || kind == SearchFilterKind.type)
          if (text.isEmpty ||
              kind.name.contains(text) ||
              kind.label(l10n).toLowerCase().contains(text))
            SearchSuggestionRow(
              text: l10n.searchFilterBy,
              pill: kind.label(l10n),
              icon: kind.icon,
              onPick: () => _pickKind(kind),
            ),
    ];
  }

  /// 选中筛选键：要选值的把输入框改成 `键:` 接着列候选，其余直接生效。
  void _pickKind(SearchFilterKind kind) {
    if (!kind.hasValues) {
      _applyFilter(kind, null);
      return;
    }
    final text = '${kind.name}:';
    _ctl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _onQueryChanged(text);
  }

  /// 让筛选生效，并清空输入框。「类型」等价于切标签，不留小标签。
  void _applyFilter(SearchFilterKind kind, int? value) {
    _ctl.clear();
    setState(() {
      _query = '';
      _hovered = null;
      _keyboardMode = false;
      if (kind == SearchFilterKind.type) {
        _tab = SearchTab.values[value! + 1];
      } else {
        _filters.removeWhere((f) => f.kind == kind);
        _filters.add(SearchAppliedFilter(kind, value));
      }
    });
    _resetSelection();
  }

  void _removeFilter(SearchAppliedFilter filter) {
    setState(() {
      _filters.remove(filter);
      _hovered = null;
    });
    _resetSelection();
  }

  void _onQueryChanged(String v) {
    // 打字期间不点亮第一行：结果列表在跟着变，灰底跳来跳去很吵。
    // 筛选候选例外 —— 那是要用 ↵ 直接选的菜单，首项需要看得见。
    setState(() {
      _query = v;
      _hovered = null;
      _keyboardMode = false;
    });
    if (!mounted) return;
    setState(
      () =>
          _keyboardMode = _suggestionRows(AppLocalizations.of(context)) != null,
    );
    _resetSelection();
  }

  /// 下标列表里第一条可选项。分组标题不参与键盘选择。
  static int _firstSelectable(List<SearchRow> rows) {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i] is! SearchSectionRow) return i;
    }
    return -1;
  }

  /// 从 [from] 往 [step] 方向找下一条可选项，到头则原地不动。
  static int _nextSelectable(List<SearchRow> rows, int from, int step) {
    var i = from + step;
    while (i >= 0 && i < rows.length) {
      if (rows[i] is! SearchSectionRow) return i;
      i += step;
    }
    return from;
  }

  // ---- 交互 ----

  void _close() => Navigator.of(context).pop();

  void _changeTab(int delta) {
    final tabs = SearchTab.values;
    final next = (_tab.index + delta).clamp(0, tabs.length - 1);
    if (next == _tab.index) return;
    setState(() {
      _tab = tabs[next];
      _selected = -1;
      _hovered = null;
      _keyboardMode = true;
    });
    _resetSelection();
  }

  void _resetSelection() {
    final target = _firstSelectable(_rows(AppLocalizations.of(context)));
    if (!mounted) return;
    setState(() => _selected = target);
    _ensureVisible(target);
  }

  void _ensureVisible(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _rowKeys[index]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 120),
      );
    });
  }

  void _moveSelection(int step) {
    final rows = _rows(AppLocalizations.of(context));
    if (_selected < 0) {
      setState(() {
        _selected = _firstSelectable(rows);
        _keyboardMode = true;
      });
      return;
    }
    final next = _nextSelectable(rows, _selected, step);
    if (next == _selected) return;
    setState(() {
      _selected = next;
      _hovered = null;
      _keyboardMode = true;
    });
    _ensureVisible(next);
  }

  /// 指针进入 / 离开某一行。悬停即等同选中：灰底跟着指针走，`↵` 打开的就是
  /// 鼠标停留的那一条。
  ///
  /// 一旦动过鼠标就退出键盘模式 —— 否则指针移走之后，灰底会「弹回」上次键盘
  /// 停在的那行，看着像是自己被选中了。
  void _hoverRow(int index, bool hovering) {
    if (!hovering) {
      if (_hovered == index) setState(() => _hovered = null);
      return;
    }
    if (_hovered == index && _selected == index) return;
    setState(() {
      _hovered = index;
      _selected = index;
      _keyboardMode = false;
    });
  }

  void _activate(SearchRow row) {
    switch (row) {
      case SearchItemRow(:final item):
        _close();
        widget.onSelect(item.id);
      case SearchActionRow(:final onRun):
        _close();
        onRun();
      case SearchSuggestionRow(:final onPick):
        onPick();
      case SearchSectionRow():
        break;
    }
  }

  void _openRowMenu(int index) {
    final rows = _rows(AppLocalizations.of(context));
    if (index < 0 || index >= rows.length) return;
    final row = rows[index];
    if (row is! SearchItemRow) return;

    setState(() {
      _selected = index;
      _hovered = null;
      _keyboardMode = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctrl = _menuControllers[row.item.id];
      if (ctrl == null) return;
      ctrl.isOpen ? ctrl.close() : ctrl.open();
    });
  }

  /// 全局键盘处理。
  ///
  /// ⚠️ **不能**用 `Focus(onKeyEvent:)` 或 `Shortcuts` 包住对话框：搜索框是自动
  /// 聚焦的，而 `EditableText` 自己就吃掉了 ←→↑↓（移光标）和 Tab，事件根本
  /// 冒泡不到祖先节点。`HardwareKeyboard` 的处理器在焦点链之前跑，才拦得住。
  bool _onKey(KeyEvent event) {
    // 按住不放的重复事件也要认，长按方向键才能连续移动。
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    if (!mounted) return false;
    // 改名 / 删除等对话框叠在上面时，键盘归它们，搜索弹窗不抢。
    if (ModalRoute.of(context)?.isCurrent == false) return false;
    final key = event.logicalKey;
    final rows = _rows(AppLocalizations.of(context));

    if (key == LogicalKeyboardKey.escape) {
      _close();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _changeTab(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _changeTab(1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
      return true;
    }
    if (key == LogicalKeyboardKey.tab) {
      _close();
      widget.onCompose();
      return true;
    }
    // 输入框已空时再按退格：撤掉最后一个筛选小标签。
    if (key == LogicalKeyboardKey.backspace &&
        _query.isEmpty &&
        _filters.isNotEmpty) {
      _removeFilter(_filters.last);
      return true;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (_selected < 0 || _selected >= rows.length) return false;
      if (HardwareKeyboard.instance.isAltPressed) {
        _openRowMenu(_selected);
      } else {
        _activate(rows[_selected]);
      }
      return true;
    }
    return false;
  }

  // ---- 渲染 ----

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final rows = _rows(l10n);
    // 数据变化（切标签、改查询）后下标可能越界。
    final selected = _selected < 0 || _selected >= rows.length ? -1 : _selected;

    return Dialog(
      backgroundColor: skin.containerBg,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: skin.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SearchHeader(
              skin: skin,
              l10n: l10n,
              controller: _ctl,
              filters: _filters,
              hintText: _has(SearchFilterKind.actions)
                  ? l10n.searchActionsHint
                  : l10n.navSearch,
              onChanged: _onQueryChanged,
              onRemoveFilter: _removeFilter,
              onClose: _close,
            ),
            SearchTabsBar(
              skin: skin,
              l10n: l10n,
              selected: _tab,
              onSelect: _selectTabByMouse,
            ),
            Flexible(
              child: _tab == SearchTab.all || _tab.hasDataSource
                  ? _body(skin, l10n, rows, selected)
                  : _empty(skin, l10n),
            ),
            Divider(height: 1, thickness: 1, color: skin.borderSecondary),
            SearchFooter(skin: skin, l10n: l10n),
          ],
        ),
      ),
    );
  }

  /// 鼠标点标签：指针在标签条上，列表里不该有行是灰的，所以退出键盘模式。
  void _selectTabByMouse(SearchTab tab) {
    setState(() {
      _tab = tab;
      _selected = -1;
      _hovered = null;
      _keyboardMode = false;
    });
    _resetSelection();
  }

  /// 空态里的「搜索全部」：回到 All 并清掉筛选。
  void _searchAll() {
    setState(() {
      _tab = SearchTab.all;
      _filters.clear();
      _selected = -1;
      _hovered = null;
    });
    _resetSelection();
  }

  Widget _empty(AppSkin skin, AppLocalizations l10n) => SearchEmptyView(
    skin: skin,
    l10n: l10n,
    tab: _tab,
    onSearchAll: _searchAll,
  );

  /// 键盘滚动锚点：按行下标缓存。
  GlobalKey _anchor(int index) => _rowKeys.putIfAbsent(index, GlobalKey.new);

  Widget _body(
    AppSkin skin,
    AppLocalizations l10n,
    List<SearchRow> rows,
    int selected,
  ) {
    // 筛选候选行无命中时（如输入 `/zzz`）也走空态。
    final hasRows = rows.any((r) => r is! SearchSectionRow);
    if (!hasRows && (_tab != SearchTab.all || _filters.isNotEmpty)) {
      return _empty(skin, l10n);
    }

    return Scrollbar(
      controller: _scroll,
      thumbVisibility: false,
      child: ListView.builder(
        controller: _scroll,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        itemBuilder: (_, i) => switch (rows[i]) {
          SearchSectionRow(:final label) => SearchSectionHeader(
            skin: skin,
            label: label,
            first: i == 0,
          ),
          SearchItemRow(:final item) => _itemRow(
            skin,
            l10n,
            item,
            index: i,
            selected: i == selected,
          ),
          final SearchActionRow row => SearchActionTile(
            skin: skin,
            anchorKey: _anchor(i),
            highlighted: _isHighlighted(i, i == selected),
            onTap: () => _activate(row),
            onHover: (v) => _hoverRow(i, v),
            label: row.label,
            icon: row.icon,
          ),
          final SearchSuggestionRow row => SearchSuggestionTile(
            skin: skin,
            anchorKey: _anchor(i),
            highlighted: _isHighlighted(i, i == selected),
            onHover: (v) => _hoverRow(i, v),
            row: row,
          ),
        },
      ),
    );
  }

  /// 灰底是否点亮：键盘模式跟着选中行，否则跟着指针。
  bool _isHighlighted(int index, bool selected) =>
      _keyboardMode ? selected : _hovered == index;

  /// 行尾菜单动作的执行：只有「打开」会关弹窗；其余动作的对话框直接叠在
  /// 搜索弹窗之上，结果就地叠在传入的 `items` 上。
  Future<void> _fireRowAction(
    SearchDialogItem item,
    SearchDialogRowAction action,
  ) async {
    if (action == SearchDialogRowAction.open) {
      _close();
      widget.onRowAction(item.id, action);
      return;
    }
    final result = await widget.onRowAction(item.id, action);
    if (!mounted || result == null) return;
    setState(() {
      if (result.removed) {
        _removed.add(item.id);
        _menuControllers.remove(item.id);
        final last = _rows(AppLocalizations.of(context)).length - 1;
        if (_selected > last) _selected = last;
      } else if (result.newLabel != null) {
        _labels[item.id] = result.newLabel!;
      }
    });
  }

  Widget _itemRow(
    AppSkin skin,
    AppLocalizations l10n,
    SearchDialogItem item, {
    required int index,
    required bool selected,
  }) {
    // 键盘选中的那行只在键盘模式下才涂灰 —— 刚打开时它只是「按 ↵ 会打开哪条」 的预备状态，不是视觉上的选中。
    //
    // 菜单开着时无条件涂灰：指针这时在浮层上，行本身收不到 hover。
    final highlighted =
        _menuOpenId == item.id || _isHighlighted(index, selected);
    // 按条目 id 持有控制器，而不是按下标 —— 过滤后下标会重排，按下标存会让
    // "打开着的菜单"漂到另一条不相干的条目上。
    final menu = _menuControllers.putIfAbsent(item.id, MenuController.new);

    // ⚠️ `MenuAnchor` 必须挂在**整行**上、且无条件挂载。
    //
    // 原先它只挂在行尾的「⋯」按钮里，而那个按钮只在行高亮时才渲染 —— 指针一从
    // 行上移到菜单上，`_hovered` 变空 → 按钮连同 `MenuAnchor` 一起被拆掉 →
    // 菜单瞬间消失，根本点不到。锚点常驻后菜单归 `MenuController` 管，鼠标移开行也仍然开着。
    // 外层 rtl + 内层逐个套回 ltr：面板右边缘贴行右边缘，见 `appMenuKeepLtr`。
    return Directionality(
      textDirection: TextDirection.rtl,
      child: MenuAnchor(
        controller: menu,
        onOpen: () => setState(() {
          _menuOpenId = item.id;
          // 不碰 `_keyboardMode`：点「⋯」打开的菜单，关闭后灰底必须跟着消失；
          // 键盘（Alt+↵）打开的路径在 [_openRowMenu] 里已经自己置过了。
          _selected = index;
        }),
        // 菜单无论怎么关的（点了选项、点到外面、Esc、再点一次「⋯」）都会走到这里，
        // 灰底锁随之解除。指针若已经不在这一行上，就顺便把悬停态也清掉。
        onClose: () {
          if (!mounted || _menuOpenId != item.id) return;
          setState(() {
            _menuOpenId = null;
            if (_hovered == index) _hovered = null;
          });
        },
        style: appMenuStyle(
          skin,
          minWidth: 160,
          // 行的右下角；rtl 下面板右边缘贴上去。
          alignment: Alignment.bottomRight,
        ),
        alignmentOffset: const Offset(0, AppMenuMetrics.gap),
        menuChildren: [
          for (final c in buildAppMenuChildren(
            context,
            skin,
            buildSearchRowMenuEntries(
              l10n,
              item.category,
              (action) => _fireRowAction(item, action),
            ),
            maxWidth: 200,
          ))
            appMenuKeepLtr(c),
        ],
        builder: (_, controller, _) => appMenuKeepLtr(
          SearchRowShell(
            skin: skin,
            anchorKey: _anchor(index),
            highlighted: highlighted,
            onTap: () => _activate(SearchItemRow(item)),
            onHover: (v) => _hoverRow(index, v),
            child: Row(
              children: [
                Icon(
                  searchCategoryIcon(item.category),
                  size: 16,
                  color: skin.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: skin.text),
                  ),
                ),
                if (highlighted) ...[
                  SearchRowTrailingButton(
                    icon: Icons.more_vert,
                    skin: skin,
                    tooltip: l10n.searchFooterActions,
                    onPressed: controller.isOpen
                        ? controller.close
                        : controller.open,
                  ),
                  SearchRowTrailingButton(
                    icon: Icons.keyboard_return,
                    skin: skin,
                    onPressed: () => _activate(SearchItemRow(item)),
                  ),
                ] else if (item.updatedAt != null)
                  Text(
                    searchTimeLabel(l10n, item.updatedAt!),
                    style: TextStyle(fontSize: 12, color: skin.textTertiary),
                  ),
                const SizedBox(width: AppSpacing.xxs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
