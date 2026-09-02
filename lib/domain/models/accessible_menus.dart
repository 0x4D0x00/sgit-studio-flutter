/// 「智能体」菜单判权结果。
class AccessibleMenus {
  const AccessibleMenus({required this.accessibleKeys, required this.resolved});

  /// 可见的 menu_key 集合（scenes/subagent/skill/mcp/tools/memory/knowledge/llm-relay）。
  final Set<String> accessibleKeys;

  /// 是否成功判权。false = 未登录 / 请求失败 / 后端异常。
  final bool resolved;

  static const AccessibleMenus unresolved =
      AccessibleMenus(accessibleKeys: <String>{}, resolved: false);
}
