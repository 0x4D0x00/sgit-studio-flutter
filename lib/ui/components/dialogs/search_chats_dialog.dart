import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 搜索条目所属的类型。决定图标、落在哪个标签下，以及行尾「⁝」里有哪些动作。
enum SearchDialogCategory { artifact, chat, project }

/// 行尾「⁝」菜单里的一项动作。对话框只回传动作，**不自己执行** ——
/// 打开 / 改名 / 删除分别由调用方接（`ui/` 层不 import features）。
enum SearchDialogRowAction { open, pin, rename, editDetails, copyLink, delete }

/// 行动作执行完的结果。弹窗据此就地刷新列表（不关弹窗）。
@immutable
class SearchRowResult {
  const SearchRowResult.removed() : removed = true, newLabel = null;
  const SearchRowResult.renamed(String this.newLabel) : removed = false;

  final bool removed;
  final String? newLabel;
}

/// 搜索弹窗里的一行 —— 展示用，选中后回传 [id] 给调用方。
@immutable
class SearchDialogItem {
  const SearchDialogItem({
    required this.id,
    required this.label,
    required this.category,
    this.updatedAt,
  });

  final String id;
  final String label;
  final SearchDialogCategory category;

  /// 右侧相对时间列（今天 / 过去一周 / 过去一月 / 过去一年 / 更早）。
  /// null = 不显示 —— 内核偶有缺时间戳的旧数据，不拿 epoch 0 顶替。
  final DateTime? updatedAt;
}

/// 命令面板标签页。前四个是真实分类，后三个暂无数据源（保留空态，等内核接上）。
enum _SearchTab { all, artifacts, chats, projects, sessions, tasks, scheduled }

extension on _SearchTab {
  /// 该标签要收哪些分类。空集合 = 这个标签当前没有数据源。
  Set<SearchDialogCategory> get categories => switch (this) {
    _SearchTab.all => SearchDialogCategory.values.toSet(),
    _SearchTab.artifacts => const {SearchDialogCategory.artifact},
    _SearchTab.chats => const {SearchDialogCategory.chat},
    _SearchTab.projects => const {SearchDialogCategory.project},
    _SearchTab.sessions || _SearchTab.tasks || _SearchTab.scheduled => const {},
  };

  bool get hasDataSource => categories.isNotEmpty;

  /// 无搜索词时最多展示多少条（最近的）。null = 不限。
  int? get recentLimit => switch (this) {
    _SearchTab.all => 8,
    _SearchTab.chats => 25,
    _ => null,
  };
}

/// 居中命令面板：搜索框 + 分类标签 + 结果列表 + 底栏快捷键。
///
/// **纯展示组件**：数据（[items]）与动作（[onSelect] / [onRowAction] /
/// [onNewChat] / [onCompose]）都由调用方注入，弹窗本身只管过滤、选择和渲染 ——
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
  required VoidCallback onNewChat,
  required VoidCallback onCompose,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _SearchChatsDialog(
      items: items,
      onSelect: onSelect,
      onRowAction: onRowAction,
      onNewChat: onNewChat,
      onCompose: onCompose,
    ),
  );
}

/// 列表里的一行。用 sealed 是为了让渲染侧的 switch 漏分支时编译报错。
sealed class _Row {
  const _Row();
}

/// 分组标题（Recents / Actions）。
class _SectionRow extends _Row {
  const _SectionRow(this.label);
  final String label;
}

/// 一条可打开的条目。
class _ItemRow extends _Row {
  const _ItemRow(this.item);
  final SearchDialogItem item;
}

/// 一条命令（目前只有「新建对话」）。
class _ActionRow extends _Row {
  const _ActionRow({required this.label, required this.icon});
  final String label;
  final IconData icon;
}

/// 输入 `/` 后列出的筛选项，或选完筛选键后列出的候选值。选中即回调 [onPick]。
class _SuggestionRow extends _Row {
  const _SuggestionRow({
    required this.text,
    required this.onPick,
    this.pill,
    this.icon,
  });
  final String text;

