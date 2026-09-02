import 'package:sgit_studio_flutter/core/config/runtime_config.dart';

/// 接口地址常量(单一真源)。对齐 **SGiT-Server** (`backend/main/http/routes.go`)。
///
/// ⚠️ SGiT-Server 的业务几乎全部走一个统一加密入口 [encryptedRequest]，靠 body 里的
/// `type` / `operation` / `action` 分发；不是一个业务一个 URL。下面的"逻辑端点"是
/// 分发参数常量，供 service 层拼 body 用，见 [ApiDispatch]。
class ApiEndpoints {
  ApiEndpoints._();

  /// 服务基址。**转发到 [RuntimeConfig]，这里不许再出现任何写死的域名。**
  ///
  /// 原来这里的默认值是 `https://potagi.cn`（我方地址）。虽然当时没有任何调用方
  /// —— 端点是 Rust FFI 侧自己解析的 —— 但留着就是个雷：谁哪天顺手用了，客户私有化
  /// 部署就会把请求打回我方。同 memory `sgcode-apibaseurl-endpoint-override`。
  static String get baseUrl => RuntimeConfig.apiBaseUrl;

  // ---- 真实 HTTP 端点(少数几个) ----
  static const String encryptedRequest = '/api/encryptedRequest';
  static const String plainRequest = '/api/plainRequest';
  static const String getServerPublicKey = '/api/getServerPublicKey';
  static const String getNonce = '/api/getNonce';
  static const String captchaImage = '/api/captcha/image';

  // ---- auth-server 同源端点(Web 专用) ----
  // Web 端没有 .so 可加载,这几个走 nginx `location /auth/` 反代到 auth-server。
  // ⚠️ 只有 GET 能这么直取:后端 browser_crypto 中间件对 GET/HEAD 豁免加密
  // (见 sgit-services/src/http/browser_crypto.rs 的 is_exempt),POST 必须走加密信封。
  /// 图形验证码(GET,明文 `{captcha_id, svg}`)。
  static const String authImageCaptcha = '/auth/imageCaptcha';

  /// 应用层加密握手:取服务端 RSA 公钥(GET,明文)。
  static const String authServerPublicKey = '/auth/serverPublicKey';

  /// 登录 V2(POST,**必须**加密信封,Web 待接加密后启用)。
  static const String authLoginPasswordV2 = '/auth/loginPasswordV2';
}

/// 统一入口的分发参数(type/operation/action)常量。业务模块按需引用，避免散落字面量。
///
/// 目前只放骨架会用到的几组，后续各 feature 的 service 再补齐自己那部分。
class ApiDispatch {
  ApiDispatch._();

  // 认证 / 用户状态
  static const login = (type: 'userStatus', operation: 'login');
  static const logout = (type: 'userStatus', operation: 'logout');

  // 基础信息 - 用户管理 (走 command/basic_information/<action>)
  static const userList = (type: 'command', operation: 'basic_information', action: 'user_list');
  static const userRegister = (type: 'command', operation: 'basic_information', action: 'user_register');
  static const userGet = (type: 'command', operation: 'basic_information', action: 'user_get');
  static const userUpdate = (type: 'command', operation: 'basic_information', action: 'user_update');
  static const userStatusUpdate = (type: 'command', operation: 'basic_information', action: 'user_status_update');

  // AI 平台 - API Key 管理
  static const apiKeyList = (type: 'aiBasicPlatform', operation: 'apiKeyManage', action: 'list');
  static const apiKeyCreate = (type: 'aiBasicPlatform', operation: 'apiKeyManage', action: 'create');
  static const apiKeyDelete = (type: 'aiBasicPlatform', operation: 'apiKeyManage', action: 'delete');

  // 菜单权限
  static const menuManagement = (type: 'command', operation: 'menu_system', action: 'menu_management');

  // 文件权限
  static const fileUpdateAllowedApps = (type: 'fileSystem', operation: 'updateAllowedApps');
}
