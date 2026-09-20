/// Web：没有进程环境变量。
///
/// 浏览器里换后端走 `RuntimeConfig.applyOverride`（从同源
/// `/_config/runtime.json` 读），不需要也拿不到 env。
String? readEnv(String name) => null;
