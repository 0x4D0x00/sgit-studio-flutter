/// 路由路径常量(单一真源)。
///
/// 结构对齐 sgit-studio：登录后落 `/`(工作台)，「智能体」8 个子页用 `/studio/<key>`
/// (studio 那边是 `/?studio=<key>` 就地渲染，同一套 key)。
///
/// ⚠️ 原来的「总览/用户管理/组织架构/权限分配/API 密钥」已按要求下掉 —— 它们不属于
/// studio 的侧栏结构。对应的页面文件仍留在 features/ 下未删，需要时再挂回来。
class RouteNames {
  RouteNames._();

  static const String login = '/login';

  /// 工作台首页。
  static const String home = '/';

  /// 输出产物页。
  static const String artifacts = '/artifacts';

  /// 新建产物 —— 分类选择页。
  static const String artifactsNew = '/artifacts/new';

  /// 历史对话「查看全部」页。
  static const String history = '/history';

  /// Projects 页面。
  static const String projects = '/projects';

  /// Customize 页面。
  static const String customize = '/customize';

  /// 「智能体」子页前缀，完整路径 `/studio/<key>`。
  static const String studioPrefix = '/studio';
  static String studio(String key) => '$studioPrefix/$key';

  /// 设置（studio 里挂在用户区，不在主导航）。
  static const String settings = '/settings';
}
