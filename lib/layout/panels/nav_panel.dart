import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/layout/panels/models/nav_entry.dart';
import 'package:sgit_studio_flutter/layout/panels/nav_row.dart';
import 'package:sgit_studio_flutter/layout/panels/nav_section_header.dart';
import 'package:sgit_studio_flutter/domain/models/find/find_matcher.dart';
import 'package:sgit_studio_flutter/ui/components/find/find_highlight.dart';

/// 左侧导航栏 —— 重构
///
/// 结构：
/// ```
/// 1. 品牌行
/// 2. 导航行（新对话、输出物、智能体）—— NavRow
/// 3. 置顶区域（带 Pin 提示）—— NavRow
/// 4. 历史对话列表（可折叠、可滚动）—— NavRow
/// ```
/// ⚠️ **纯展示组件**：不 import 状态管理库、不 import features、不判 `isDark`。
/// 数据与回调全部由 `features/shell/presentation/nav_panel_container.dart` 注入。
class NavPanel extends StatefulWidget {
  const NavPanel({
    super.key,
    required this.brandName,
    required this.header,
    required this.sections,
    required this.activeId,
    required this.onSelect,
    this.onFindCount,
  });

  final String brandName;
  final List<NavEntry> header;
  final List<NavSection> sections;
  final String? activeId;
  final ValueChanged<String> onSelect;

  /// 页内查找：历史对话标题里的匹配总数变了就报一次（没在查找时报 0）。
  final ValueChanged<int>? onFindCount;

  @override
  State<NavPanel> createState() => _NavPanelState();
}

class _NavPanelState extends State<NavPanel> {
  bool _chatsCollapsed = false;

  /// 当前弹着菜单的导航行 id（智能体行）。用来让那一行在菜单开着时保持高亮。
  String? _openMenuId;

  /// 鼠标当前停留的分组下标（驱动标题行的悬停显示）。
  int? _hoveredSection;

  /// 页内查找：本次 build 里下一个历史对话行的第一个匹配序号（行间累加）。
  int _findNext = 0;
  String _findQuery = '';
  int _findReported = 0;

  @override
  void dispose() {
    // 左栏收起 / 卸载后，它那份匹配数就不该再算进总数。
    final report = widget.onFindCount;
    if (_findReported != 0 && report != null) {
      scheduleMicrotask(() {
        try {
          report(0);
        } catch (_) {
          // 容器已随应用一起销毁。
        }
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final scope = FindScope.maybeOf(context);
    _findQuery = scope?.active == true ? scope!.query : '';
    _findNext = 0;
    // 行是在下面 Column 里同步建出来的（`_row` 累加 [_findNext]），帧末再报总数。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _findNext == _findReported) return;
      _findReported = _findNext;
      widget.onFindCount?.call(_findReported);
    });

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: WorkspaceMetrics.navPanelPaddingBlock,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 品牌行
          _brand(skin),

          // 2. 固定区：新对话（不随列表滚动）
          if (widget.header.isNotEmpty)
            _row(widget.header.first, isHeader: true),

          // 3-4. 可滚动区域（其余导航行、置顶、历史会话列表）
          Expanded(
            child: ScrollbarTheme(
              data: const ScrollbarThemeData(
                thickness: WidgetStatePropertyAll(4),
                radius: Radius.circular(1),
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (final e in widget.header.skip(1))
                    _row(e, isHeader: true),
                  if (widget.header.length > 1) const SizedBox(height: 8),
                  for (var i = 0; i < widget.sections.length; i++)
                    if (!widget.sections[i].isEmpty)
                      _sectionBlock(widget.sections[i], i),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 一个分组（标题 + 条目）。鼠标停在整块区域上时，标题行才露出折叠箭头等控件。
  Widget _sectionBlock(NavSection s, int index) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredSection = index),
      onExit: (_) => setState(() {
        if (_hoveredSection == index) _hoveredSection = null;
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...[
            // 组标题行（带操作按钮）
            if (s.title != null)
              NavSectionHeader(
                section: s,
                collapsed: s.isCollapsed ?? _chatsCollapsed,
                onToggleCollapse:
                    s.onToggleCollapse ??
                    (s.collapsible
                        ? () =>
                              setState(() => _chatsCollapsed = !_chatsCollapsed)
                        : null),
                hovered: _hoveredSection == index,
              ),

            if (s.entries.isNotEmpty &&
                (!_chatsCollapsed ||
                    !s.collapsible ||
                    s.onToggleCollapse != null))
              // 显示条目（未折叠 或 不可折叠 或 有自定义折叠回调）
              for (final e in s.entries) _row(e, isChatItem: s.collapsible),

            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _row(NavEntry e, {bool isHeader = false, bool isChatItem = false}) {
    // 只有历史对话标题参与查找（顶部固定导航与「查看全部」不算）。
    int? findStart;
    if (isChatItem && !e.isSpecialAction && _findQuery.isNotEmpty) {
      findStart = _findNext;
      _findNext += FindMatcher.count(e.label, _findQuery);
    }
    return NavRow(
        entry: e,
        selected: widget.activeId == e.id,
        menuOpen: _openMenuId == e.id,
        onSelect: widget.onSelect,
        onMenuOpenChanged: (open) =>
            setState(() => _openMenuId = open ? e.id : null),
        isHeader: isHeader,
        isChatItem: isChatItem,
        findStart: findStart,
      );
  }

  /// 品牌行：字标。（收起/展开左栏的入口在窗口左上角工具行。）
  Widget _brand(AppSkin skin) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
    child: Text(
      widget.brandName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: WorkspaceMetrics.brandFontSize,
        fontWeight: FontWeight.w700,
        height: 1,
        color: skin.text,
      ),
    ),
  );
}
