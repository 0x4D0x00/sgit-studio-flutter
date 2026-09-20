import 'dart:io';

/// 桌面 / 移动：读进程环境变量。
///
/// 与 `runtime_env_web.dart` 成对，由 `runtime_config.dart` 条件导入 ——
/// Web 上 `dart:io` 不可用，所以不能在同一个文件里用 `kIsWeb` 判断，
/// 那样 Web 构建仍会去解析 `dart:io` 的符号。项目里
/// `settings_repository_{io,web}.dart` 是同一套范式。
String? readEnv(String name) => Platform.environment[name];
