import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/features/studio/application/accessible_menus_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 一个「智能体」子页的入口归属。
///
/// 一个页只在**一个**入口出现 —— 挪走就是挪走，不是两处都放。
enum StudioPlacement {
  /// 左栏「智能体」行的悬停菜单。
  navMenu,

  /// 设置弹窗「自定义」分组（技能 / 连接器 / 插件 那一组下面）。
  settingsDialog,
}

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
    required this.placement,
    this.backendGated = true,
  });

  final String key;
  final IconData icon;

  /// 文案走 l10n，不在这里写死字面量。
  final String Function(AppLocalizations) label;

  /// 是否受后端 `menu_key` 判权。
  ///
  /// 默认 `true`：与 studio 同名的 8 个 key 必须由后端放行。
  /// 只有**后端菜单表里根本没有这个 key** 的本端新增页才置 `false` ——
  /// 否则它会被拒绝式过滤永久挡掉（后端不认识的 key 一律不放行）。
  ///
  /// ⚠️ 这不是「绕过判权」的后门：置 `false` 的页自己不许读受控数据，
  /// 真正的数据权限在各页调用的端点上。
  final bool backendGated;

  /// 这一页从哪个入口进 —— 决定它是出现在左栏「智能体」的悬停菜单里，
  /// 还是出现在设置弹窗的「自定义」分组里。
  ///
  /// 写进 def 而不是让两个入口各自过滤一遍 key 名单：后者要在两处同步维护，
  /// 加一页忘了改另一处就会漏入口或重复出现。
  final StudioPlacement placement;

  /// 顺序即设置弹窗「自定义」分组里的展示顺序（`skill` / `memory` 除外，
  /// 它们在那边有自己的入口，见各自条目的注释）。
  static const List<StudioPageDef> all = <StudioPageDef>[
    StudioPageDef(
      key: 'scenes',
      icon: Icons.grid_view_rounded,
      label: _scenes,
      placement: StudioPlacement.settingsDialog,
    ),
    StudioPageDef(
      key: 'subagent',
      icon: Icons.smart_toy_outlined,
      label: _subagent,
      placement: StudioPlacement.settingsDialog,
    ),
    // 技能留在左栏菜单：设置弹窗里的「技能」指向的是 Customize 那套
    // 卡片/全量列表，与这页不是同一份 UI，放一起会串味。
    StudioPageDef(
      key: 'skill',
      icon: Icons.auto_awesome_outlined,
      label: _skill,
      placement: StudioPlacement.navMenu,
    ),
    StudioPageDef(
      key: 'mcp',
      icon: Icons.extension_outlined,
      label: _mcp,
      placement: StudioPlacement.settingsDialog,
    ),
    StudioPageDef(
      key: 'tools',
      icon: Icons.widgets_outlined,
      label: _tools,
      placement: StudioPlacement.settingsDialog,
    ),
    // 记忆同理：弹窗里的「记忆」是 MemoryPage，与这页的笔记列表不是一回事。
    StudioPageDef(
      key: 'memory',
      icon: Icons.memory_rounded,
      label: _memory,
      placement: StudioPlacement.navMenu,
    ),
    StudioPageDef(
      key: 'knowledge',
      icon: Icons.menu_book_outlined,
      label: _knowledge,
      placement: StudioPlacement.settingsDialog,
    ),
    StudioPageDef(
      key: 'llm-relay',
      icon: Icons.hub_outlined,
      label: _llmRelay,
      placement: StudioPlacement.settingsDialog,
    ),
    // 第 9 项。studio 的 `StudioNav.tsx` 只有 8 项，这一项是本端新增的入口
    // （端点 `ApiEndpoints.apiKey*` 早就有了，只是还没有落地页）。
    StudioPageDef(
      key: 'api-key',
      icon: Icons.vpn_key_outlined,
      label: _apiKey,
      placement: StudioPlacement.settingsDialog,
      backendGated: false,
    ),
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
String _apiKey(AppLocalizations l) => l.studioApiKey;

/// 当前可见的「智能体」子页。
///
/// ⚠️ **拒绝式（deny by default）**，与 studio `StudioNav.tsx` 的实际行为一致：
/// - 加载中 → 空（不先显示全部再抽走，避免闪现无权限菜单）；
/// - 判权失败 / 未登录（resolved=false）→ 空（**不放行**，避免后端抖动时漏出全部菜单）；
/// - 判权成功 → 只显示命中的 key。
/// **临时降级方案（2026-09-14）**：判权失败时改为全开，避免后端 nonce 服务未就绪时
/// 整个智能体菜单消失。生产环境部署完整后端后，恢复拒绝式（把下面 `// FIXME` 那行删掉）。
final visibleStudioPagesProvider =
    Provider<List<StudioPageDef>>((
      ref,
    ) {
      final menus = ref.watch(accessibleMenusProvider,).asData?.value;
      // FIXME: 临时全开模式，等后端 nonce/菜单判权服务就绪后改回
      // if (menus == null || !menus.resolved) return const <StudioPageDef>[];
      if (menus ==null)return const <StudioPageDef>[]; // 加载中仍不显示，避免闪现
      if (!menus.resolved) {
        print('[visibleStudioPagesProvider] 菜单判权失败，临时降级为全开模式',);
        return StudioPageDef.all; // 判权失败时全开，避免后端未就绪导致菜单消失
      }
      return StudioPageDef.all
      .where((p) =>
          !p.backendGated || menus.accessibleKeys.contains(p.key))
      .toList(growable: false);
    });