  /// 文字后面的小药丸（「按 [所有者] 筛选」里的所有者）。
  final String? pill;
  final IconData? icon;
  final VoidCallback onPick;
}

/// 筛选键。`owner` / `date` / `type` 要再选一个值；`archived` / `actions` 直接生效。
enum _FilterKind { owner, date, type, archived, actions }

extension on _FilterKind {
  bool get hasValues =>
      this == _FilterKind.owner ||
      this == _FilterKind.date ||
      this == _FilterKind.type;
}

/// 已生效的筛选（搜索框左侧的小标签）。[value] 是候选值的下标。
@immutable
class _AppliedFilter {
  const _AppliedFilter(this.kind, [this.value]);
  final _FilterKind kind;
  final int? value;
}

class _SearchChatsDialog extends StatefulWidget {
  const _SearchChatsDialog({
    required this.items,
    required this.onSelect,
    required this.onRowAction,
    required this.onNewChat,
    required this.onCompose,
  });

  final List<SearchDialogItem> items;
  final ValueChanged<String> onSelect;
  final Future<SearchRowResult?> Function(
    String id,
    SearchDialogRowAction action,
  )
  onRowAction;
  final VoidCallback onNewChat;
  final VoidCallback onCompose;

  @override
  State<_SearchChatsDialog> createState() => _SearchChatsDialogState();
}

class _SearchChatsDialogState extends State<_SearchChatsDialog> {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  final List<_AppliedFilter> _filters = [];
  String _query = '';
  _SearchTab _tab = _SearchTab.all;

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
        .where(_matchesFilters)
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

  bool _has(_FilterKind kind) => _filters.any((f) => f.kind == kind);

  /// 已生效的筛选是否放行该条目。
  ///
  /// 目前没有「所有者」「归档」的数据源：条目全是自己的、没有归档项，
  /// 所以「我」放行全部，「与我共享」和「已归档」一条都不放行。
  bool _matchesFilters(SearchDialogItem e) {
    for (final f in _filters) {
      switch (f.kind) {
        case _FilterKind.owner:
          if (f.value != 0) return false;
        case _FilterKind.archived:
          return false;
        case _FilterKind.date:
          final at = e.updatedAt;
          if (at == null) return false;
          // 与 [_timeLabel] 同一分档：只留下行尾显示该标签的条目，互不重叠。
          final days = DateTime.now().difference(at).inDays;
          final inBucket = switch (f.value!) {
            0 => days < 1,
            1 => days >= 1 && days < 7,
            _ => days >= 7 && days < 30,
          };
          if (!inBucket) return false;
        case _FilterKind.type || _FilterKind.actions:
          break;
      }
    }
    return true;
  }

  /// 当前标签下摊平后的行（含分组标题）。
  List<_Row> _rows(AppLocalizations l10n) {
    final suggestions = _suggestionRows(l10n);
    if (suggestions != null) return suggestions;
    if (_has(_FilterKind.actions)) {
      final q = _query.trim().toLowerCase();
      return [
        if (q.isEmpty || l10n.searchNewChat.toLowerCase().contains(q))
          _ActionRow(label: l10n.searchNewChat, icon: Icons.add_circle_outline),
      ];
    }
    final items = _visibleItems;
    if (_tab != _SearchTab.all) {
      return [for (final i in items) _ItemRow(i)];
    }
    return [
      if (items.isNotEmpty) ...[
        _SectionRow(l10n.searchSectionRecents),
        for (final i in items) _ItemRow(i),
      ],
      // 带着筛选时只看筛选结果，不再夹带命令。
      if (_filters.isEmpty) ...[
        _SectionRow(l10n.searchSectionActions),
        _ActionRow(label: l10n.searchNewChat, icon: Icons.add_circle_outline),
      ],
    ];
  }

