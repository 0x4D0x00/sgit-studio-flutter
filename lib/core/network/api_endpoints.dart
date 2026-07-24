/// 接口地址常量(单一真源)。对齐 **SGiT-Server** (`backend/main/http/routes.go`)。
///
/// ⚠️ SGiT-Server 的业务几乎全部走一个统一加密入口 [encryptedRequest]，靠 body 里的
/// `type` / `operation` / `action` 分发；不是一个业务一个 URL。下面的"逻辑端点"是
/// 分发参数常量，供 service 层拼 body 用，见 [ApiDispatch]。
class ApiEndpoints {
  ApiEndpoints._();

  /// 服务基址。可用 `--dart-define=SGIT_API_BASE=...` 覆盖连本地/测试环境。
  static const String baseUrl = String.fromEnvironment(
    'SGIT_API_BASE',
    defaultValue: 'https://potagi.cn',
  );

  // ---- 真实 HTTP 端点(少数几个) ----
  static const String encryptedRequest = '/api/encryptedRequest';
  static const String plainRequest = '/api/plainRequest';
  static const String getServerPublicKey = '/api/getServerPublicKey';
  static const String getNonce = '/api/getNonce';
  static const String captchaImage = '/api/captcha/image';
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
