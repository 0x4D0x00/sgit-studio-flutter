import 'runtime_env_io.dart'
    if (dart.library.js_interop) 'runtime_env_web.dart' as env_impl;

/// 运行时配置（单一真源）。
///
/// ⚠️ **后端地址禁止编译期写死。** sgcode 那边栽过同一个坑：`ApiConfig` 内置端点池默认
/// 指向我方 `potagi.cn`，客户私有化部署后验证码/登录/文件全打回我方 —— 既泄露，又在客户
/// 网络不通时直接登录失败（见 memory `sgcode-apibaseurl-endpoint-override`，修法是
/// 加 `SGIT_API_BASE_URL` 环境变量覆盖）。
///
/// 本客户端的解法同源、但更前一步：**没有可用的默认值就直接报错，不静默回落到任何域名。**
/// 优先级（高 → 低）：
///   1. 运行时注入 [applyOverride]（Web 从同源 `/_config/runtime.json` 读，换后端不重编）
///   2. 运行时环境变量 [envVarName]（桌面端主用 —— 与 Rust 侧同一个名字）
///   3. `--dart-define=SGIT_API_BASE_URL=...`（构建期固化，做内网包时用）
///   4. 都没有 —— 抛 [StateError]，让问题在启动时炸出来，而不是在客户网络里静默打错地址
///
/// ## ⚠️ 变量名必须与 Rust 侧一致
///
/// 这里踩过一次：Dart 读 `SGIT_API_BASE`、Rust（`ApiConfig`）读
/// `SGIT_API_BASE_URL` —— **两个不同的名字**。于是 `SGIT_API_BASE_URL=xxx` 启动时，
/// Rust 那边生效了（登录、模型列表都正常），Dart 这边却始终"未配置"。
/// 本地引擎路不读它所以一直没暴露，一切到云端引擎就报「后端地址未配置」。
///
/// 现在统一用 [envVarName]，并且**运行时就能读**（见下一段）。
///
/// ## 为什么不能只有 `String.fromEnvironment`
///
/// 那是**编译期**常量：运行时 `export SGIT_API_BASE_URL=...` 对它毫无作用，
/// 必须 `--dart-define` 重新构建整个应用。桌面端要换后端地址却得重编，不合理。
/// 所以桌面/移动优先读进程环境变量（真·运行时，见 `runtime_env_io.dart`），
/// `fromEnvironment` 退化成"构建内网包时固化进去"的兜底。
/// Web 没有进程环境变量（`runtime_env_web.dart` 恒返回 null），走 [applyOverride]。
class RuntimeConfig {
  RuntimeConfig._();

  /// 后端地址的环境变量名。**与 sgcode Rust 侧 `ApiConfig` 读的那个同名** ——
  /// 一个名字配一次，两侧同时生效。
  ///
  /// 语义是「**Go 后端 API** 的地址」（getNonce / silicoid / 文件 等 `/api/*`）。
  /// 本地引擎模式下 sgcode 直连它。**不是 gateway 地址** —— 见 [gatewayEnvVarName]。
  static const String envVarName = 'SGIT_API_BASE_URL';

  /// gateway 地址的环境变量名。缺省回落到 [envVarName]。
  ///
  /// ## 为什么要和后端 API 分开
  ///
  /// 两者**可能不在同一个入口**。实测某内网环境：
  ///
  /// ```text
  /// 10.100.0.66:32717  Go 后端 API      ✅ /api/getNonce   ❌ 无 /sgcode-kernel/ws
  /// 10.100.0.66:18088  studio nginx     ✅ /sgcode-*(反代 gateway)  ❌ /api/* 被 SPA 首页吃掉
  /// ```
  ///
  /// gateway 按设计只绑 `127.0.0.1:8788`、不对外开（见 sgcode `docs/deploy-web.md`：
  /// "不要对外开 3210/8787/8788"），外部一律经 nginx 反代。于是 gateway 的对外
  /// 入口天然和后端 API 是**两个地址**。
  ///
  /// 混用一个变量的后果（都实测踩过）：
  /// - 配 18088 → 云端对话通，但本地模型推理打到 SPA 首页，报 `Failed to get nonce`
  /// - 配 32717 → 本地通，但云端对话 404（那台没有 `/sgcode-kernel/ws`）
  ///
  /// 同机部署（gateway 与后端同一入口）时**不用配这个**，回落即可。
  static const String gatewayEnvVarName = 'SGIT_GATEWAY_BASE_URL';

