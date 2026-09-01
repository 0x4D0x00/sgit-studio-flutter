// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get navHome => '首页';

  @override
  String get navDashboard => '总览';

  @override
  String get navUsers => '用户管理';

  @override
  String get navOrganizations => '组织架构';

  @override
  String get navPermissions => '权限分配';

  @override
  String get navModels => '模型中转站';

  @override
  String get navApiKeys => 'API 密钥';

  @override
  String get navSettings => '设置';

  @override
  String get navLogout => '退出登录';

  @override
  String get loginButton => '登 录';

  @override
  String get loginIdentifierPlaceholder => '请输入用户名';

  @override
  String get loginPasswordPlaceholder => '请输入密码';

  @override
  String get loginCaptchaPlaceholder => '输入验证码';

  @override
  String get loginCaptchaRefresh => '点击刷新验证码';

  @override
  String get loginCaptchaFailed => '验证码加载失败，点击图片重试';

  @override
  String get loginIdentifierRequired => '请输入用户名';

  @override
  String get loginPasswordRequired => '请输入密码';

  @override
  String get loginCaptchaRequired => '请输入图形验证码';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsThemeMode => '主题模式';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsPrimaryColor => '主题色';

  @override
  String get settingsSecondaryColor => '次主题色';

  @override
  String get settingsFontScale => '字体缩放';

  @override
  String get settingsLanguage => '语言';

  @override
  String get commonSave => '保存';

  @override
  String get commonCancel => '取消';

  @override
  String get commonRefresh => '刷新';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonLoading => '加载中…';

  @override
  String get commonEmpty => '暂无数据';

  @override
  String get commonRetry => '重试';

  @override
  String get commonError => '出错了';

  @override
  String get commonComingSoon => '功能开发中';
}
