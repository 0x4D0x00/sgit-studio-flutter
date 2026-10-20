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
enum SearchDialogRowAction { open, rename, delete }

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
    _SearchTab.sessions || _SearchTab.tasks || _SearchTab.scheduled =>
      const {},
  };

  bool get hasDataSource => categories.isNotEmpty;
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
  required void Function(String id, SearchDialogRowAction action) onRowAction,
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
  final void Function(String id, SearchDialogRowAction action) onRowAction;
  final VoidCallback onNewChat;
  final VoidCallback onCompose;

  @override
  State<_SearchChatsDialog> createState() => _SearchChatsDialogState();
}

class _SearchChatsDialogState extends State<_SearchChatsDialog> {
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  final _filtersController = MenuController();
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
        .where((e) => cats.contains(e.category))
        .where((e) => q.isEmpty || e.label.toLowerCase().contains(q))
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
    return list;
  }

  /// 当前标签下摊平后的行（含分组标题）。
  List<_Row> _rows(AppLocalizations l10n) {
    final items = _visibleItems;
    if (_tab != _SearchTab.all) {
      return [for (final i in items) _ItemRow(i)];
    }
    return [
      if (items.isNotEmpty) ...[
        _SectionRow(l10n.searchSectionRecents),
        for (final i in items) _ItemRow(i),
      ],
      _SectionRow(l10n.searchSectionActions),
      _ActionRow(label: l10n.searchNewChat, icon: Icons.add_circle_outline),
    ];
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
    // `/` 只在搜索框为空时当命令用，否则它就是用户要输入的字符。
    if (key == LogicalKeyboardKey.slash &&
        _query.isEmpty &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _filtersController.isOpen
          ? _filtersController.close()
          : _filtersController.open();
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
    final selected = _selected < 0 || _selected >= rows.length
        ? -1
        : _selected;

    return Dialog(
      backgroundColor: skin.containerBg,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: skin.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
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
        Expanded(
          child: TextField(
            controller: _ctl,
            autofocus: true,
            cursorColor: skin.textSecondary,
            onChanged: (v) {
              // 打字期间不点亮第一行：结果列表在跟着变，灰底跳来跳去很吵。
              setState(() {
                _query = v;
                _hovered = null;
                _keyboardMode = false;
              });
              _resetSelection();
            },
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
              hintText: l10n.navSearch,
              hintStyle: TextStyle(fontSize: 16, color: skin.textTertiary),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          iconSize: 20,
          color: skin.textSecondary,
          tooltip: l10n.commonClose,
          onPressed: _close,
        ),
      ],
    ),
  );

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
    final hasItems = rows.any((r) => r is _ItemRow);
    if (!hasItems && _tab != _SearchTab.all) return _empty(skin, l10n);

    return Scrollbar(
      controller: _scroll,
      thumbVisibility: false,
      child: ListView.builder(
        controller: _scroll,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: rows.length,
        itemBuilder: (_, i) => switch (rows[i]) {
          _SectionRow(:final label) => _sectionHeader(skin, label, first: i == 0),
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
    // 键盘选中的那行只在键盘模式下才涂灰 —— 刚打开时它只是「按 ↵ 会打开哪条」
    // 的预备状态，不是视觉上的选中。
    final highlighted = _hovered == index || (_keyboardMode && selected);
    // 按条目 id 持有控制器，而不是按下标 —— 过滤后下标会重排，按下标存会让
    // "打开着的菜单"漂到另一条不相干的条目上。
    final menu = _menuControllers.putIfAbsent(item.id, MenuController.new);

    // ⚠️ `MenuAnchor` 必须挂在**整行**上、且无条件挂载。
    //
    // 原先它只挂在行尾的「⋯」按钮里，而那个按钮只在行高亮时才渲染 —— 指针一从
    // 行上移到菜单上，`_hovered` 变空 → 按钮连同 `MenuAnchor` 一起被拆掉 →
    // 菜单瞬间消失，根本点不到。锚点常驻后菜单归 `MenuController` 管，鼠标
    // 移开行也仍然开着。
    return MenuAnchor(
      controller: menu,
      style: appMenuStyle(
        skin,
        minWidth: 160,
        // 贴着行的右下角弹出，跟截图一致。
        alignment: AlignmentDirectional.bottomEnd,
      ),
      menuChildren: buildAppMenuChildren(
        context,
        skin,
        _rowEntries(l10n, item),
        maxWidth: 200,
      ),
      builder: (_, controller, _) => _rowShell(
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
    );
  }

  List<AppMenuEntry> _rowEntries(AppLocalizations l10n, SearchDialogItem item) {
    void fire(SearchDialogRowAction action) {
      _close();
      widget.onRowAction(item.id, action);
    }

    return [
      AppMenuAction(
        icon: Icons.open_in_new,
        label: l10n.searchOpen,
        onTap: () => fire(SearchDialogRowAction.open),
      ),
      if (item.category == SearchDialogCategory.chat) ...[
        AppMenuAction(
          icon: Icons.edit_outlined,
          label: l10n.navChatRename,
          onTap: () => fire(SearchDialogRowAction.rename),
        ),
        AppMenuAction(
          icon: Icons.delete_outline,
          label: l10n.commonDelete,
          danger: true,
          onTap: () => fire(SearchDialogRowAction.delete),
        ),
      ],
    ];
  }

  Widget _actionRow(
    AppSkin skin,
    AppLocalizations l10n, {
    required String label,
    required IconData icon,
    required int index,
    required bool selected,
  }) {
    final highlighted = _hovered == index || (_keyboardMode && selected);
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
        onEnter: (_) => onHover(true),
        onExit: (_) => onHover(false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Material(
            color: highlighted
                ? skin.textSecondary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: InkWell(
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
          child: Text(l10n.searchSearchAll, style: const TextStyle(fontSize: 13)),
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

  /// 「Filters /」—— 键帽同时是筛选菜单的锚点，点它和按 `/` 等价。
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
        MenuAnchor(
          controller: _filtersController,
          style: appMenuStyle(skin, minWidth: 180),
          menuChildren: buildAppMenuChildren(context, skin, [
            AppMenuLabel(l10n.searchFiltersTitle),
            for (final tab in _SearchTab.values)
              AppMenuAction(
                label: _tabLabel(l10n, tab),
                checked: tab == _tab,
                onTap: () {
                  setState(() {
                    _tab = tab;
                    _selected = -1;
                    _hovered = null;
                  });
                  _resetSelection();
                },
              ),
          ]),
          builder: (_, controller, _) => InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: controller.isOpen ? controller.close : controller.open,
            child: _keycap(skin, '/'),
          ),
        ),
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
