/// 鉴权失败的唯一判定与广播口。
///
/// ## 为什么需要这一层
///
/// 后端判「未登录 / 令牌失效」时回的是普通业务失败信封：
/// `{"status":"fail","message":"认证失败: 无效的user_auth_token: ..."}`。
/// 它和「网络不通」「请求参数错」在形状上**没有任何区别**，于是每层只能各自
/// catch 住、各自咽掉：
///
/// ```text
/// model_list_controller   → 保留 cache，只 debugPrint
/// relay_controller        → 保留 cache，只 debugPrint
/// thread_list_controller  → 塞进 state.error，界面不展示
/// session_sync            → 注释直接写明「一律不抛」
/// ```
///
/// 用户看到的就是「明明登录着，却暂无可用模型 / 列表空白 / 点了没反应」——
/// 而登录页永远到达不了，只能手动清 localStorage。真踩过。
///
/// 这里把两件事收成一处：
/// 1. [isAuthFailureMessage]：所有入口共用一套判据，不再各写一个 `contains`；
/// 2. [report]：任一入口识别到就广播一次，`AuthController` 订阅后统一清会话，
///    路由（`app_router.dart`）的监听随即使它跳登录页。
///
/// ## 不要在这里做 UI
///
/// 本文件只发信号，不持有 BuildContext、不弹提示 —— 它被后台 isolate 之外
/// 的任意仓储调用，**可能在 build 期间被触发**。
library;

/// 「这次失败是因为身份没了」的判据。
///
/// 覆盖三处来源（别按其中一处写死）：
/// - Rust/gateway 打的 `[auth_expired]` 功能标记；
/// - Go 后端 `authenticateUser` 的原话（`sgit-server/backend/main/http/distribute.go`）：
///   `缺少user_auth_token` / `无效的user_auth_token` / `认证失败: ...`；
/// - 令牌校验的原话（`backend/basicinformation/cache/userauthtokens.go`）：
///   `认证令牌已过期` / `认证令牌已被吊销或冻结` / `认证令牌签名无效`。
///
/// ⚠️ **不要加「未登录」以外的宽泛词**（比如只写 `token`）：业务参数里也有
/// token（`silicoid` 的厂商密钥、邀请码之类），误判会把人无辜踢下线。
bool isAuthFailureMessage(String? message) {
  if (message == null) return false;
  final m = message;
  return m.contains('[auth_expired]') ||
      m.contains('auth_expired') ||
      m.contains('认证令牌已过期') ||
      m.contains('认证令牌已被吊销或冻结') ||
      m.contains('认证令牌签名无效') ||
      m.contains('认证令牌格式') ||
      m.contains('无效的user_auth_token') ||
      m.contains('缺少user_auth_token') ||
      m.contains('认证失败') ||
      m.contains('请重新登录') ||
      // 网关 WS 的拒绝语（`gateway_kernel_ws.rs` / `gateway_chat_ws.rs`）
      m.contains('未在本服务器登录过') ||
      // Rust 侧 FFI 会话缺失的原话（`sgit-ffi/src/{settings,studio,session_sync}.rs`
      // 的 `err("未登录")`、`kernel.rs` 的「无进程内会话」）。
      //
      // 这几条是桌面端最常见的形态：token 过期 → Rust 取不到令牌 → 每个
      // 入口都回「未登录」，而 Dart 原来把它当成普通业务失败咽掉。
      m.contains('未登录') ||
      m.contains('无进程内会话') ||
      m.contains('未找到有效的认证信息');
}

/// 一次鉴权失败事件。
class AuthFailureEvent {
  const AuthFailureEvent(this.message);
  final String message;

  @override
  String toString() => 'AuthFailureEvent($message)';
}

/// 全局广播点。刻意做成静态、无依赖 —— 仓储层（含后台 isolate 之外的任意
/// 调用点）可以直接调，不需要拿到 ProviderContainer。
class AuthFailure {
  AuthFailure._();

  static final List<void Function(AuthFailureEvent)> _listeners = [];

  static void addListener(void Function(AuthFailureEvent) listener) {
    _listeners.add(listener);
  }

  static void removeListener(void Function(AuthFailureEvent) listener) {
    _listeners.remove(listener);
  }

  /// 广播一次「身份失效」。
  ///
  /// 幂等：重复广播由订阅方（`AuthController.invalidate`）自己判「已经未登录」，
  /// 这里不做去重 —— 去重状态放静态变量会在热重载/测试间残留。
  static void report(String message) {
    final event = AuthFailureEvent(message);
    for (final l in List.of(_listeners)) {
      try {
        l(event);
      } catch (_) {
        // 订阅方自己出错不该拖垮本次请求的异常传播。
      }
    }
  }

  /// 便捷入口：消息命中判据才广播。返回是否命中，方便调用方直接用于
  /// `ApiException(isAuthExpired: ...)`。
  static bool reportIfAuth(String? message) {
    if (!isAuthFailureMessage(message)) return false;
    report(message ?? '');
    return true;
  }
}
