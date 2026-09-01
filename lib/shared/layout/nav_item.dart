import 'package:flutter/material.dart';

/// 侧栏导航条目。
class NavItemData {
  const NavItemData({
    required this.icon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String route;
}

/// 「智能体」分组的一项。对齐 studio `home/_layout/Body/StudioNav.tsx` 的 8 项，
/// key 与其保持一致（studio 用 `/?studio=<key>` 就地渲染，我们用同名 key 做路由参数）。
class StudioNavItem {
  const StudioNavItem({
    required this.key,
    required this.icon,
    required this.label,
  });

  final String key;
  final IconData icon;
  final String label;

  /// studio 的 8 项，顺序照抄，不增不减。
  static const List<StudioNavItem> all = <StudioNavItem>[
    StudioNavItem(key: 'scenes', icon: Icons.grid_view_rounded, label: '场景'),
    StudioNavItem(key: 'subagent', icon: Icons.smart_toy_outlined, label: '子 Agent'),
    StudioNavItem(key: 'skill', icon: Icons.auto_awesome_outlined, label: '技能'),
    StudioNavItem(key: 'mcp', icon: Icons.extension_outlined, label: 'MCP'),
    StudioNavItem(key: 'tools', icon: Icons.widgets_outlined, label: '工具'),
    StudioNavItem(key: 'memory', icon: Icons.memory_rounded, label: '记忆'),
    StudioNavItem(key: 'knowledge', icon: Icons.menu_book_outlined, label: '知识库'),
    StudioNavItem(key: 'llm-relay', icon: Icons.hub_outlined, label: '大模型中转站'),
  ];
}
