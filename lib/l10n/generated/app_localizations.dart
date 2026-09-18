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

  /// No description provided for @navSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get navSearch;

  /// No description provided for @navSearchDialogHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索聊天'**
  String get navSearchDialogHint;

  /// No description provided for @navSearchDialogEmpty.
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配的会话'**
  String get navSearchDialogEmpty;

  /// No description provided for @navNewChat.
  ///
  /// In zh, this message translates to:
  /// **'新建对话'**
  String get navNewChat;

  /// No description provided for @navHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史对话'**
  String get navHistory;

  /// No description provided for @navChatPin.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get navChatPin;

  /// No description provided for @navChatRename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get navChatRename;

  /// No description provided for @navViewAll.
  ///
  /// In zh, this message translates to:
  /// **'查看全部'**
  String get navViewAll;

  /// No description provided for @navSelect.
  ///
  /// In zh, this message translates to:
  /// **'选择'**
  String get navSelect;

  /// No description provided for @navSelectAll.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get navSelectAll;

  /// No description provided for @navDeselectAll.
  ///
  /// In zh, this message translates to:
  /// **'取消全选'**
  String get navDeselectAll;

  /// No description provided for @navSelectedCount.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 项'**
  String navSelectedCount(int count);

  /// No description provided for @commonClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get commonClose;

  /// No description provided for @navAssistants.
  ///
  /// In zh, this message translates to:
  /// **'助理'**
  String get navAssistants;

  /// No description provided for @assistantPentest.
  ///
  /// In zh, this message translates to:
  /// **'渗透助理'**
  String get assistantPentest;

  /// No description provided for @assistantDefense.
  ///
  /// In zh, this message translates to:
  /// **'防护助理'**
  String get assistantDefense;

  /// No description provided for @assistantContest.
  ///
  /// In zh, this message translates to:
  /// **'竞赛助理'**
  String get assistantContest;

  /// No description provided for @assistantOffice.
  ///
  /// In zh, this message translates to:
  /// **'办公助理'**
  String get assistantOffice;

  /// No description provided for @assistantSwitcher.
  ///
  /// In zh, this message translates to:
  /// **'切换助理'**
  String get assistantSwitcher;

  /// No description provided for @navStudioGroup.
  ///
  /// In zh, this message translates to:
  /// **'智能体'**
  String get navStudioGroup;

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

  /// No description provided for @chatGroupBy.
  ///
  /// In zh, this message translates to:
  /// **'分组方式'**
  String get chatGroupBy;

  /// No description provided for @chatSortBy.
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get chatSortBy;

  /// No description provided for @chatGroupNone.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get chatGroupNone;

  /// No description provided for @chatGroupDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get chatGroupDate;

  /// No description provided for @chatGroupAssistant.
  ///
  /// In zh, this message translates to:
  /// **'助理'**
  String get chatGroupAssistant;

  /// No description provided for @chatSortName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get chatSortName;

  /// No description provided for @chatSortLastActivity.
  ///
  /// In zh, this message translates to:
  /// **'最近活动'**
  String get chatSortLastActivity;

  /// No description provided for @chatGroupToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get chatGroupToday;

  /// No description provided for @chatGroupYesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get chatGroupYesterday;

  /// No description provided for @chatGroupOlder.
  ///
  /// In zh, this message translates to:
  /// **'之前'**
  String get chatGroupOlder;

  /// No description provided for @shellExpandNav.
  ///
  /// In zh, this message translates to:
  /// **'展开导航'**
  String get shellExpandNav;

  /// No description provided for @shellCollapseNav.
  ///
  /// In zh, this message translates to:
  /// **'收起导航'**
  String get shellCollapseNav;

  /// No description provided for @shellToggleOutput.
  ///
  /// In zh, this message translates to:
  /// **'输出物面板'**
  String get shellToggleOutput;

  /// No description provided for @shellOutputTitle.
  ///
  /// In zh, this message translates to:
  /// **'输出物'**
  String get shellOutputTitle;

  /// No description provided for @shellOutputEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无产物'**
  String get shellOutputEmpty;

  /// 工作台欢迎语。name 来自 brand.json，禁止在文案里写死品牌名
  ///
  /// In zh, this message translates to:
  /// **'{name}，为你待命'**
  String workspaceWelcome(String name);

  /// No description provided for @workspaceInputHint.
  ///
  /// In zh, this message translates to:
  /// **'有什么可以帮你的？'**
  String get workspaceInputHint;

  /// No description provided for @workspaceSend.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get workspaceSend;

  /// No description provided for @studioAccessDenied.
  ///
  /// In zh, this message translates to:
  /// **'无权访问该功能'**
  String get studioAccessDenied;

  /// No description provided for @studioScenes.
  ///
  /// In zh, this message translates to:
  /// **'场景'**
  String get studioScenes;

  /// No description provided for @studioSubagent.
  ///
  /// In zh, this message translates to:
  /// **'子 Agent'**
  String get studioSubagent;

  /// No description provided for @studioSkill.
  ///
  /// In zh, this message translates to:
  /// **'技能'**
  String get studioSkill;

  /// No description provided for @studioMcp.
  ///
  /// In zh, this message translates to:
  /// **'MCP'**
  String get studioMcp;

  /// No description provided for @studioTools.
  ///
  /// In zh, this message translates to:
  /// **'工具'**
  String get studioTools;

  /// No description provided for @studioMemory.
  ///
  /// In zh, this message translates to:
  /// **'记忆'**
  String get studioMemory;

  /// No description provided for @studioKnowledge.
  ///
  /// In zh, this message translates to:
  /// **'知识库'**
  String get studioKnowledge;

  /// No description provided for @studioLlmRelay.
  ///
  /// In zh, this message translates to:
  /// **'大模型中转站'**
  String get studioLlmRelay;

  /// No description provided for @studioApiKey.
  ///
  /// In zh, this message translates to:
  /// **'API 密钥'**
  String get studioApiKey;

  /// No description provided for @chatFaultNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'尚未连接到内核，无法发送'**
  String get chatFaultNotConnected;

  /// No description provided for @chatReconnect.
  ///
  /// In zh, this message translates to:
  /// **'重连'**
  String get chatReconnect;

  /// No description provided for @chatAddMenu.
  ///
  /// In zh, this message translates to:
  /// **'更多选项'**
  String get chatAddMenu;

  /// No description provided for @chatAttachFiles.
  ///
  /// In zh, this message translates to:
  /// **'附件'**
  String get chatAttachFiles;

  /// No description provided for @chatWebSearch.
  ///
  /// In zh, this message translates to:
  /// **'联网搜索'**
  String get chatWebSearch;

  /// No description provided for @chatAgentGateway.
  ///
  /// In zh, this message translates to:
  /// **'Agent Gateway'**
  String get chatAgentGateway;

  /// No description provided for @chatStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get chatStop;

  /// No description provided for @chatSteerHint.
  ///
  /// In zh, this message translates to:
  /// **'插话改方向…'**
  String get chatSteerHint;

  /// No description provided for @chatTextTruncated.
  ///
  /// In zh, this message translates to:
  /// **'内容可能不完整'**
  String get chatTextTruncated;

  /// No description provided for @chatApprovalTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要你确认'**
  String get chatApprovalTitle;

  /// No description provided for @chatApprovalAllowOnce.
  ///
  /// In zh, this message translates to:
  /// **'允许一次'**
  String get chatApprovalAllowOnce;

  /// No description provided for @chatApprovalAllowAlways.
  ///
  /// In zh, this message translates to:
  /// **'总是允许'**
  String get chatApprovalAllowAlways;

  /// No description provided for @chatApprovalDeny.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get chatApprovalDeny;

  /// No description provided for @chatApprovalResolvedAllow.
  ///
  /// In zh, this message translates to:
  /// **'已允许'**
  String get chatApprovalResolvedAllow;

  /// No description provided for @chatApprovalResolvedAlways.
  ///
  /// In zh, this message translates to:
  /// **'已设为总是允许'**
  String get chatApprovalResolvedAlways;

  /// No description provided for @chatApprovalResolvedDeny.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝'**
  String get chatApprovalResolvedDeny;

  /// No description provided for @chatToolRunning.
  ///
  /// In zh, this message translates to:
  /// **'执行中…'**
  String get chatToolRunning;

  /// No description provided for @chatToolTruncated.
  ///
  /// In zh, this message translates to:
  /// **'输出已截断，完整内容需展开获取'**
  String get chatToolTruncated;

  /// No description provided for @chatNoticeCompacted.
  ///
  /// In zh, this message translates to:
  /// **'上下文已压缩'**
  String get chatNoticeCompacted;

  /// No description provided for @chatNoticeDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'连接已断开'**
  String get chatNoticeDisconnected;

  /// No description provided for @chatNoticeUnknown.
  ///
  /// In zh, this message translates to:
  /// **'未知提示'**
  String get chatNoticeUnknown;

  /// No description provided for @chatToolElapsed.
  ///
  /// In zh, this message translates to:
  /// **'{ms} ms'**
  String chatToolElapsed(int ms);

  /// No description provided for @chatNoticeModelRerouted.
  ///
  /// In zh, this message translates to:
  /// **'模型已改道：{to}'**
  String chatNoticeModelRerouted(String to);

  /// No description provided for @chatNoticeDropped.
  ///
  /// In zh, this message translates to:
  /// **'有 {count} 条增量被合并（内容可能不完整）'**
  String chatNoticeDropped(int count);

  /// No description provided for @chatFaultVersionMismatch.
  ///
  /// In zh, this message translates to:
  /// **'内核帧格式版本 {kernel} 与客户端 {client} 不匹配，请升级客户端'**
  String chatFaultVersionMismatch(int kernel, int client);

  /// No description provided for @chatStats.
  ///
  /// In zh, this message translates to:
  /// **'输入 {input} · 输出 {output} · 耗时 {ms} ms'**
  String chatStats(int input, int output, int ms);

  /// No description provided for @studioEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get studioEmpty;

  /// No description provided for @studioRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get studioRefresh;

  /// No description provided for @studioRemove.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get studioRemove;

  /// No description provided for @studioRemoveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」？'**
  String studioRemoveConfirm(String name);

  /// No description provided for @studioRemoveConfirmMany.
  ///
  /// In zh, this message translates to:
  /// **'确定删除选中的 {count} 项？'**
  String studioRemoveConfirmMany(int count);

  /// No description provided for @studioStale.
  ///
  /// In zh, this message translates to:
  /// **'显示的是缓存，正在刷新…'**
  String get studioStale;

  /// No description provided for @studioComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'该页数据源待接'**
  String get studioComingSoon;

  /// No description provided for @relayProviders.
  ///
  /// In zh, this message translates to:
  /// **'厂商'**
  String get relayProviders;

  /// No description provided for @relayModels.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get relayModels;

  /// No description provided for @relayKeys.
  ///
  /// In zh, this message translates to:
  /// **'密钥'**
  String get relayKeys;

  /// No description provided for @relayDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已停用'**
  String get relayDisabled;

  /// No description provided for @relayCustom.
  ///
  /// In zh, this message translates to:
  /// **'自建'**
  String get relayCustom;

  /// No description provided for @relayBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get relayBack;

  /// No description provided for @relayKeyMasked.
  ///
  /// In zh, this message translates to:
  /// **'密钥仅显示后 6 位'**
  String get relayKeyMasked;

  /// No description provided for @relayContextWindow.
  ///
  /// In zh, this message translates to:
  /// **'上下文 {n}'**
  String relayContextWindow(int n);

  /// No description provided for @relayToggleOn.
  ///
  /// In zh, this message translates to:
  /// **'点击启用'**
  String get relayToggleOn;

  /// No description provided for @relayToggleOff.
  ///
  /// In zh, this message translates to:
  /// **'点击停用'**
  String get relayToggleOff;

  /// No description provided for @relaySync.
  ///
  /// In zh, this message translates to:
  /// **'同步模型'**
  String get relaySync;

  /// No description provided for @relayNoProvider.
  ///
  /// In zh, this message translates to:
  /// **'尚未配置任何厂商'**
  String get relayNoProvider;

  /// No description provided for @modelSelector.
  ///
  /// In zh, this message translates to:
  /// **'选择模型'**
  String get modelSelector;

  /// No description provided for @modelSelectorDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认模型'**
  String get modelSelectorDefault;

  /// No description provided for @modelSelectorNone.
  ///
  /// In zh, this message translates to:
  /// **'暂无可用模型'**
  String get modelSelectorNone;

  /// No description provided for @navNewChatDone.
  ///
  /// In zh, this message translates to:
  /// **'已开始新对话'**
  String get navNewChatDone;

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

  /// No description provided for @settingsGeneral.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get settingsGeneral;

  /// No description provided for @settingsAccount.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get settingsAccount;

  /// No description provided for @settingsThemeMode.
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get settingsThemeMode;

  /// No description provided for @settingsThemeTransparent.
  ///
  /// In zh, this message translates to:
  /// **'透明'**
  String get settingsThemeTransparent;

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

  /// No description provided for @settingsLanguageZh.
  ///
  /// In zh, this message translates to:
  /// **'简体中文'**
  String get settingsLanguageZh;

  /// No description provided for @settingsLanguageEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get settingsLanguageEn;

  /// No description provided for @settingsResetDefault.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get settingsResetDefault;

  /// No description provided for @accountAvatar.
  ///
  /// In zh, this message translates to:
  /// **'头像'**
  String get accountAvatar;

  /// No description provided for @accountUsername.
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get accountUsername;

  /// No description provided for @accountPassword.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get accountPassword;

  /// No description provided for @accountChangeAvatar.
  ///
  /// In zh, this message translates to:
  /// **'修改头像'**
  String get accountChangeAvatar;

  /// No description provided for @accountChangePassword.
  ///
  /// In zh, this message translates to:
  /// **'修改密码'**
  String get accountChangePassword;

  /// No description provided for @accountCurrentPassword.
  ///
  /// In zh, this message translates to:
  /// **'当前密码'**
  String get accountCurrentPassword;

  /// No description provided for @accountNewPassword.
  ///
  /// In zh, this message translates to:
  /// **'新密码'**
  String get accountNewPassword;

  /// No description provided for @accountConfirmPassword.
  ///
  /// In zh, this message translates to:
  /// **'确认密码'**
  String get accountConfirmPassword;

  /// No description provided for @accountUsernamePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get accountUsernamePlaceholder;

  /// No description provided for @accountCurrentPasswordPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'请输入当前密码'**
  String get accountCurrentPasswordPlaceholder;

  /// No description provided for @accountNewPasswordPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'请输入新密码'**
  String get accountNewPasswordPlaceholder;

  /// No description provided for @accountConfirmPasswordPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'请再次输入新密码'**
  String get accountConfirmPasswordPlaceholder;

  /// No description provided for @accountPasswordMismatch.
  ///
  /// In zh, this message translates to:
  /// **'两次输入的密码不一致'**
  String get accountPasswordMismatch;

  /// No description provided for @accountPasswordTooShort.
  ///
  /// In zh, this message translates to:
  /// **'密码长度至少为6位'**
  String get accountPasswordTooShort;

  /// No description provided for @accountUpdateSuccess.
  ///
  /// In zh, this message translates to:
  /// **'更新成功'**
  String get accountUpdateSuccess;

  /// No description provided for @accountUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'更新失败'**
  String get accountUpdateFailed;

  /// No description provided for @accountAvatarTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'图片过大，请选择小于 5MB 的图片'**
  String get accountAvatarTooLarge;

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

  /// 点到尚未接线的入口时的提示
  ///
  /// In zh, this message translates to:
  /// **'{what}：功能待接'**
  String commonNotWired(String what);

  /// No description provided for @studioScopePersonal.
  ///
  /// In zh, this message translates to:
  /// **'个人'**
  String get studioScopePersonal;

  /// No description provided for @studioScopeMaster.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get studioScopeMaster;

  /// No description provided for @studioScopeMasterHint.
  ///
  /// In zh, this message translates to:
  /// **'管理版：改动对所有用户生效'**
  String get studioScopeMasterHint;

  /// No description provided for @relayAddProvider.
  ///
  /// In zh, this message translates to:
  /// **'添加厂商'**
  String get relayAddProvider;

  /// No description provided for @relayEditProvider.
  ///
  /// In zh, this message translates to:
  /// **'编辑厂商'**
  String get relayEditProvider;

  /// No description provided for @relayDeleteProvider.
  ///
  /// In zh, this message translates to:
  /// **'删除厂商'**
  String get relayDeleteProvider;

  /// No description provided for @relayDeleteProviderHint.
  ///
  /// In zh, this message translates to:
  /// **'厂商下若仍有模型或密钥将无法删除，需先在其模型页清空。'**
  String get relayDeleteProviderHint;

  /// No description provided for @relayAddModel.
  ///
  /// In zh, this message translates to:
  /// **'手动添加模型'**
  String get relayAddModel;

  /// No description provided for @relayEditModel.
  ///
  /// In zh, this message translates to:
  /// **'编辑模型'**
  String get relayEditModel;

  /// No description provided for @relayDeleteModel.
  ///
  /// In zh, this message translates to:
  /// **'删除模型'**
  String get relayDeleteModel;

  /// No description provided for @relayKeyPool.
  ///
  /// In zh, this message translates to:
  /// **'密钥池'**
  String get relayKeyPool;

  /// No description provided for @relayKeyPoolTitle.
  ///
  /// In zh, this message translates to:
  /// **'API Key 密钥池 · {code}（该品牌下所有模型共用）'**
  String relayKeyPoolTitle(String code);

  /// No description provided for @relaySyncConfirmMaster.
  ///
  /// In zh, this message translates to:
  /// **'从 {code} 厂商接口同步最新模型列表？'**
  String relaySyncConfirmMaster(String code);

  /// No description provided for @relaySyncConfirmPersonal.
  ///
  /// In zh, this message translates to:
  /// **'直连 {code} 的接口拉取模型列表？需先填好 Base URL 并添加密钥。'**
  String relaySyncConfirmPersonal(String code);

  /// No description provided for @relayScopeHintMaster.
  ///
  /// In zh, this message translates to:
  /// **'共 {n} 个模型 · 保存/同步后自动对所有用户生效'**
  String relayScopeHintMaster(int n);

  /// No description provided for @relayScopeHintPersonal.
  ///
  /// In zh, this message translates to:
  /// **'共 {n} 个模型 · 仅本人可见 · 对话时由 sgcode 直连厂商，不经平台后端'**
  String relayScopeHintPersonal(int n);

  /// No description provided for @relayLocalBadge.
  ///
  /// In zh, this message translates to:
  /// **'个人（本地）'**
  String get relayLocalBadge;

  /// No description provided for @relayAddKey.
  ///
  /// In zh, this message translates to:
  /// **'新增'**
  String get relayAddKey;

  /// No description provided for @relayKeyNameHint.
  ///
  /// In zh, this message translates to:
  /// **'密钥备注名（可选）'**
  String get relayKeyNameHint;

  /// No description provided for @relayKeyPasteHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴 API Key'**
  String get relayKeyPasteHint;

  /// No description provided for @relayNoKeys.
  ///
  /// In zh, this message translates to:
  /// **'暂无密钥'**
  String get relayNoKeys;

  /// No description provided for @relayNoProviders.
  ///
  /// In zh, this message translates to:
  /// **'暂无厂商，点右上角「添加厂商」新建。'**
  String get relayNoProviders;

  /// No description provided for @relayFieldModelCode.
  ///
  /// In zh, this message translates to:
  /// **'品牌代码'**
  String get relayFieldModelCode;

  /// No description provided for @relayFieldProvider.
  ///
  /// In zh, this message translates to:
  /// **'厂商标签'**
  String get relayFieldProvider;

  /// No description provided for @relayFieldDisplayName.
  ///
  /// In zh, this message translates to:
  /// **'显示名'**
  String get relayFieldDisplayName;

  /// No description provided for @relayFieldBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'Base URL'**
  String get relayFieldBaseUrl;

  /// No description provided for @relayFieldEndpoint.
  ///
  /// In zh, this message translates to:
  /// **'聊天端点'**
  String get relayFieldEndpoint;

  /// No description provided for @relayFieldModelsEndpoint.
  ///
  /// In zh, this message translates to:
  /// **'模型列表端点'**
  String get relayFieldModelsEndpoint;

  /// No description provided for @relayFieldUploadBaseUrl.
  ///
  /// In zh, this message translates to:
  /// **'上传 Base URL'**
  String get relayFieldUploadBaseUrl;

  /// No description provided for @relayFieldModelType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get relayFieldModelType;

  /// No description provided for @relayFieldPriority.
  ///
  /// In zh, this message translates to:
  /// **'优先级'**
  String get relayFieldPriority;

  /// No description provided for @relayFieldModelName.
  ///
  /// In zh, this message translates to:
  /// **'模型名'**
  String get relayFieldModelName;

  /// No description provided for @relayFieldContextWindow.
  ///
  /// In zh, this message translates to:
  /// **'上下文窗口'**
  String get relayFieldContextWindow;

  /// No description provided for @relayFieldMaxOutput.
  ///
  /// In zh, this message translates to:
  /// **'最大输出'**
  String get relayFieldMaxOutput;

  /// No description provided for @relayFieldAvailable.
  ///
  /// In zh, this message translates to:
  /// **'可用'**
  String get relayFieldAvailable;

  /// No description provided for @relayRequiredModelCode.
  ///
  /// In zh, this message translates to:
  /// **'品牌代码必填（唯一，如 DeepSeek）'**
  String get relayRequiredModelCode;

  /// No description provided for @relayRequiredModelName.
  ///
  /// In zh, this message translates to:
  /// **'模型代码和模型名必填'**
  String get relayRequiredModelName;

  /// No description provided for @relayRequiredApiKey.
  ///
  /// In zh, this message translates to:
  /// **'请输入 API Key'**
  String get relayRequiredApiKey;

  /// No description provided for @commonDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In zh, this message translates to:
  /// **'新增'**
  String get commonAdd;

  /// No description provided for @commonConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get commonConfirm;

  /// No description provided for @commonSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get commonSaved;

  /// No description provided for @commonDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get commonDeleted;

  /// No description provided for @commonSynced.
  ///
  /// In zh, this message translates to:
  /// **'已同步'**
  String get commonSynced;

  /// No description provided for @relaySyncBlockedDisabled.
  ///
  /// In zh, this message translates to:
  /// **'厂商已停用，先启用才能同步'**
  String get relaySyncBlockedDisabled;

  /// No description provided for @kernelPhaseConnecting1.
  ///
  /// In zh, this message translates to:
  /// **'正在连接内核…'**
  String get kernelPhaseConnecting1;

  /// No description provided for @kernelPhaseConnecting2.
  ///
  /// In zh, this message translates to:
  /// **'正在校验身份…'**
  String get kernelPhaseConnecting2;

  /// No description provided for @kernelPhaseSandbox1.
  ///
  /// In zh, this message translates to:
  /// **'正在启动你的沙箱…'**
  String get kernelPhaseSandbox1;

  /// No description provided for @kernelPhaseSandbox2.
  ///
  /// In zh, this message translates to:
  /// **'正在拉起运行环境…'**
  String get kernelPhaseSandbox2;

  /// No description provided for @kernelPhaseSandbox3.
  ///
  /// In zh, this message translates to:
  /// **'正在准备工作目录…'**
  String get kernelPhaseSandbox3;

  /// No description provided for @kernelPhaseSandbox4.
  ///
  /// In zh, this message translates to:
  /// **'正在加载技能与 MCP 工具…'**
  String get kernelPhaseSandbox4;

  /// No description provided for @kernelPhaseSandbox5.
  ///
  /// In zh, this message translates to:
  /// **'首次启动会慢一些，请稍候…'**
  String get kernelPhaseSandbox5;

  /// No description provided for @kernelPhaseSandbox6.
  ///
  /// In zh, this message translates to:
  /// **'正在等待引擎握手…'**
  String get kernelPhaseSandbox6;

  /// No description provided for @kernelPhaseReady.
  ///
  /// In zh, this message translates to:
  /// **'内核已就绪'**
  String get kernelPhaseReady;

  /// No description provided for @chatSendWhileBusy.
  ///
  /// In zh, this message translates to:
  /// **'上一轮还在跑，可直接输入插话'**
  String get chatSendWhileBusy;

  /// No description provided for @chatNoTurnToSteer.
  ///
  /// In zh, this message translates to:
  /// **'当前没有进行中的对话，无法插话'**
  String get chatNoTurnToSteer;

  /// No description provided for @chatKernelStalled.
  ///
  /// In zh, this message translates to:
  /// **'内核长时间无响应，已恢复可输入状态'**
  String get chatKernelStalled;

  /// No description provided for @artifactsTitle.
  ///
  /// In zh, this message translates to:
  /// **'输出产物'**
  String get artifactsTitle;

  /// No description provided for @artifactsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无产物'**
  String get artifactsEmpty;

  /// No description provided for @artifactsSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索产物'**
  String get artifactsSearch;

  /// No description provided for @artifactsSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'按标题搜索'**
  String get artifactsSearchHint;

  /// No description provided for @artifactsSearchClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭搜索'**
  String get artifactsSearchClose;

  /// No description provided for @artifactsRange.
  ///
  /// In zh, this message translates to:
  /// **'时间范围'**
  String get artifactsRange;

  /// No description provided for @artifactsRangeToday.
  ///
  /// In zh, this message translates to:
  /// **'今日'**
  String get artifactsRangeToday;

  /// No description provided for @artifactsRangeWeek.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get artifactsRangeWeek;

  /// No description provided for @artifactsRangeMonth.
  ///
  /// In zh, this message translates to:
  /// **'本月'**
  String get artifactsRangeMonth;

  /// No description provided for @artifactsRangeYear.
  ///
  /// In zh, this message translates to:
  /// **'本年'**
  String get artifactsRangeYear;

  /// No description provided for @artifactsRangeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get artifactsRangeAll;

  /// 产物卡片上的最后编辑时间。when 已按当前语言格式化
  ///
  /// In zh, this message translates to:
  /// **'编辑于 {when}'**
  String artifactsEdited(String when);
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
