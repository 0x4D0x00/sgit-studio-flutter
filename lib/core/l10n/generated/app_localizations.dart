import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @navHome.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get navHome;

  /// No description provided for @navDashboard.
  ///
  /// In zh, this message translates to:
  /// **'总览'**
  String get navDashboard;

  /// No description provided for @navUsers.
  ///
  /// In zh, this message translates to:
  /// **'用户管理'**
  String get navUsers;

  /// No description provided for @navOrganizations.
  ///
  /// In zh, this message translates to:
  /// **'组织架构'**
  String get navOrganizations;

  /// No description provided for @navPermissions.
  ///
  /// In zh, this message translates to:
  /// **'权限分配'**
  String get navPermissions;

  /// No description provided for @navModels.
  ///
  /// In zh, this message translates to:
  /// **'模型中转站'**
  String get navModels;

  /// No description provided for @navApiKeys.
  ///
  /// In zh, this message translates to:
  /// **'API 密钥'**
  String get navApiKeys;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @navLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get navLogout;

  /// No description provided for @loginButton.
  ///
  /// In zh, this message translates to:
  /// **'登 录'**
  String get loginButton;

  /// No description provided for @loginIdentifierPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get loginIdentifierPlaceholder;

  /// No description provided for @loginPasswordPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get loginPasswordPlaceholder;

  /// No description provided for @loginCaptchaPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'输入验证码'**
  String get loginCaptchaPlaceholder;

  /// No description provided for @loginCaptchaRefresh.
  ///
  /// In zh, this message translates to:
  /// **'点击刷新验证码'**
  String get loginCaptchaRefresh;

  /// No description provided for @loginCaptchaFailed.
  ///
  /// In zh, this message translates to:
  /// **'验证码加载失败，点击图片重试'**
  String get loginCaptchaFailed;

  /// No description provided for @loginIdentifierRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get loginIdentifierRequired;

  /// No description provided for @loginPasswordRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get loginPasswordRequired;

  /// No description provided for @loginCaptchaRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入图形验证码'**
  String get loginCaptchaRequired;

  /// No description provided for @settingsTitle.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settingsTitle;

  /// No description provided for @settingsThemeMode.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get settingsThemeMode;

  /// No description provided for @settingsThemeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get settingsThemeDark;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get settingsThemeSystem;

  /// No description provided for @settingsPrimaryColor.
  ///
  /// In zh, this message translates to:
  /// **'主题色'**
  String get settingsPrimaryColor;

  /// No description provided for @settingsSecondaryColor.
  ///
  /// In zh, this message translates to:
  /// **'次主题色'**
  String get settingsSecondaryColor;

  /// No description provided for @settingsFontScale.
  ///
  /// In zh, this message translates to:
  /// **'字体缩放'**
  String get settingsFontScale;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @commonSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get commonCancel;

  /// No description provided for @commonRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get commonRefresh;

  /// No description provided for @commonSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get commonSearch;

  /// No description provided for @commonLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get commonLoading;

  /// No description provided for @commonEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get commonEmpty;

  /// No description provided for @commonRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get commonRetry;

  /// No description provided for @commonError.
  ///
  /// In zh, this message translates to:
  /// **'出错了'**
  String get commonError;

  /// No description provided for @commonComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'功能开发中'**
  String get commonComingSoon;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
