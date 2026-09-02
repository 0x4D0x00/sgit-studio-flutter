import 'package:flutter/widgets.dart';

/// 导航项（**纯展示数据**）。
///
/// ⚠️ 这里刻意不含任何业务语义 —— 没有路由、没有权限、没有 studio 的 8 个 key。
/// 业务清单在 `features/<feature>/<feature>_feature.dart` 里注册，由容器组件
/// 映射成 [NavEntry] 再喂给 `NavPanel`。布局层因此不反向依赖 features。
@immutable
class NavEntry {
  const NavEntry({required this.id, required this.icon, required this.label});

  /// 选中态比对用的标识。容器自己决定它是路由、是 studio key、还是别的什么。
  final String id;

  final IconData icon;
  final String label;
}

/// 导航分组。[title] 为空时不渲染组标题（整组紧贴上一组）。
@immutable
class NavSection {
  const NavSection({this.title, required this.entries});

  final String? title;
  final List<NavEntry> entries;

  bool get isEmpty => entries.isEmpty;
}