  String _kindLabel(AppLocalizations l10n, _FilterKind kind) => switch (kind) {
    _FilterKind.owner => l10n.searchFilterOwner,
    _FilterKind.date => l10n.searchFilterDate,
    _FilterKind.type => l10n.searchFilterType,
    _FilterKind.archived => l10n.searchFilterArchived,
    _FilterKind.actions => l10n.searchFilterActions,
  };

  /// 某个筛选键的候选值（文案）。
  List<String> _valueLabels(AppLocalizations l10n, _FilterKind kind) =>
      switch (kind) {
        _FilterKind.owner => [l10n.searchOwnerMe, l10n.searchOwnerShared],
        _FilterKind.date => [
          l10n.searchTimeToday,
          l10n.searchTimePastWeek,
          l10n.searchTimePastMonth,
        ],
        // 「全部」不是类型。下标对应 `_SearchTab.values[i + 1]`。
        _FilterKind.type => [
          for (final t in _SearchTab.values.skip(1)) _tabLabel(l10n, t),
        ],
        _ => const [],
      };

  /// 输入框里的筛选语法对应的候选行；不在筛选语法里时返回 null。
  ///
  /// - `/` 开头、没有冒号：列出筛选键（可按已输入的字过滤）
  /// - `键:`（可带 `/`）：列出该键的候选值（可按冒号后的字过滤）
  List<_Row>? _suggestionRows(AppLocalizations l10n) {
    if (_has(_FilterKind.actions)) return null;
    final slash = _query.startsWith('/');
    final body = (slash ? _query.substring(1) : _query).toLowerCase();
    final colon = body.indexOf(':');

    if (colon >= 0) {
      final key = body.substring(0, colon).trim();
      final kind = _FilterKind.values
          .where((k) => k.hasValues)
          .where(
            (k) => k.name == key || _kindLabel(l10n, k).toLowerCase() == key,
          )
          .firstOrNull;
      if (kind == null) return null;
      final text = body.substring(colon + 1).trim();
      final labels = _valueLabels(l10n, kind);
      return [
        _SectionRow(_kindLabel(l10n, kind)),
        for (var i = 0; i < labels.length; i++)
          if (text.isEmpty || labels[i].toLowerCase().contains(text))
            _SuggestionRow(
              text: labels[i],
              onPick: () => _applyFilter(kind, i),
            ),
      ];
    }

    if (!slash) return null;
    final text = body.trim();
    return [
      for (final kind in _FilterKind.values)
        if (!_has(kind) || kind == _FilterKind.type)
          if (text.isEmpty ||
              kind.name.contains(text) ||
              _kindLabel(l10n, kind).toLowerCase().contains(text))
            _SuggestionRow(
              text: l10n.searchFilterBy,
              pill: _kindLabel(l10n, kind),
              icon: _kindIcon(kind),
              onPick: () => _pickKind(kind),
            ),
    ];
  }

  IconData _kindIcon(_FilterKind kind) => switch (kind) {
    _FilterKind.owner => Icons.person_outline,
    _FilterKind.date => Icons.schedule,
    _FilterKind.type => Icons.category_outlined,
    _FilterKind.archived => Icons.archive_outlined,
    _FilterKind.actions => Icons.keyboard_command_key,
  };

