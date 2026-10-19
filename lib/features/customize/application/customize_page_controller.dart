import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Customize 页面顶部的内容类型标签。
///
/// 前三个是 LobeChat 那套「自定义」内容（技能 / 连接器 / 插件）；
/// 后面几项是 sgcode 的智能体配置页 —— 它们原先在左栏「智能体」的悬停菜单里，
/// 那个入口已移除，统一收到设置弹窗与这里。
///
/// ⚠️ 与 `StudioPageDef.key` 的对应关系写死在 [studioPageKey]，
/// 不要靠 enum 名字猜（`subagent` 对应 `subagent`，但 `modelRelay` 对应
/// `llm-relay`、`apiKey` 对应 `api-key`）。
enum CustomizeTab {
  skills,
  connectors,
  plugins,
  scenes,
  subagent,
  mcp,
  tools,
  knowledge,
  llmRelay,
  apiKey;

  /// 该 tab 对应的 studio 页 key；前三个自定义 tab 没有。
  String? get studioPageKey => switch (this) {
        CustomizeTab.scenes => 'scenes',
        CustomizeTab.subagent => 'subagent',
        CustomizeTab.mcp => 'mcp',
        CustomizeTab.tools => 'tools',
        CustomizeTab.knowledge => 'knowledge',
        CustomizeTab.llmRelay => 'llm-relay',
        CustomizeTab.apiKey => 'api-key',
        _ => null,
      };

  /// 是否属于「自定义」（LobeChat 那套），决定要不要显示 Yours/Discover 切换。
  bool get isCustomizeContent => studioPageKey == null;
}

/// Customize 页面当前选中的标签，放到 provider 而不是页面内部 State ——
/// 这样设置弹窗里的 Skills/Connectors/Plugins 项在用户已经停在 Customize
/// 页面时，能直接切换这个 provider 再关掉弹窗，而不是在弹窗里再渲染一份重复内容。
class CustomizeTabController extends StateNotifier<CustomizeTab> {
  CustomizeTabController() : super(CustomizeTab.skills);

  void setTab(CustomizeTab tab) => state = tab;
}

final customizeTabControllerProvider =
    StateNotifierProvider<CustomizeTabController, CustomizeTab>(
  (ref) => CustomizeTabController(),
);