  /// 构建期固化值（做内网包时 `--dart-define=SGIT_API_BASE_URL=...`）。
  static const String _compileTimeBase =
      String.fromEnvironment(envVarName);

  /// 运行时环境变量。Web 上没有进程环境，恒为 null。
  static String? _envBase() {
    final v = env_impl.readEnv(envVarName)?.trim();
    return (v == null || v.isEmpty) ? null : _stripTrailingSlash(v);
  }

  static String? _override;

  /// 运行时注入（`bootstrap` 阶段调用一次）。传空串等同于没配。
  static void applyOverride(String? baseUrl) {
    final v = baseUrl?.trim();
    _override = (v == null || v.isEmpty) ? null : _stripTrailingSlash(v);
  }

  /// 是否已有可用后端地址。UI 可据此给出"未配置后端"的明确提示。
  static bool get isConfigured => _resolve() != null;

  /// 后端基址。未配置时**抛异常**，不回落到任何写死的域名。
  static String get apiBaseUrl {
    final v = _resolve();
    if (v == null) {
      throw StateError(
        '后端地址未配置。任选其一：\n'
        '  1) 设环境变量 $envVarName=<url>（桌面端推荐，与 sgcode 共用同一个变量）\n'
        '  2) 构建时 --dart-define=$envVarName=<url>（做内网包）\n'
        '  3) Web：在 /_config/runtime.json 里提供 apiBaseUrl\n'
        '禁止回落到任何内置域名。',
      );
    }
    return v;
  }

  /// gateway 的构建期固化值。
  ///
  /// ⚠️ **不能少这一条**。漏了它 `--dart-define=SGIT_GATEWAY_BASE_URL=...` 会被
  /// **静默忽略**并回落到 [apiBaseUrl] —— 踩过：明明传了 18088，日志里却是
  /// `建连模式=云端引擎 → ws://…:32717/sgcode-kernel/ws`，而 32717 上没有
  /// `/sgcode-kernel/ws`。两个 getter 的来源必须对称，见 [_compileTimeBase]。
  static const String _compileTimeGateway =
      String.fromEnvironment(gatewayEnvVarName);

  /// gateway 基址。未单独配置时回落到 [apiBaseUrl]（同机部署的常见情形）。
  ///
  /// 云端引擎模式的 WS、以及 studio 各页的 `gatewayCall` 都打这里。
  /// 优先级与 [apiBaseUrl] 一致：运行时注入 > 环境变量 > 构建期固化 > 回落。
  static String get gatewayBaseUrl {
    final v = _gatewayOverride ?? _envGateway() ?? _compileGateway();
    return v ?? apiBaseUrl; // 回落；apiBaseUrl 未配置时由它抛错
  }

  static String? _compileGateway() {
    final v = _stripTrailingSlash(_compileTimeGateway);
    return v.isEmpty ? null : v;
  }

  static String? _gatewayOverride;

  /// 运行时注入 gateway 地址（Web 从 `/_config/runtime.json` 读）。
  static void applyGatewayOverride(String? url) {
    final v = url?.trim();
    _gatewayOverride = (v == null || v.isEmpty) ? null : _stripTrailingSlash(v);
  }

  static String? _envGateway() {
    final v = env_impl.readEnv(gatewayEnvVarName)?.trim();
    return (v == null || v.isEmpty) ? null : _stripTrailingSlash(v);
  }

  /// 按优先级解析，全空返回 null。
  static String? _resolve() {
    if (_override != null) return _override;
    final env = _envBase();
    if (env != null) return env;
    final compile = _stripTrailingSlash(_compileTimeBase);
    return compile.isEmpty ? null : compile;
  }

  static String _stripTrailingSlash(String v) =>
      v.endsWith('/') ? v.substring(0, v.length - 1) : v;
}