  /// 选中筛选键：要选值的把输入框改成 `键:` 接着列候选，其余直接生效。
  void _pickKind(_FilterKind kind) {
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
  void _applyFilter(_FilterKind kind, int? value) {
    _ctl.clear();
    setState(() {
      _query = '';
      _hovered = null;
      _keyboardMode = false;
      if (kind == _FilterKind.type) {
        _tab = _SearchTab.values[value! + 1];
      } else {
        _filters.removeWhere((f) => f.kind == kind);
        _filters.add(_AppliedFilter(kind, value));
      }
    });
    _resetSelection();
  }

  void _removeFilter(_AppliedFilter filter) {
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
  static int _firstSelectable(List<_Row> rows) {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i] is! _SectionRow) return i;
    }
    return -1;
  }

  /// 从 [from] 往 [step] 方向找下一条可选项，到头则原地不动。
  static int _nextSelectable(List<_Row> rows, int from, int step) {
    var i = from + step;
    while (i >= 0 && i < rows.length) {
      if (rows[i] is! _SectionRow) return i;
      i += step;
    }
    return from;
  }

  // ---- 交互 ----

  void _close() => Navigator.of(context).pop();

  void _changeTab(int delta) {
    final tabs = _SearchTab.values;
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

  void _activate(_Row row) {
    switch (row) {
      case _ItemRow(:final item):
        _close();
        widget.onSelect(item.id);
      case _ActionRow():
        _close();
        widget.onNewChat();
      case _SuggestionRow(:final onPick):
        onPick();
      case _SectionRow():
        break;
    }
  }

  void _openRowMenu(int index) {
    final rows = _rows(AppLocalizations.of(context));
    if (index < 0 || index >= rows.length) return;
    final row = rows[index];
    if (row is! _ItemRow) return;

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
            _header(skin, l10n),
            _tabs(skin, l10n),
            Flexible(
              child: _tab == _SearchTab.all || _tab.hasDataSource
                  ? _body(skin, l10n, rows, selected)
                  : _empty(skin, l10n),
            ),
            Divider(height: 1, thickness: 1, color: skin.borderSecondary),
            _footer(skin, l10n),
          ],
        ),
      ),
    );
  }

  Widget _header(AppSkin skin, AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.xs,
      AppSpacing.xxs,
    ),
    child: Row(
      children: [
        for (final f in _filters) _filterChip(skin, l10n, f),
        Expanded(
          child: TextField(
            controller: _ctl,
            autofocus: true,
            cursorColor: skin.textSecondary,
            onChanged: _onQueryChanged,
            style: TextStyle(fontSize: 16, color: skin.text),
            decoration: InputDecoration(
              isDense: true,
              filled: false,
              // ⚠️ 三条都要显式置 none：主题的 `inputDecorationTheme` 给了
              // `enabledBorder` / `focusedBorder`，只写 `border` 时它们仍会画出
              // 一圈描边，搜索框会变成一只带框的输入框。
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xxs,
                vertical: AppSpacing.xs,
              ),
              hintText: _has(_FilterKind.actions)
                  ? l10n.searchActionsHint
                  : l10n.navSearch,
              hintStyle: TextStyle(fontSize: 16, color: skin.textTertiary),
            ),
          ),
        ),
        ExcludeFocus(
          child: IconButton(
            icon: const Icon(Icons.close),
            iconSize: 20,
            color: skin.textSecondary,
            tooltip: l10n.commonClose,
            onPressed: _close,
          ),
        ),
      ],
    ),
  );

  /// 搜索框左侧的已生效筛选，点 × 或在空输入框里退格即可撤掉。
  Widget _filterChip(AppSkin skin, AppLocalizations l10n, _AppliedFilter f) {
    final value = f.value;
    final label = value == null
        ? _kindLabel(l10n, f.kind)
        : '${_kindLabel(l10n, f.kind)}: ${_valueLabels(l10n, f.kind)[value]}';
    return Container(
      margin: const EdgeInsets.only(right: AppSpacing.xxs),
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      decoration: BoxDecoration(
        color: skin.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: skin.text)),
          InkWell(
            canRequestFocus: false,
            onTap: () => _removeFilter(f),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close, size: 12, color: skin.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// 分类标签行。视觉与 [PillTabBar] 同一套（选中 = 8% 描底色 + w600），
  /// 但这里要响应键盘切换并用滚动容器定位，所以不复用那个纯渲染组件。
  Widget _tabs(AppSkin skin, AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final tab in _SearchTab.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xxs),
              child: _tabPill(skin, l10n, tab),
            ),
        ],
      ),
    );
  }

  Widget _tabPill(AppSkin skin, AppLocalizations l10n, _SearchTab tab) {
    final selected = tab == _tab;
    return InkWell(
      // 不接管焦点：否则方向键会被焦点遍历拿去，把某一行画成焦点灰底。
      canRequestFocus: false,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () {
        setState(() {
          _tab = tab;
          _selected = -1;
          _hovered = null;
          // 鼠标点的标签：指针在标签条上，列表里不该有行是灰的。
          _keyboardMode = false;
        });
        _resetSelection();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: selected ? skin.textSecondary.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          _tabLabel(l10n, tab),
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? skin.text : skin.textSecondary,
          ),
        ),
      ),
    );
  }

  String _tabLabel(AppLocalizations l10n, _SearchTab tab) => switch (tab) {
    _SearchTab.all => l10n.searchTabAll,
    _SearchTab.artifacts => l10n.searchTabArtifacts,
    _SearchTab.chats => l10n.searchTabChats,
    _SearchTab.projects => l10n.searchTabProjects,
    _SearchTab.sessions => l10n.searchTabSessions,
    _SearchTab.tasks => l10n.searchTabTasks,
    _SearchTab.scheduled => l10n.searchTabScheduled,
  };

  Widget _body(
    AppSkin skin,
    AppLocalizations l10n,
    List<_Row> rows,
    int selected,
  ) {
    // 筛选候选行无命中时（如输入 `/zzz`）也走空态。
    final hasRows = rows.any((r) => r is! _SectionRow);
    if (!hasRows && (_tab != _SearchTab.all || _filters.isNotEmpty)) {
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
          _SectionRow(:final label) => _sectionHeader(
            skin,
            label,
            first: i == 0,
          ),
          _ItemRow(:final item) => _itemRow(
            skin,
            l10n,
            item,
            index: i,
            selected: i == selected,
          ),
          _ActionRow(:final label, :final icon) => _actionRow(
            skin,
            l10n,
            label: label,
            icon: icon,
            index: i,
            selected: i == selected,
          ),
          final _SuggestionRow row => _suggestionRow(
            skin,
            row,
            index: i,
            selected: i == selected,
          ),
        },
      ),
    );
  }

  Widget _sectionHeader(AppSkin skin, String label, {required bool first}) =>
      Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          first ? AppSpacing.xs : AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxs,
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, color: skin.textTertiary),
        ),
      );

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
        _menuOpenId == item.id ||
        (_keyboardMode ? selected : _hovered == index);
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
            _rowEntries(l10n, item),
            maxWidth: 200,
          ))
            appMenuKeepLtr(c),
        ],
        builder: (_, controller, _) => appMenuKeepLtr(
          _rowShell(
            skin,
            index: index,
            highlighted: highlighted,
            onTap: () => _activate(_ItemRow(item)),
            onHover: (v) => _hoverRow(index, v),
            child: Row(
              children: [
                Icon(
                  _categoryIcon(item.category),
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
                  _rowTrailingButton(
                    icon: Icons.more_vert,
                    skin: skin,
                    tooltip: l10n.searchFooterActions,
                    onPressed: controller.isOpen
                        ? controller.close
                        : controller.open,
                  ),
                  _rowTrailingButton(
                    icon: Icons.keyboard_return,
                    skin: skin,
                    onPressed: () => _activate(_ItemRow(item)),
                  ),
                ] else if (item.updatedAt != null)
                  Text(
                    _timeLabel(l10n, item.updatedAt!),
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

  List<AppMenuEntry> _rowEntries(AppLocalizations l10n, SearchDialogItem item) {
    // 只有「打开」会关弹窗；其余动作的对话框直接叠在搜索弹窗之上。
    Future<void> fire(SearchDialogRowAction action) async {
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

    AppMenuAction open() => AppMenuAction(
      icon: Icons.open_in_new,
      label: l10n.searchOpen,
      onTap: () => fire(SearchDialogRowAction.open),
    );
    AppMenuAction pin(String label) => AppMenuAction(
      icon: Icons.push_pin_outlined,
      label: label,
      onTap: () => fire(SearchDialogRowAction.pin),
    );
    final delete = AppMenuAction(
      icon: Icons.delete_outline,
      label: l10n.commonDelete,
      danger: true,
      onTap: () => fire(SearchDialogRowAction.delete),
    );

    // 三类的动作集合各不一样：产物只有开关与复制链接；项目/聊天多一个置顶，
    // 但项目走「编辑细节」、聊天走「重命名」。
    return switch (item.category) {
      SearchDialogCategory.artifact => [
        open(),
        AppMenuAction(
          icon: Icons.link,
          label: l10n.artifactsCopyLink,
          onTap: () => fire(SearchDialogRowAction.copyLink),
        ),
      ],
      SearchDialogCategory.project => [
        open(),
        pin(l10n.projectsPin),
        AppMenuAction(
          icon: Icons.edit_outlined,
          label: l10n.projectsEditDetails,
          onTap: () => fire(SearchDialogRowAction.editDetails),
        ),
        delete,
      ],
      SearchDialogCategory.chat => [
        open(),
        pin(l10n.navChatPin),
        AppMenuAction(
          icon: Icons.edit_outlined,
          label: l10n.navChatRename,
          onTap: () => fire(SearchDialogRowAction.rename),
        ),
        delete,
      ],
    };
  }

  Widget _actionRow(
    AppSkin skin,
    AppLocalizations l10n, {
    required String label,
    required IconData icon,
    required int index,
    required bool selected,
  }) {
    final highlighted = _keyboardMode ? selected : _hovered == index;
    return _rowShell(
      skin,
      index: index,
      highlighted: highlighted,
      onTap: () => _activate(_ActionRow(label: label, icon: icon)),
      onHover: (v) => _hoverRow(index, v),
      child: Row(
        children: [
          Icon(icon, size: 16, color: skin.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: skin.text),
            ),
          ),
          if (highlighted)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Icon(
                Icons.keyboard_return,
                size: 14,
                color: skin.textTertiary,
              ),
            ),
          const SizedBox(width: AppSpacing.xxs),
        ],
      ),
    );
  }

  /// 筛选候选行：`[图标] 筛选 [药丸]`，或只有文字的候选值。
  Widget _suggestionRow(
    AppSkin skin,
    _SuggestionRow row, {
    required int index,
    required bool selected,
  }) {
    final highlighted = _keyboardMode ? selected : _hovered == index;
    return _rowShell(
      skin,
      index: index,
      highlighted: highlighted,
      onTap: row.onPick,
      onHover: (v) => _hoverRow(index, v),
      child: Row(
        children: [
          if (row.icon != null) ...[
            Icon(row.icon, size: 16, color: skin.textSecondary),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(row.text, style: TextStyle(fontSize: 14, color: skin.text)),
          if (row.pill != null) ...[
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: skin.textSecondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                row.pill!,
                style: TextStyle(fontSize: 12, color: skin.textSecondary),
              ),
            ),
          ],
          const Spacer(),
          if (highlighted)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Icon(
                Icons.keyboard_return,
                size: 14,
                color: skin.textTertiary,
              ),
            ),
          const SizedBox(width: AppSpacing.xxs),
        ],
      ),
    );
  }

  /// 行外壳：悬停/选中底色、圆角、键盘滚动锚点。
  Widget _rowShell(
    AppSkin skin, {
    required int index,
    required bool highlighted,
    required VoidCallback onTap,
    required ValueChanged<bool> onHover,
    required Widget child,
  }) {
    final key = _rowKeys.putIfAbsent(index, GlobalKey.new);
    return KeyedSubtree(
      key: key,
      child: MouseRegion(
        // onHover 而非 onEnter：键盘滚动时行从静止的指针下滑过会误触发 onEnter，抢走键盘选中。
        onHover: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Material(
            color: highlighted
                ? skin.textSecondary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: InkWell(
              canRequestFocus: false,
              // 行底色由 [highlighted] 单独控制；InkWell 自带的 hover / focus / highlight / splash 蒙层一律关掉，避免叠出第二层灰。
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              hoverColor: Colors.transparent,
              onTap: onTap,
              child: Container(
                height: 40,
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                alignment: Alignment.centerLeft,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 行尾的小图标按钮。
  ///
  /// ⚠️ **必须把所有 overlay 关掉**：按钮浮在已经上过色的行底之上，
  /// `IconButton` 默认的 hover / highlight / splash 蒙层会再叠一层灰，
  /// 看上去就是一深一浅两块灰摞在一起。行的底色本身已经是反馈了。
  Widget _rowTrailingButton({
    required IconData icon,
    required AppSkin skin,
    String? tooltip,
    required VoidCallback onPressed,
  }) => SizedBox(
    width: 28,
    height: 40,
    child: IconButton(
      icon: Icon(icon),
      iconSize: 15,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      color: skin.textSecondary,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        overlayColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        focusColor: Colors.transparent,
      ),
      onPressed: onPressed,
    ),
  );

  IconData _categoryIcon(SearchDialogCategory c) => switch (c) {
    SearchDialogCategory.artifact => Icons.description_outlined,
    SearchDialogCategory.chat => Icons.chat_bubble_outline,
    SearchDialogCategory.project => Icons.inventory_2_outlined,
  };

  /// 相对时间。分档与截图一致：今天 / 过去一周 / 过去一月 / 过去一年 / 更早。
  String _timeLabel(AppLocalizations l10n, DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inDays < 1) return l10n.searchTimeToday;
    if (diff.inDays < 7) return l10n.searchTimePastWeek;
    if (diff.inDays < 30) return l10n.searchTimePastMonth;
    if (diff.inDays < 365) return l10n.searchTimePastYear;
    return l10n.searchTimeOlder;
  }

  Widget _empty(AppSkin skin, AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.searchNoResultsIn(_tabLabel(l10n, _tab)),
          style: TextStyle(fontSize: 14, color: skin.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _tab = _SearchTab.all;
              _filters.clear();
              _selected = -1;
              _hovered = null;
            });
            _resetSelection();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: skin.text,
            side: BorderSide(color: skin.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            minimumSize: Size.zero,
            // ⚠️ 字号写在子 Text 上，别用 `styleFrom(textStyle:)` ——
            // 那会把主题里带 fontFamily / fontFamilyFallback 的按钮文字样式整个
            // 替换掉，中文没了随包 CJK 兜底，直接渲染成方框。
          ),
          child: Text(
            l10n.searchSearchAll,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    ),
  );

  Widget _footer(AppSkin skin, AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.md,
      vertical: AppSpacing.xs,
    ),
    child: Row(
      children: [
        _hint(skin, l10n.searchFooterClose, const ['Esc']),
        _hint(skin, l10n.searchFooterChangeType, const ['←', '→']),
        _filtersHint(skin, l10n),
        _hint(skin, l10n.searchFooterActions, const ['Alt', '↵']),
        const Spacer(),
        _hint(skin, l10n.searchFooterCompose, const ['Tab']),
      ],
    ),
  );

  Widget _hint(AppSkin skin, String label, List<String> keys) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.md),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: skin.textTertiary)),
        const SizedBox(width: AppSpacing.xxs),
        for (final k in keys) _keycap(skin, k),
      ],
    ),
  );

  /// 「Filters /」—— 键帽仅作提示，不可点击；在搜索框里输入 `/` 才会列出筛选项。
  Widget _filtersHint(AppSkin skin, AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.only(right: AppSpacing.md),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.searchFooterFilters,
          style: TextStyle(fontSize: 12, color: skin.textTertiary),
        ),
        const SizedBox(width: AppSpacing.xxs),
        _keycap(skin, '/'),
      ],
    ),
  );

  Widget _keycap(AppSkin skin, String text) => Container(
    margin: const EdgeInsets.only(left: 2),
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      border: Border.all(color: skin.border),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: skin.textSecondary),
    ),
  );
}
