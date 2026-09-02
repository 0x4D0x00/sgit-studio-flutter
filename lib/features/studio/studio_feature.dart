import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/features/menu/application/menu_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 「智能体」子页注册清单 —— 本 feature 的单一真源。
///
/// 与 sgit-studio `home/_layout/Body/StudioNav.tsx` 的 8 项同 key、同顺序
/// （studio 用 `/?studio=<key>` 就地渲染，我们用同名 key 做路由参数）。
///
/// ⚠️ 只做**个人版（per-cid）**，不做管理版（母版），也没有管理/个人切换器。
/// 管理动作继续在 React 版 studio 做。
@immutable
class StudioPageDef {
  const StudioPageDef({
    required this.key,
    required this.icon,
    required this.label,
  });

  final String key;
  final IconData icon;

  /// 文案走 l10n，不在这里写死字面量。
  final String Function(AppLocalizations) label;

  static const List<StudioPageDef> all = <StudioPageDef>[
    StudioPageDef(key: 'scenes', icon: Icons.grid_view_rounded, label: _scenes),
    StudioPageDef(
        key: 'subagent', icon: Icons.smart_toy_outlined, label: _subagent),
    StudioPageDef(key: 'skill', icon: Icons.auto_awesome_outlined, label: _skill),
    StudioPageDef(key: 'mcp', icon: Icons.extension_outlined, label: _mcp),
    StudioPageDef(key: 'tools', icon: Icons.widgets_outlined, label: _tools),
    StudioPageDef(key: 'memory', icon: Icons.memory_rounded, label: _memory),
    StudioPageDef(
        key: 'knowledge', icon: Icons.menu_book_outlined, label: _knowledge),
    StudioPageDef(key: 'llm-relay', icon: Icons.hub_outlined, label: _llmRelay),
  ];
}

String _scenes(AppLocalizations l) => l.studioScenes;
String _subagent(AppLocalizations l) => l.studioSubagent;
String _skill(AppLocalizations l) => l.studioSkill;
String _mcp(AppLocalizations l) => l.studioMcp;
String _tools(AppLocalizations l) => l.studioTools;
String _memory(AppLocalizations l) => l.studioMemory;
String _knowledge(AppLocalizations l) => l.studioKnowledge;
String _llmRelay(AppLocalizations l) => l.studioLlmRelay;

/// 当前可见的「智能体」子页。
///
/// ⚠️ **拒绝式（deny by default）**，与 studio `StudioNav.tsx` 的实际行为一致：
/// - 加载中 → 空（不先显示全部再抽走，避免闪现无权限菜单）；
/// - 判权失败 / 未登录（resolved=false）→ 空（**不放行**，避免后端抖动时漏出全部菜单）；
/// - 判权成功 → 只显示命中的 key。
///
/// 注意 studio 的 `services/sgcodeMenu.ts` 文件头注释写的是「失败即全开」，那是**过时的**，
/// 组件里早已改成拒绝式。以组件行为为准，别照那句注释写。
final visibleStudioPagesProvider = Provider<List<StudioPageDef>>((ref) {
  final menus = ref.watch(accessibleMenusProvider).asData?.value;
  if (menus == null || !menus.resolved) return const <StudioPageDef>[];
  return StudioPageDef.all
      .where((p) => menus.accessibleKeys.contains(p.key))
      .toList(growable: false);
});
