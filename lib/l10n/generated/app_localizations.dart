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

  /// No description provided for @navNew.
  ///
  /// In zh, this message translates to:
  /// **'新建'**
  String get navNew;

  /// No description provided for @navProjects.
  ///
  /// In zh, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @navCustomize.
  ///
  /// In zh, this message translates to:
  /// **'Customize'**
  String get navCustomize;

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

  /// No description provided for @navGetHelp.
  ///
  /// In zh, this message translates to:
  /// **'寻求帮助'**
  String get navGetHelp;

  /// No description provided for @navLearnMore.
  ///
  /// In zh, this message translates to:
  /// **'了解更多'**
  String get navLearnMore;

  /// No description provided for @navAboutBrand.
  ///
  /// In zh, this message translates to:
  /// **'关于 {brand}'**
  String navAboutBrand(String brand);

  /// No description provided for @navUsagePolicy.
  ///
  /// In zh, this message translates to:
  /// **'使用政策'**
  String get navUsagePolicy;

  /// No description provided for @navPrivacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get navPrivacyPolicy;

  /// No description provided for @navTermsOfService.
  ///
  /// In zh, this message translates to:
  /// **'服务条款'**
  String get navTermsOfService;

  /// No description provided for @navPrivacyChoices.
  ///
  /// In zh, this message translates to:
  /// **'您的隐私设置'**
  String get navPrivacyChoices;

  /// No description provided for @navKeyboardShortcuts.
  ///
  /// In zh, this message translates to:
  /// **'键盘快捷键'**
  String get navKeyboardShortcuts;

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

  /// No description provided for @chatGroupUnknown.
  ///
  /// In zh, this message translates to:
  /// **'时间未知'**
  String get chatGroupUnknown;

  /// No description provided for @chatRenameHint.
  ///
  /// In zh, this message translates to:
  /// **'保持简短且易于识别。'**
  String get chatRenameHint;

  /// No description provided for @chatHistoryEmptyAction.
  ///
  /// In zh, this message translates to:
  /// **'开启新对话'**
  String get chatHistoryEmptyAction;

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
  /// **'添加文件/图片'**
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

  /// No description provided for @chatPickFile.
  ///
  /// In zh, this message translates to:
  /// **'选择文件'**
  String get chatPickFile;

  /// No description provided for @chatPickImage.
  ///
  /// In zh, this message translates to:
  /// **'选择图片'**
  String get chatPickImage;

  /// No description provided for @chatPickFileFailed.
  ///
  /// In zh, this message translates to:
  /// **'选择文件失败：{reason}'**
  String chatPickFileFailed(String reason);

  /// No description provided for @chatRemoveAttachment.
  ///
  /// In zh, this message translates to:
  /// **'移除附件'**
  String get chatRemoveAttachment;

  /// No description provided for @chatReply.
  ///
  /// In zh, this message translates to:
  /// **'回复'**
  String get chatReply;

  /// No description provided for @chatQuoteTitle.
  ///
  /// In zh, this message translates to:
  /// **'引用'**
  String get chatQuoteTitle;

  /// No description provided for @chatRemoveQuote.
  ///
  /// In zh, this message translates to:
  /// **'移除引用'**
  String get chatRemoveQuote;

  /// No description provided for @chatClearScene.
  ///
  /// In zh, this message translates to:
  /// **'退出场景'**
  String get chatClearScene;

  /// No description provided for @chatMemory.
  ///
  /// In zh, this message translates to:
  /// **'记忆'**
  String get chatMemory;

  /// No description provided for @chatSkills.
  ///
  /// In zh, this message translates to:
  /// **'技能'**
  String get chatSkills;

  /// No description provided for @chatKnowledge.
  ///
  /// In zh, this message translates to:
  /// **'知识库'**
  String get chatKnowledge;

  /// No description provided for @chatContextWindow.
  ///
  /// In zh, this message translates to:
  /// **'上下文窗口'**
  String get chatContextWindow;

  /// No description provided for @chatContextWindowDetail.
  ///
  /// In zh, this message translates to:
  /// **'已用 {used} / 共 {total} tokens'**
  String chatContextWindowDetail(int used, int total);

  /// No description provided for @chatApprovalPolicy.
  ///
  /// In zh, this message translates to:
  /// **'审批策略'**
  String get chatApprovalPolicy;

  /// No description provided for @chatApprovalUntrusted.
  ///
  /// In zh, this message translates to:
  /// **'仅信任只读'**
  String get chatApprovalUntrusted;

  /// No description provided for @chatApprovalUntrustedDesc.
  ///
  /// In zh, this message translates to:
  /// **'只自动批准已知安全的只读命令，其余都问你'**
  String get chatApprovalUntrustedDesc;

  /// No description provided for @chatApprovalOnRequest.
  ///
  /// In zh, this message translates to:
  /// **'由模型决定'**
  String get chatApprovalOnRequest;

  /// No description provided for @chatApprovalOnRequestDesc.
  ///
  /// In zh, this message translates to:
  /// **'模型自行判断何时需要你批准（引擎默认）'**
  String get chatApprovalOnRequestDesc;

  /// No description provided for @chatApprovalNever.
  ///
  /// In zh, this message translates to:
  /// **'从不询问'**
  String get chatApprovalNever;

  /// No description provided for @chatApprovalNeverDesc.
  ///
  /// In zh, this message translates to:
  /// **'从不打断你，失败直接返回给模型'**
  String get chatApprovalNeverDesc;

  /// No description provided for @chatApprovalGranular.
  ///
  /// In zh, this message translates to:
  /// **'细粒度'**
  String get chatApprovalGranular;

  /// No description provided for @chatApprovalGranularDesc.
  ///
  /// In zh, this message translates to:
  /// **'逐类控制哪些操作需要审批'**
  String get chatApprovalGranularDesc;

  /// No description provided for @chatApprovalFieldSandbox.
  ///
  /// In zh, this message translates to:
  /// **'Shell 命令'**
  String get chatApprovalFieldSandbox;

  /// No description provided for @chatApprovalFieldRules.
  ///
  /// In zh, this message translates to:
  /// **'规则变更'**
  String get chatApprovalFieldRules;

  /// No description provided for @chatApprovalFieldSkill.
  ///
  /// In zh, this message translates to:
  /// **'技能调用'**
  String get chatApprovalFieldSkill;

  /// No description provided for @chatApprovalFieldPermissions.
  ///
  /// In zh, this message translates to:
  /// **'权限申请'**
  String get chatApprovalFieldPermissions;

  /// No description provided for @chatApprovalFieldMcp.
  ///
  /// In zh, this message translates to:
  /// **'MCP 请求'**
  String get chatApprovalFieldMcp;

  /// No description provided for @chatSandboxMode.
  ///
  /// In zh, this message translates to:
  /// **'沙箱'**
  String get chatSandboxMode;

  /// No description provided for @chatSandboxReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'只读'**
  String get chatSandboxReadOnly;

  /// No description provided for @chatSandboxReadOnlyDesc.
  ///
  /// In zh, this message translates to:
  /// **'只能读，不能改动任何文件（引擎默认）'**
  String get chatSandboxReadOnlyDesc;

  /// No description provided for @chatSandboxWorkspaceWrite.
  ///
  /// In zh, this message translates to:
  /// **'可写工作区'**
  String get chatSandboxWorkspaceWrite;

  /// No description provided for @chatSandboxWorkspaceWriteDesc.
  ///
  /// In zh, this message translates to:
  /// **'可以改动工作目录内的文件'**
  String get chatSandboxWorkspaceWriteDesc;

  /// No description provided for @chatSandboxDangerFullAccess.
  ///
  /// In zh, this message translates to:
  /// **'完全放开'**
  String get chatSandboxDangerFullAccess;

  /// No description provided for @chatSandboxDangerFullAccessDesc.
  ///
  /// In zh, this message translates to:
  /// **'不做任何限制。仅在你清楚风险时使用'**
  String get chatSandboxDangerFullAccessDesc;

  /// No description provided for @chatReasoningEffort.
  ///
  /// In zh, this message translates to:
  /// **'推理强度'**
  String get chatReasoningEffort;

  /// No description provided for @chatEffortNone.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get chatEffortNone;

  /// No description provided for @chatEffortMinimal.
  ///
  /// In zh, this message translates to:
  /// **'极低'**
  String get chatEffortMinimal;

  /// No description provided for @chatEffortLow.
  ///
  /// In zh, this message translates to:
  /// **'低'**
  String get chatEffortLow;

  /// No description provided for @chatEffortMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get chatEffortMedium;

  /// No description provided for @chatEffortHigh.
  ///
  /// In zh, this message translates to:
  /// **'高'**
  String get chatEffortHigh;

  /// No description provided for @chatEffortXhigh.
  ///
  /// In zh, this message translates to:
  /// **'很高'**
  String get chatEffortXhigh;

  /// No description provided for @chatEffortMax.
  ///
  /// In zh, this message translates to:
  /// **'最高'**
  String get chatEffortMax;

  /// No description provided for @chatEffortUltra.
  ///
  /// In zh, this message translates to:
  /// **'极限'**
  String get chatEffortUltra;

  /// No description provided for @chatSettingWriteFailed.
  ///
  /// In zh, this message translates to:
  /// **'设置未保存：{reason}'**
  String chatSettingWriteFailed(String reason);

  /// No description provided for @chatTextTruncated.
  ///
  /// In zh, this message translates to:
  /// **'内容可能不完整'**
  String get chatTextTruncated;

  /// No description provided for @chatCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get chatCopy;

  /// No description provided for @chatCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get chatCopied;

  /// No description provided for @chatCopiedAll.
  ///
  /// In zh, this message translates to:
  /// **'已复制整段会话'**
  String get chatCopiedAll;

  /// No description provided for @chatArtifactOpen.
  ///
  /// In zh, this message translates to:
  /// **'在右侧打开'**
  String get chatArtifactOpen;

  /// No description provided for @chatArtifactDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get chatArtifactDownload;

  /// No description provided for @chatArtifactClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get chatArtifactClose;

  /// No description provided for @chatArtifactDownloading.
  ///
  /// In zh, this message translates to:
  /// **'正在保存…'**
  String get chatArtifactDownloading;

  /// No description provided for @chatArtifactSaved.
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get chatArtifactSaved;

  /// No description provided for @chatArtifactSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'保存失败'**
  String get chatArtifactSaveFailed;

  /// No description provided for @chatArtifactExpand.
  ///
  /// In zh, this message translates to:
  /// **'全屏查看'**
  String get chatArtifactExpand;

  /// No description provided for @chatArtifactCollapse.
  ///
  /// In zh, this message translates to:
  /// **'退出全屏'**
  String get chatArtifactCollapse;

  /// No description provided for @chatArtifactPanelTitle.
  ///
  /// In zh, this message translates to:
  /// **'产物'**
  String get chatArtifactPanelTitle;

  /// No description provided for @chatArtifactPanelEmpty.
  ///
  /// In zh, this message translates to:
  /// **'本次会话还没有产物'**
  String get chatArtifactPanelEmpty;

  /// No description provided for @chatArtifactUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'这份内容无法以图形方式渲染，已按原文显示'**
  String get chatArtifactUnavailable;

  /// No description provided for @chatEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get chatEdit;

  /// No description provided for @chatEditRegenerateHint.
  ///
  /// In zh, this message translates to:
  /// **'保存后将丢弃此消息之后的内容，并用编辑后的内容重新开始本次会话'**
  String get chatEditRegenerateHint;

  /// No description provided for @chatRetry.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get chatRetry;

  /// No description provided for @chatReadAloud.
  ///
  /// In zh, this message translates to:
  /// **'朗读'**
  String get chatReadAloud;

  /// No description provided for @chatThumbUp.
  ///
  /// In zh, this message translates to:
  /// **'赞'**
  String get chatThumbUp;

  /// No description provided for @chatThumbDown.
  ///
  /// In zh, this message translates to:
  /// **'踩'**
  String get chatThumbDown;

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

  /// No description provided for @chatEngineMode.
  ///
  /// In zh, this message translates to:
  /// **'引擎模式'**
  String get chatEngineMode;

  /// No description provided for @chatEngineModeLocal.
  ///
  /// In zh, this message translates to:
  /// **'本地引擎'**
  String get chatEngineModeLocal;

  /// No description provided for @chatEngineModeRemote.
  ///
  /// In zh, this message translates to:
  /// **'云端引擎'**
  String get chatEngineModeRemote;

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

  /// No description provided for @chatThinking1.
  ///
  /// In zh, this message translates to:
  /// **'正在思考…'**
  String get chatThinking1;

  /// No description provided for @chatThinking2.
  ///
  /// In zh, this message translates to:
  /// **'正在梳理…'**
  String get chatThinking2;

  /// No description provided for @chatThinking3.
  ///
  /// In zh, this message translates to:
  /// **'正在推敲…'**
  String get chatThinking3;

  /// No description provided for @chatThinking4.
  ///
  /// In zh, this message translates to:
  /// **'正在核对…'**
  String get chatThinking4;

  /// No description provided for @chatThinking5.
  ///
  /// In zh, this message translates to:
  /// **'正在落笔…'**
  String get chatThinking5;

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

  /// No description provided for @studioUnsyncedHint.
  ///
  /// In zh, this message translates to:
  /// **'本地已修改，尚未同步到服务器'**
  String get studioUnsyncedHint;

  /// No description provided for @studioSyncNow.
  ///
  /// In zh, this message translates to:
  /// **'同步到服务器'**
  String get studioSyncNow;

  /// No description provided for @studioSyncDone.
  ///
  /// In zh, this message translates to:
  /// **'已同步'**
  String get studioSyncDone;

  /// No description provided for @studioSyncConflicts.
  ///
  /// In zh, this message translates to:
  /// **'已同步，{count} 项有冲突：服务器版本已生效，你的改动存为 .conflict 备份'**
  String studioSyncConflicts(int count);

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

  /// No description provided for @relayPlatform.
  ///
  /// In zh, this message translates to:
  /// **'平台'**
  String get relayPlatform;

  /// No description provided for @relayPlatformReadonly.
  ///
  /// In zh, this message translates to:
  /// **'平台开放的厂商/模型，个人页只读'**
  String get relayPlatformReadonly;

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

  /// No description provided for @loginSessionExpired.
  ///
  /// In zh, this message translates to:
  /// **'登录已过期，请重新登录'**
  String get loginSessionExpired;

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

  /// No description provided for @settingsLanguageSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索语言'**
  String get settingsLanguageSearch;

  /// No description provided for @settingsResetDefault.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get settingsResetDefault;

  /// No description provided for @settingsPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'隐私'**
  String get settingsPrivacy;

  /// No description provided for @settingsBilling.
  ///
  /// In zh, this message translates to:
  /// **'账单'**
  String get settingsBilling;

  /// No description provided for @settingsCapabilities.
  ///
  /// In zh, this message translates to:
  /// **'能力'**
  String get settingsCapabilities;

  /// No description provided for @settingsMemory.
  ///
  /// In zh, this message translates to:
  /// **'记忆'**
  String get settingsMemory;

  /// No description provided for @settingsReflect.
  ///
  /// In zh, this message translates to:
  /// **'反思'**
  String get settingsReflect;

  /// No description provided for @settingsTimeFocus.
  ///
  /// In zh, this message translates to:
  /// **'时间和专注'**
  String get settingsTimeFocus;

  /// No description provided for @settingsClaudeCode.
  ///
  /// In zh, this message translates to:
  /// **'Claude Code'**
  String get settingsClaudeCode;

  /// No description provided for @settingsCustomize.
  ///
  /// In zh, this message translates to:
  /// **'自定义'**
  String get settingsCustomize;

  /// No description provided for @settingsSkills.
  ///
  /// In zh, this message translates to:
  /// **'技能'**
  String get settingsSkills;

  /// No description provided for @settingsConnectors.
  ///
  /// In zh, this message translates to:
  /// **'连接器'**
  String get settingsConnectors;

  /// No description provided for @settingsPlugins.
  ///
  /// In zh, this message translates to:
  /// **'插件'**
  String get settingsPlugins;

  /// No description provided for @settingsSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get settingsSearch;

  /// No description provided for @settingsAppearance.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get settingsTheme;

  /// No description provided for @settingsChatFont.
  ///
  /// In zh, this message translates to:
  /// **'聊天字体'**
  String get settingsChatFont;

  /// No description provided for @settingsTranscriptWidth.
  ///
  /// In zh, this message translates to:
  /// **'转录宽度'**
  String get settingsTranscriptWidth;

  /// No description provided for @settingsTranscriptWidthDesc.
  ///
  /// In zh, this message translates to:
  /// **'转录与输入列的最大宽度。'**
  String get settingsTranscriptWidthDesc;

  /// No description provided for @settingsTranscriptNarrow.
  ///
  /// In zh, this message translates to:
  /// **'窄'**
  String get settingsTranscriptNarrow;

  /// No description provided for @settingsTranscriptMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get settingsTranscriptMedium;

  /// No description provided for @settingsTranscriptWide.
  ///
  /// In zh, this message translates to:
  /// **'宽'**
  String get settingsTranscriptWide;

  /// No description provided for @settingsMotion.
  ///
  /// In zh, this message translates to:
  /// **'动效'**
  String get settingsMotion;

  /// No description provided for @settingsMotionDesc.
  ///
  /// In zh, this message translates to:
  /// **'减少流式响应和其他界面元素的动画'**
  String get settingsMotionDesc;

  /// No description provided for @settingsMotionSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统'**
  String get settingsMotionSystem;

  /// No description provided for @settingsMotionReduced.
  ///
  /// In zh, this message translates to:
  /// **'减少'**
  String get settingsMotionReduced;

  /// No description provided for @settingsVoice.
  ///
  /// In zh, this message translates to:
  /// **'语音'**
  String get settingsVoice;

  /// No description provided for @settingsVoiceLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsVoiceLanguage;

  /// No description provided for @settingsVoiceStyle.
  ///
  /// In zh, this message translates to:
  /// **'风格'**
  String get settingsVoiceStyle;

  /// No description provided for @settingsVoiceSpeed.
  ///
  /// In zh, this message translates to:
  /// **'速度'**
  String get settingsVoiceSpeed;

  /// No description provided for @settingsNotifications.
  ///
  /// In zh, this message translates to:
  /// **'通知'**
  String get settingsNotifications;

  /// No description provided for @settingsNotifResponseComplete.
  ///
  /// In zh, this message translates to:
  /// **'响应完成'**
  String get settingsNotifResponseComplete;

  /// No description provided for @settingsNotifResponseCompleteDesc.
  ///
  /// In zh, this message translates to:
  /// **'当 Claude 完成响应时通知。对长时间运行的任务很有用。'**
  String get settingsNotifResponseCompleteDesc;

  /// No description provided for @settingsFontAnthropic.
  ///
  /// In zh, this message translates to:
  /// **'Anthropic Serif'**
  String get settingsFontAnthropic;

  /// No description provided for @settingsFontSystem.
  ///
  /// In zh, this message translates to:
  /// **'系统字体'**
  String get settingsFontSystem;

  /// No description provided for @settingsVoiceEnglish.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get settingsVoiceEnglish;

  /// No description provided for @settingsVoiceChinese.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get settingsVoiceChinese;

  /// No description provided for @settingsVoiceStyleButtery.
  ///
  /// In zh, this message translates to:
  /// **'Buttery'**
  String get settingsVoiceStyleButtery;

  /// No description provided for @settingsVoiceStyleNormal.
  ///
  /// In zh, this message translates to:
  /// **'Normal'**
  String get settingsVoiceStyleNormal;

  /// No description provided for @settingsVoiceSpeedNormal.
  ///
  /// In zh, this message translates to:
  /// **'Normal'**
  String get settingsVoiceSpeedNormal;

  /// No description provided for @settingsVoiceSpeedFast.
  ///
  /// In zh, this message translates to:
  /// **'Fast'**
  String get settingsVoiceSpeedFast;

  /// No description provided for @settingsComingSoon.
  ///
  /// In zh, this message translates to:
  /// **'即将推出'**
  String get settingsComingSoon;

  /// No description provided for @settingsComingSoonDesc.
  ///
  /// In zh, this message translates to:
  /// **'此功能正在开发中'**
  String get settingsComingSoonDesc;

  /// No description provided for @billingFreePlan.
  ///
  /// In zh, this message translates to:
  /// **'免费版'**
  String get billingFreePlan;

  /// No description provided for @billingTryClaude.
  ///
  /// In zh, this message translates to:
  /// **'试用 Claude'**
  String get billingTryClaude;

  /// No description provided for @billingUpgradePlan.
  ///
  /// In zh, this message translates to:
  /// **'升级方案'**
  String get billingUpgradePlan;

  /// No description provided for @billingFeatureChatPlatforms.
  ///
  /// In zh, this message translates to:
  /// **'在网页、iOS、Android 及桌面端进行对话'**
  String get billingFeatureChatPlatforms;

  /// No description provided for @billingFeatureGenerateCode.
  ///
  /// In zh, this message translates to:
  /// **'生成代码并可视化数据'**
  String get billingFeatureGenerateCode;

  /// No description provided for @billingFeatureWriteEdit.
  ///
  /// In zh, this message translates to:
  /// **'编写、编辑和创作内容'**
  String get billingFeatureWriteEdit;

  /// No description provided for @billingFeatureSearchWeb.
  ///
  /// In zh, this message translates to:
  /// **'支持网页搜索能力'**
  String get billingFeatureSearchWeb;

  /// No description provided for @billingFeatureMemory.
  ///
  /// In zh, this message translates to:
  /// **'跨对话的记忆能力'**
  String get billingFeatureMemory;

  /// No description provided for @billingFeatureCreateFiles.
  ///
  /// In zh, this message translates to:
  /// **'创建文件并执行代码'**
  String get billingFeatureCreateFiles;

  /// No description provided for @billingFeatureDesktopExtensions.
  ///
  /// In zh, this message translates to:
  /// **'通过桌面扩展解锁 Claude 的更多能力'**
  String get billingFeatureDesktopExtensions;

  /// No description provided for @billingFeatureConnectWorkspace.
  ///
  /// In zh, this message translates to:
  /// **'连接 Slack 和 Google Workspace 服务'**
  String get billingFeatureConnectWorkspace;

  /// No description provided for @billingFeatureConnectors.
  ///
  /// In zh, this message translates to:
  /// **'通过远程 MCP 连接器接入任意上下文或工具'**
  String get billingFeatureConnectors;

  /// No description provided for @billingFeatureExtendedThinking.
  ///
  /// In zh, this message translates to:
  /// **'为复杂任务提供扩展思考'**
  String get billingFeatureExtendedThinking;

  /// No description provided for @memoryTitle.
  ///
  /// In zh, this message translates to:
  /// **'记忆'**
  String get memoryTitle;

  /// No description provided for @memoryGenerateFromChats.
  ///
  /// In zh, this message translates to:
  /// **'从对话中生成记忆'**
  String get memoryGenerateFromChats;

  /// No description provided for @memoryGenerateFromChatsDesc.
  ///
  /// In zh, this message translates to:
  /// **'允许 Claude 根据您的对话生成记忆。{learnMore}'**
  String memoryGenerateFromChatsDesc(Object learnMore);

  /// No description provided for @memoryGenerateFromChatsLearnMore.
  ///
  /// In zh, this message translates to:
  /// **'了解更多。'**
  String get memoryGenerateFromChatsLearnMore;

  /// No description provided for @memoryLearnMore.
  ///
  /// In zh, this message translates to:
  /// **'了解更多。'**
  String get memoryLearnMore;

  /// No description provided for @memorySensitiveTopics.
  ///
  /// In zh, this message translates to:
  /// **'在记忆中包含敏感话题'**
  String get memorySensitiveTopics;

  /// No description provided for @memorySensitiveTopicsDesc.
  ///
  /// In zh, this message translates to:
  /// **'允许 Claude 将健康状况或宗教信仰等敏感话题的详情保存到记忆中。{learnMore}'**
  String memorySensitiveTopicsDesc(Object learnMore);

  /// No description provided for @memoryImportFromOtherAi.
  ///
  /// In zh, this message translates to:
  /// **'从其他 AI 服务商导入记忆'**
  String get memoryImportFromOtherAi;

  /// No description provided for @memoryImportFromOtherAiDesc.
  ///
  /// In zh, this message translates to:
  /// **'将其他 AI 服务商的相关上下文与数据带入 Claude。我们会提供一段提示词，供您从其他账号获取记忆。{learnMore}'**
  String memoryImportFromOtherAiDesc(Object learnMore);

  /// No description provided for @memoryStartImport.
  ///
  /// In zh, this message translates to:
  /// **'开始导入'**
  String get memoryStartImport;

  /// No description provided for @memoryNoFiles.
  ///
  /// In zh, this message translates to:
  /// **'暂无文件'**
  String get memoryNoFiles;

  /// No description provided for @memoryInputHint.
  ///
  /// In zh, this message translates to:
  /// **'例如：把清单控制在五项以内'**
  String get memoryInputHint;

  /// No description provided for @memoryDisableTitle.
  ///
  /// In zh, this message translates to:
  /// **'关闭记忆'**
  String get memoryDisableTitle;

  /// No description provided for @memoryPauseMemory.
  ///
  /// In zh, this message translates to:
  /// **'暂停记忆'**
  String get memoryPauseMemory;

  /// No description provided for @memoryPauseMemoryDesc.
  ///
  /// In zh, this message translates to:
  /// **'Claude 会保留现有记忆（包括敏感话题），但不会使用记忆，也不会生成新记忆。'**
  String get memoryPauseMemoryDesc;

  /// No description provided for @memoryResetMemory.
  ///
  /// In zh, this message translates to:
  /// **'重置记忆'**
  String get memoryResetMemory;

  /// No description provided for @memoryResetMemoryDesc.
  ///
  /// In zh, this message translates to:
  /// **'这将永久删除所有记忆（含项目记忆），并关闭敏感话题的保存。此操作无法撤销。'**
  String get memoryResetMemoryDesc;

  /// No description provided for @reflectTitle.
  ///
  /// In zh, this message translates to:
  /// **'反思'**
  String get reflectTitle;

  /// No description provided for @reflectDesc.
  ///
  /// In zh, this message translates to:
  /// **'基于您在 Claude 对话中的内容。'**
  String get reflectDesc;

  /// No description provided for @reflectEnableMemoryHintPrefix.
  ///
  /// In zh, this message translates to:
  /// **'要使用此反思功能，您需要先在'**
  String get reflectEnableMemoryHintPrefix;

  /// No description provided for @reflectMemorySettingsLink.
  ///
  /// In zh, this message translates to:
  /// **'记忆设置'**
  String get reflectMemorySettingsLink;

  /// No description provided for @reflectEnableMemoryHintSuffix.
  ///
  /// In zh, this message translates to:
  /// **'中启用记忆。'**
  String get reflectEnableMemoryHintSuffix;

  /// No description provided for @timeFocusTitle.
  ///
  /// In zh, this message translates to:
  /// **'时间和专注'**
  String get timeFocusTitle;

  /// No description provided for @timeFocusBreakReminders.
  ///
  /// In zh, this message translates to:
  /// **'休息提醒'**
  String get timeFocusBreakReminders;

  /// No description provided for @timeFocusBreakRemindersDesc.
  ///
  /// In zh, this message translates to:
  /// **'在使用 Claude 时提醒您休息一下。您可以随时暂停提醒或调整时间。'**
  String get timeFocusBreakRemindersDesc;

  /// No description provided for @timeFocusQuietHours.
  ///
  /// In zh, this message translates to:
  /// **'静默时段'**
  String get timeFocusQuietHours;

  /// No description provided for @timeFocusQuietHoursDesc.
  ///
  /// In zh, this message translates to:
  /// **'为 Claude 设置时间限制。您可以随时取消或调整。'**
  String get timeFocusQuietHoursDesc;

  /// No description provided for @commonDashPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'-'**
  String get commonDashPlaceholder;

  /// No description provided for @commonHoursValue.
  ///
  /// In zh, this message translates to:
  /// **'{n} 小时'**
  String commonHoursValue(int n);

  /// No description provided for @commonMinutesValue.
  ///
  /// In zh, this message translates to:
  /// **'{n} 分钟'**
  String commonMinutesValue(int n);

  /// No description provided for @commonSunday.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get commonSunday;

  /// No description provided for @commonMonday.
  ///
  /// In zh, this message translates to:
  /// **'一'**
  String get commonMonday;

  /// No description provided for @commonTuesday.
  ///
  /// In zh, this message translates to:
  /// **'二'**
  String get commonTuesday;

  /// No description provided for @commonWednesday.
  ///
  /// In zh, this message translates to:
  /// **'三'**
  String get commonWednesday;

  /// No description provided for @commonThursday.
  ///
  /// In zh, this message translates to:
  /// **'四'**
  String get commonThursday;

  /// No description provided for @commonFriday.
  ///
  /// In zh, this message translates to:
  /// **'五'**
  String get commonFriday;

  /// No description provided for @commonSaturday.
  ///
  /// In zh, this message translates to:
  /// **'六'**
  String get commonSaturday;

  /// No description provided for @timeFocusQuietHoursTo.
  ///
  /// In zh, this message translates to:
  /// **'至'**
  String get timeFocusQuietHoursTo;

  /// No description provided for @timeFocusQuietHoursNextDay.
  ///
  /// In zh, this message translates to:
  /// **'次日'**
  String get timeFocusQuietHoursNextDay;

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

  /// No description provided for @accountProfile.
  ///
  /// In zh, this message translates to:
  /// **'个人资料'**
  String get accountProfile;

  /// No description provided for @accountWorkDescription.
  ///
  /// In zh, this message translates to:
  /// **'您的工作类型？'**
  String get accountWorkDescription;

  /// No description provided for @accountWorkPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'选择您的角色'**
  String get accountWorkPlaceholder;

  /// No description provided for @accountWorkRoleProductManagement.
  ///
  /// In zh, this message translates to:
  /// **'产品管理'**
  String get accountWorkRoleProductManagement;

  /// No description provided for @accountWorkRoleEngineering.
  ///
  /// In zh, this message translates to:
  /// **'工程'**
  String get accountWorkRoleEngineering;

  /// No description provided for @accountWorkRoleHumanResources.
  ///
  /// In zh, this message translates to:
  /// **'人力资源'**
  String get accountWorkRoleHumanResources;

  /// No description provided for @accountWorkRoleDesign.
  ///
  /// In zh, this message translates to:
  /// **'设计'**
  String get accountWorkRoleDesign;

  /// No description provided for @accountWorkRoleSoftwareEngineering.
  ///
  /// In zh, this message translates to:
  /// **'软件工程'**
  String get accountWorkRoleSoftwareEngineering;

  /// No description provided for @accountWorkRoleStudent.
  ///
  /// In zh, this message translates to:
  /// **'学生'**
  String get accountWorkRoleStudent;

  /// No description provided for @accountWorkRoleOther.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get accountWorkRoleOther;

  /// No description provided for @accountInstructions.
  ///
  /// In zh, this message translates to:
  /// **'给 Claude 的指示'**
  String get accountInstructions;

  /// No description provided for @accountInstructionsDesc.
  ///
  /// In zh, this message translates to:
  /// **'Claude 将在 Anthropic 准则范围内，在此账户及关联账户的所有对话和协作中记住这些内容。'**
  String get accountInstructionsDesc;

  /// No description provided for @accountInstructionsPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'例如：在学习新概念时，我发现类比特别有帮助'**
  String get accountInstructionsPlaceholder;

  /// No description provided for @accountInstructionsLearnMore.
  ///
  /// In zh, this message translates to:
  /// **'了解更多'**
  String get accountInstructionsLearnMore;

  /// No description provided for @accountSectionTitle.
  ///
  /// In zh, this message translates to:
  /// **'账户'**
  String get accountSectionTitle;

  /// No description provided for @accountLogoutAll.
  ///
  /// In zh, this message translates to:
  /// **'退出所有设备'**
  String get accountLogoutAll;

  /// No description provided for @accountLogout.
  ///
  /// In zh, this message translates to:
  /// **'退出登录'**
  String get accountLogout;

  /// No description provided for @accountDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除您的账户'**
  String get accountDelete;

  /// No description provided for @accountDeleteButton.
  ///
  /// In zh, this message translates to:
  /// **'删除账户'**
  String get accountDeleteButton;

  /// No description provided for @accountOrgId.
  ///
  /// In zh, this message translates to:
  /// **'组织 ID'**
  String get accountOrgId;

  /// No description provided for @privacyTitle.
  ///
  /// In zh, this message translates to:
  /// **'隐私'**
  String get privacyTitle;

  /// No description provided for @privacyIntro.
  ///
  /// In zh, this message translates to:
  /// **'Anthropic 倡导透明的数据实践。了解使用 Anthropic 产品时如何保护您的信息，请访问我们的{privacyCenter}和{privacyPolicy}了解更多详情。'**
  String privacyIntro(Object privacyCenter, Object privacyPolicy);

  /// No description provided for @privacyCenter.
  ///
  /// In zh, this message translates to:
  /// **'隐私中心'**
  String get privacyCenter;

  /// No description provided for @privacyPolicy.
  ///
  /// In zh, this message translates to:
  /// **'隐私政策'**
  String get privacyPolicy;

  /// No description provided for @privacyProtectData.
  ///
  /// In zh, this message translates to:
  /// **'我们如何保护您的数据'**
  String get privacyProtectData;

  /// No description provided for @privacyUseData.
  ///
  /// In zh, this message translates to:
  /// **'我们如何使用您的数据'**
  String get privacyUseData;

  /// No description provided for @privacyPreferences.
  ///
  /// In zh, this message translates to:
  /// **'偏好设置'**
  String get privacyPreferences;

  /// No description provided for @privacyLocationMetadata.
  ///
  /// In zh, this message translates to:
  /// **'位置元数据'**
  String get privacyLocationMetadata;

  /// No description provided for @privacyLocationMetadataDesc.
  ///
  /// In zh, this message translates to:
  /// **'允许 Claude 使用粗略的位置元数据（城市/地区）来改进产品体验。{learnMore}'**
  String privacyLocationMetadataDesc(Object learnMore);

  /// No description provided for @privacyLocationMetadataLearnMore.
  ///
  /// In zh, this message translates to:
  /// **'了解更多。'**
  String get privacyLocationMetadataLearnMore;

  /// No description provided for @privacyImproveModels.
  ///
  /// In zh, this message translates to:
  /// **'帮助改进我们的 AI 模型'**
  String get privacyImproveModels;

  /// No description provided for @privacyImproveModelsDesc.
  ///
  /// In zh, this message translates to:
  /// **'允许使用您的对话和编程会话来训练和改进 Anthropic AI 模型。{learnMore}'**
  String privacyImproveModelsDesc(Object learnMore);

  /// No description provided for @privacyImproveModelsLearnMore.
  ///
  /// In zh, this message translates to:
  /// **'了解更多。'**
  String get privacyImproveModelsLearnMore;

  /// No description provided for @privacyYourData.
  ///
  /// In zh, this message translates to:
  /// **'您的数据'**
  String get privacyYourData;

  /// No description provided for @privacyExportData.
  ///
  /// In zh, this message translates to:
  /// **'导出数据'**
  String get privacyExportData;

  /// No description provided for @privacyExportDataButton.
  ///
  /// In zh, this message translates to:
  /// **'导出数据'**
  String get privacyExportDataButton;

  /// No description provided for @privacySharedChats.
  ///
  /// In zh, this message translates to:
  /// **'共享对话'**
  String get privacySharedChats;

  /// No description provided for @privacySharedArtifacts.
  ///
  /// In zh, this message translates to:
  /// **'共享产物'**
  String get privacySharedArtifacts;

  /// No description provided for @privacyUploadedFiles.
  ///
  /// In zh, this message translates to:
  /// **'上传的文件'**
  String get privacyUploadedFiles;

  /// No description provided for @privacyYourFeedback.
  ///
  /// In zh, this message translates to:
  /// **'您的反馈'**
  String get privacyYourFeedback;

  /// No description provided for @privacyManage.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get privacyManage;

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

  /// No description provided for @chatNoModelAvailable.
  ///
  /// In zh, this message translates to:
  /// **'没有可用模型，请先在中转站启用一个厂商与模型'**
  String get chatNoModelAvailable;

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

  /// No description provided for @chatLocalExecUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'本地引擎已启动，但命令类能力不可用（未找到 sgcode 可执行文件）—— 可以对话，但无法执行命令或改文件。装上 sgcode 或改用云端引擎。'**
  String get chatLocalExecUnavailable;

  /// No description provided for @chatOpeningThread.
  ///
  /// In zh, this message translates to:
  /// **'正在载入这条会话…'**
  String get chatOpeningThread;

  /// 对话流浮出按钮：直接滚到最新一条回答。
  ///
  /// In zh, this message translates to:
  /// **'回到最新'**
  String get chatJumpToLatest;

  /// No description provided for @chatThreadOpenFailed.
  ///
  /// In zh, this message translates to:
  /// **'打开会话失败：{reason}'**
  String chatThreadOpenFailed(String reason);

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

  /// No description provided for @artifactsTypeAll.
  ///
  /// In zh, this message translates to:
  /// **'全部类型'**
  String get artifactsTypeAll;

  /// No description provided for @artifactsTabAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get artifactsTabAll;

  /// No description provided for @artifactsTabYours.
  ///
  /// In zh, this message translates to:
  /// **'你的'**
  String get artifactsTabYours;

  /// No description provided for @artifactsTabShared.
  ///
  /// In zh, this message translates to:
  /// **'与你共享'**
  String get artifactsTabShared;

  /// No description provided for @artifactsViewGrid.
  ///
  /// In zh, this message translates to:
  /// **'网格视图'**
  String get artifactsViewGrid;

  /// No description provided for @artifactsViewList.
  ///
  /// In zh, this message translates to:
  /// **'列表视图'**
  String get artifactsViewList;

  /// No description provided for @artifactsMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get artifactsMoreActions;

  /// No description provided for @artifactsCopyLink.
  ///
  /// In zh, this message translates to:
  /// **'复制链接'**
  String get artifactsCopyLink;

  /// 产物卡片上的最后编辑时间。when 已按当前语言格式化
  ///
  /// In zh, this message translates to:
  /// **'编辑于 {when}'**
  String artifactsEdited(String when);

  /// No description provided for @projectsTitle.
  ///
  /// In zh, this message translates to:
  /// **'Projects'**
  String get projectsTitle;

  /// No description provided for @projectsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无项目'**
  String get projectsEmpty;

  /// No description provided for @projectsCreate.
  ///
  /// In zh, this message translates to:
  /// **'创建项目'**
  String get projectsCreate;

  /// No description provided for @projectsCreateDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'创建新项目'**
  String get projectsCreateDialogTitle;

  /// No description provided for @projectsCreateDialogName.
  ///
  /// In zh, this message translates to:
  /// **'项目名称'**
  String get projectsCreateDialogName;

  /// No description provided for @projectsCreateDialogNameHint.
  ///
  /// In zh, this message translates to:
  /// **'请输入项目名称'**
  String get projectsCreateDialogNameHint;

  /// No description provided for @projectsCreateDialogNameRequired.
  ///
  /// In zh, this message translates to:
  /// **'请输入项目名称'**
  String get projectsCreateDialogNameRequired;

  /// No description provided for @projectsCreateDialogDescription.
  ///
  /// In zh, this message translates to:
  /// **'你想实现什么目标？'**
  String get projectsCreateDialogDescription;

  /// No description provided for @projectsCreateDialogDescriptionHint.
  ///
  /// In zh, this message translates to:
  /// **'描述你的项目、目标、主题等...'**
  String get projectsCreateDialogDescriptionHint;

  /// No description provided for @projectsSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索项目...'**
  String get projectsSearchHint;

  /// No description provided for @projectsMoreActions.
  ///
  /// In zh, this message translates to:
  /// **'更多操作'**
  String get projectsMoreActions;

  /// No description provided for @projectsPin.
  ///
  /// In zh, this message translates to:
  /// **'置顶'**
  String get projectsPin;

  /// No description provided for @projectsEditDetails.
  ///
  /// In zh, this message translates to:
  /// **'编辑细节'**
  String get projectsEditDetails;

  /// No description provided for @projectsEditDialogTitle.
  ///
  /// In zh, this message translates to:
  /// **'编辑细节'**
  String get projectsEditDialogTitle;

  /// No description provided for @projectsEditDialogName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get projectsEditDialogName;

  /// No description provided for @projectsEditDialogDescription.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get projectsEditDialogDescription;

  /// No description provided for @projectsUpdatedJustNow.
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get projectsUpdatedJustNow;

  /// No description provided for @projectsUpdatedMinutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{n} 分钟前'**
  String projectsUpdatedMinutesAgo(int n);

  /// No description provided for @projectsUpdatedHoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{n} 小时前'**
  String projectsUpdatedHoursAgo(int n);

  /// No description provided for @projectsUpdatedDaysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{n} 天前'**
  String projectsUpdatedDaysAgo(int n);

  /// No description provided for @customizeTitle.
  ///
  /// In zh, this message translates to:
  /// **'Customize'**
  String get customizeTitle;

  /// No description provided for @customizeTabTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get customizeTabTheme;

  /// No description provided for @customizeTabLayout.
  ///
  /// In zh, this message translates to:
  /// **'布局'**
  String get customizeTabLayout;

  /// No description provided for @customizeTabShortcuts.
  ///
  /// In zh, this message translates to:
  /// **'快捷键'**
  String get customizeTabShortcuts;

  /// No description provided for @customizeTabConnectors.
  ///
  /// In zh, this message translates to:
  /// **'连接器'**
  String get customizeTabConnectors;

  /// No description provided for @customizeTabPlugins.
  ///
  /// In zh, this message translates to:
  /// **'插件'**
  String get customizeTabPlugins;

  /// No description provided for @customizeTabYours.
  ///
  /// In zh, this message translates to:
  /// **'你的'**
  String get customizeTabYours;

  /// No description provided for @customizeTabDiscover.
  ///
  /// In zh, this message translates to:
  /// **'发现'**
  String get customizeTabDiscover;

  /// No description provided for @customizeTabForYou.
  ///
  /// In zh, this message translates to:
  /// **'为你推荐'**
  String get customizeTabForYou;

  /// No description provided for @customizeTabNew.
  ///
  /// In zh, this message translates to:
  /// **'最新'**
  String get customizeTabNew;

  /// No description provided for @customizeSearchSkillsHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索技能…'**
  String get customizeSearchSkillsHint;

  /// No description provided for @customizeSearchPluginsHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索插件…'**
  String get customizeSearchPluginsHint;

  /// No description provided for @skillsYoursEmptyTitle.
  ///
  /// In zh, this message translates to:
  /// **'你还没有自建技能'**
  String get skillsYoursEmptyTitle;

  /// No description provided for @skillsYoursEmptyHint.
  ///
  /// In zh, this message translates to:
  /// **'母版下发的技能在 Discover 里'**
  String get skillsYoursEmptyHint;

  /// No description provided for @customizeSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索...'**
  String get customizeSearchHint;

  /// No description provided for @capabilitiesToolAccessMode.
  ///
  /// In zh, this message translates to:
  /// **'工具访问模式'**
  String get capabilitiesToolAccessMode;

  /// No description provided for @capabilitiesToolAccessModeDesc.
  ///
  /// In zh, this message translates to:
  /// **'控制连接器工具在新对话中的加载方式。'**
  String get capabilitiesToolAccessModeDesc;

  /// No description provided for @capabilitiesToolAccessLoadWhenNeeded.
  ///
  /// In zh, this message translates to:
  /// **'按需加载工具'**
  String get capabilitiesToolAccessLoadWhenNeeded;

  /// No description provided for @capabilitiesConnectorSearch.
  ///
  /// In zh, this message translates to:
  /// **'连接器搜索'**
  String get capabilitiesConnectorSearch;

  /// No description provided for @capabilitiesConnectorSearchDesc.
  ///
  /// In zh, this message translates to:
  /// **'允许 Claude 搜索连接器目录，并在对话中呈现相关的连接器。'**
  String get capabilitiesConnectorSearchDesc;

  /// No description provided for @capabilitiesSwitchModels.
  ///
  /// In zh, this message translates to:
  /// **'消息被标记时切换模型'**
  String get capabilitiesSwitchModels;

  /// No description provided for @capabilitiesSwitchModelsDesc.
  ///
  /// In zh, this message translates to:
  /// **'当安全机制标记某条消息时，自动切换到其他模型以继续对话。关闭后，对话将暂停。'**
  String get capabilitiesSwitchModelsDesc;

  /// No description provided for @capabilitiesVisuals.
  ///
  /// In zh, this message translates to:
  /// **'视觉内容'**
  String get capabilitiesVisuals;

  /// No description provided for @capabilitiesArtifacts.
  ///
  /// In zh, this message translates to:
  /// **'Artifacts'**
  String get capabilitiesArtifacts;

  /// No description provided for @capabilitiesArtifactsDesc.
  ///
  /// In zh, this message translates to:
  /// **'在对话旁的独立窗口中生成代码、文档和设计。'**
  String get capabilitiesArtifactsDesc;

  /// No description provided for @capabilitiesArtifactsLocked.
  ///
  /// In zh, this message translates to:
  /// **'始终开启，不可关闭。'**
  String get capabilitiesArtifactsLocked;

  /// No description provided for @capabilitiesAiArtifacts.
  ///
  /// In zh, this message translates to:
  /// **'AI 驱动的 Artifacts'**
  String get capabilitiesAiArtifacts;

  /// No description provided for @capabilitiesAiArtifactsDesc.
  ///
  /// In zh, this message translates to:
  /// **'构建在 artifact 内部调用 Claude 的应用与交互式文档。'**
  String get capabilitiesAiArtifactsDesc;

  /// No description provided for @capabilitiesInlineVisualizations.
  ///
  /// In zh, this message translates to:
  /// **'对话内可视化'**
  String get capabilitiesInlineVisualizations;

  /// No description provided for @capabilitiesInlineVisualizationsDesc.
  ///
  /// In zh, this message translates to:
  /// **'允许 Claude 直接在对话中生成交互式可视化、图表和图解。'**
  String get capabilitiesInlineVisualizationsDesc;

  /// No description provided for @capabilitiesCodeExecution.
  ///
  /// In zh, this message translates to:
  /// **'代码执行与文件创建'**
  String get capabilitiesCodeExecution;

  /// No description provided for @capabilitiesCodeExecutionDesc.
  ///
  /// In zh, this message translates to:
  /// **'Claude 可以执行代码，并创建和编辑文档、表格、演示文稿、PDF 和数据报告。技能功能依赖此项。'**
  String get capabilitiesCodeExecutionDesc;

  /// No description provided for @capabilitiesNetworkEgress.
  ///
  /// In zh, this message translates to:
  /// **'允许网络出站'**
  String get capabilitiesNetworkEgress;

  /// No description provided for @capabilitiesNetworkEgressDesc.
  ///
  /// In zh, this message translates to:
  /// **'允许 Claude 访问常用包管理器，以安装用于数据分析、可视化和文件处理的包与库。{viewDomains}。请密切监控对话，因为这会带来{securityRisks}。'**
  String capabilitiesNetworkEgressDesc(
    String viewDomains,
    String securityRisks,
  );

  /// No description provided for @capabilitiesNetworkEgressViewDomains.
  ///
  /// In zh, this message translates to:
  /// **'查看包管理器域名'**
  String get capabilitiesNetworkEgressViewDomains;

  /// No description provided for @capabilitiesNetworkEgressSecurityRisks.
  ///
  /// In zh, this message translates to:
  /// **'安全风险'**
  String get capabilitiesNetworkEgressSecurityRisks;

  /// No description provided for @capabilitiesSkills.
  ///
  /// In zh, this message translates to:
  /// **'技能'**
  String get capabilitiesSkills;

  /// No description provided for @capabilitiesSkillsMoved.
  ///
  /// In zh, this message translates to:
  /// **'技能已移至「{customize}」。'**
  String capabilitiesSkillsMoved(String customize);

  /// No description provided for @searchSectionRecents.
  ///
  /// In zh, this message translates to:
  /// **'最近'**
  String get searchSectionRecents;

  /// No description provided for @searchSectionActions.
  ///
  /// In zh, this message translates to:
  /// **'操作'**
  String get searchSectionActions;

  /// No description provided for @searchTabAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get searchTabAll;

  /// No description provided for @searchTabArtifacts.
  ///
  /// In zh, this message translates to:
  /// **'输出物'**
  String get searchTabArtifacts;

  /// No description provided for @searchTabChats.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get searchTabChats;

  /// No description provided for @searchTabProjects.
  ///
  /// In zh, this message translates to:
  /// **'项目'**
  String get searchTabProjects;

  /// No description provided for @searchTabSessions.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get searchTabSessions;

  /// No description provided for @searchTabTasks.
  ///
  /// In zh, this message translates to:
  /// **'任务'**
  String get searchTabTasks;

  /// No description provided for @searchTabScheduled.
  ///
  /// In zh, this message translates to:
  /// **'定时'**
  String get searchTabScheduled;

  /// No description provided for @searchNoResultsIn.
  ///
  /// In zh, this message translates to:
  /// **'{type} 中没有结果'**
  String searchNoResultsIn(String type);

  /// No description provided for @searchSearchAll.
  ///
  /// In zh, this message translates to:
  /// **'搜索全部'**
  String get searchSearchAll;

  /// No description provided for @searchNewChat.
  ///
  /// In zh, this message translates to:
  /// **'新建对话'**
  String get searchNewChat;

  /// No description provided for @searchTimeToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get searchTimeToday;

  /// No description provided for @searchTimePastWeek.
  ///
  /// In zh, this message translates to:
  /// **'过去一周'**
  String get searchTimePastWeek;

  /// No description provided for @searchTimePastMonth.
  ///
  /// In zh, this message translates to:
  /// **'过去一月'**
  String get searchTimePastMonth;

  /// No description provided for @searchTimePastYear.
  ///
  /// In zh, this message translates to:
  /// **'过去一年'**
  String get searchTimePastYear;

  /// No description provided for @searchTimeOlder.
  ///
  /// In zh, this message translates to:
  /// **'更早'**
  String get searchTimeOlder;

  /// No description provided for @searchFooterClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get searchFooterClose;

  /// No description provided for @searchFooterChangeType.
  ///
  /// In zh, this message translates to:
  /// **'切换分类'**
  String get searchFooterChangeType;

  /// No description provided for @searchFooterFilters.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get searchFooterFilters;

  /// No description provided for @searchFooterActions.
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get searchFooterActions;

  /// No description provided for @searchFooterCompose.
  ///
  /// In zh, this message translates to:
  /// **'输入'**
  String get searchFooterCompose;

  /// No description provided for @searchFiltersTitle.
  ///
  /// In zh, this message translates to:
  /// **'筛选分类'**
  String get searchFiltersTitle;

  /// No description provided for @searchOpen.
  ///
  /// In zh, this message translates to:
  /// **'打开'**
  String get searchOpen;

  /// No description provided for @searchFilterBy.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get searchFilterBy;

  /// No description provided for @searchFilterOwner.
  ///
  /// In zh, this message translates to:
  /// **'所有者'**
  String get searchFilterOwner;

  /// No description provided for @searchFilterDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get searchFilterDate;

  /// No description provided for @searchFilterType.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get searchFilterType;

  /// No description provided for @searchFilterArchived.
  ///
  /// In zh, this message translates to:
  /// **'已归档'**
  String get searchFilterArchived;

  /// No description provided for @searchFilterActions.
  ///
  /// In zh, this message translates to:
  /// **'操作'**
  String get searchFilterActions;

  /// No description provided for @searchOwnerMe.
  ///
  /// In zh, this message translates to:
  /// **'我'**
  String get searchOwnerMe;

  /// No description provided for @searchOwnerShared.
  ///
  /// In zh, this message translates to:
  /// **'与我共享'**
  String get searchOwnerShared;

  /// No description provided for @searchActionsHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索操作'**
  String get searchActionsHint;
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
