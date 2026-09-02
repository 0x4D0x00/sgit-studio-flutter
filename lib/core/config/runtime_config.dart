/// 运行时配置（单一真源）。
///
/// ⚠️ **后端地址禁止编译期写死。** sgcode 那边栽过同一个坑：`ApiConfig` 内置端点池默认
/// 指向我方 `potagi.cn`，客户私有化部署后验证码/登录/文件全打回我方 —— 既泄露，又在客户
/// 网络不通时直接登录失败（见 memory `sgcode-apibaseurl-endpoint-override`，修法是
/// 加 `SGIT_API_BASE_URL` 环境变量覆盖）。
///
/// 本客户端的解法同源、但更前一步：**没有可用的默认值就直接报错，不静默回落到任何域名。**
/// 优先级（高 → 低）：
///   1. `--dart-define=SGIT_API_BASE=...`（构建期指定，桌面包/内网包用）
///   2. 运行时注入 [override]（Web 从同源 `/_config/runtime.json` 读，换后端不重编）
///   3. 都没有 —— 抛 [StateError]，让问题在启动时炸出来，而不是在客户网络里静默打错地址
class RuntimeConfig {
  RuntimeConfig._();

  static const String _compileTimeBase =
      String.fromEnvironment('SGIT_API_BASE');

  static String? _override;

  /// 运行时注入（`bootstrap` 阶段调用一次）。传空串等同于没配。
  static void applyOverride(String? baseUrl) {
    final v = baseUrl?.trim();
    _override = (v == null || v.isEmpty) ? null : _stripTrailingSlash(v);
  }

  /// 是否已有可用后端地址。UI 可据此给出"未配置后端"的明确提示。
  static bool get isConfigured =>
      _override != null || _compileTimeBase.isNotEmpty;

  /// 后端基址。未配置时**抛异常**，不回落到任何写死的域名。
  static String get apiBaseUrl {
    final v = _override ?? _stripTrailingSlash(_compileTimeBase);
    if (v.isEmpty) {
      throw StateError(
        '后端地址未配置。请用 --dart-define=SGIT_API_BASE=<url> 构建，'
        '或在 /_config/runtime.json 里提供 apiBaseUrl。'
        '禁止回落到任何内置域名。',
      );
    }
    return v;
  }

  static String _stripTrailingSlash(String v) =>
      v.endsWith('/') ? v.substring(0, v.length - 1) : v;
}
