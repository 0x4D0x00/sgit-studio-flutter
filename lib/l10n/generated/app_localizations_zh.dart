// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get navSearch => '搜索';

  @override
  String get navSearchDialogHint => '搜索聊天';

  @override
  String get navSearchDialogEmpty => '未找到匹配的会话';

  @override
  String get navNewChat => '新建对话';

  @override
  String get navNew => '新建';

  @override
  String get navProjects => 'Projects';

  @override
  String get navCustomize => 'Customize';

  @override
  String get navHistory => '历史对话';

  @override
  String get navChatPin => '置顶';

  @override
  String get navChatRename => '重命名';

  @override
  String get navViewAll => '查看全部';

  @override
  String get navSelect => '选择';

  @override
  String get navSelectAll => '全选';

  @override
  String get navDeselectAll => '取消全选';

  @override
  String navSelectedCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String get commonClose => '关闭';

  @override
  String get navAssistants => '助理';

  @override
  String get assistantPentest => '渗透助理';

  @override
  String get assistantDefense => '防护助理';

  @override
  String get assistantContest => '竞赛助理';

  @override
  String get assistantOffice => '办公助理';

  @override
  String get assistantSwitcher => '切换助理';

  @override
  String get navStudioGroup => '智能体';

  @override
  String get navGetHelp => '寻求帮助';

  @override
  String get navLearnMore => '了解更多';

  @override
  String navAboutBrand(String brand) {
    return '关于 $brand';
  }

  @override
  String get navUsagePolicy => '使用政策';

  @override
  String get navPrivacyPolicy => '隐私政策';

  @override
  String get navTermsOfService => '服务条款';

  @override
  String get navPrivacyChoices => '您的隐私设置';

  @override
  String get navKeyboardShortcuts => '键盘快捷键';

  @override
  String get navSettings => '设置';

  @override
  String get navLogout => '退出登录';

  @override
  String get chatGroupBy => '分组方式';

  @override
  String get chatSortBy => '排序方式';

  @override
  String get chatGroupNone => '无';

  @override
  String get chatGroupDate => '日期';

  @override
  String get chatGroupAssistant => '助理';

  @override
  String get chatSortName => '名称';

  @override
  String get chatSortLastActivity => '最近活动';

  @override
  String get chatGroupToday => '今天';

  @override
  String get chatGroupYesterday => '昨天';

  @override
  String get chatGroupOlder => '之前';

  @override
  String get chatGroupUnknown => '时间未知';

  @override
  String get chatRenameHint => '保持简短且易于识别。';

  @override
  String get chatHistoryEmptyAction => '开启新对话';

  @override
  String get shellExpandNav => '展开导航';

  @override
  String get shellCollapseNav => '收起导航';

  @override
  String get shellToggleOutput => '输出物面板';

  @override
  String get shellOutputTitle => '输出物';

  @override
  String get shellOutputEmpty => '暂无产物';

  @override
  String workspaceWelcome(String name) {
    return '$name，为你待命';
  }

  @override
  String get workspaceInputHint => '有什么可以帮你的？';

  @override
  String get workspaceSend => '发送';

  @override
  String get studioAccessDenied => '无权访问该功能';

  @override
  String get studioScenes => '场景';

  @override
  String get studioSubagent => '子 Agent';

  @override
  String get studioSkill => '技能';

  @override
  String get studioMcp => 'MCP';

  @override
  String get studioTools => '工具';

  @override
  String get studioMemory => '记忆';

  @override
  String get studioKnowledge => '知识库';

  @override
  String get studioLlmRelay => '大模型中转站';

  @override
  String get studioApiKey => 'API 密钥';

  @override
  String get chatFaultNotConnected => '尚未连接到内核，无法发送';

  @override
  String get chatReconnect => '重连';

  @override
  String get chatAddMenu => '更多选项';

  @override
  String get chatAttachFiles => '添加文件/图片';

  @override
  String get chatWebSearch => '联网搜索';

  @override
  String get chatAgentGateway => 'Agent Gateway';

  @override
  String get chatStop => '停止';

  @override
  String get chatSteerHint => '插话改方向…';

  @override
  String get chatPickFile => '选择文件';

  @override
  String get chatPickImage => '选择图片';

  @override
  String chatPickFileFailed(String reason) {
    return '选择文件失败：$reason';
  }

  @override
  String get chatRemoveAttachment => '移除附件';

  @override
  String get chatReply => '回复';

  @override
  String get chatQuoteTitle => '引用';

  @override
  String get chatRemoveQuote => '移除引用';

  @override
  String get chatClearScene => '退出场景';

  @override
  String get chatMemory => '记忆';

  @override
  String get chatSkills => '技能';

  @override
  String get chatKnowledge => '知识库';

  @override
  String get chatContextWindow => '上下文窗口';

  @override
  String chatContextWindowDetail(int used, int total) {
    return '已用 $used / 共 $total tokens';
  }

  @override
  String get chatApprovalPolicy => '审批策略';

  @override
  String get chatApprovalUntrusted => '仅信任只读';

  @override
  String get chatApprovalUntrustedDesc => '只自动批准已知安全的只读命令，其余都问你';

  @override
  String get chatApprovalOnRequest => '由模型决定';

  @override
  String get chatApprovalOnRequestDesc => '模型自行判断何时需要你批准（引擎默认）';

  @override
  String get chatApprovalNever => '从不询问';

  @override
  String get chatApprovalNeverDesc => '从不打断你，失败直接返回给模型';

  @override
  String get chatApprovalGranular => '细粒度';

  @override
  String get chatApprovalGranularDesc => '逐类控制哪些操作需要审批';

  @override
  String get chatApprovalFieldSandbox => 'Shell 命令';

  @override
  String get chatApprovalFieldRules => '规则变更';

  @override
  String get chatApprovalFieldSkill => '技能调用';

  @override
  String get chatApprovalFieldPermissions => '权限申请';

  @override
  String get chatApprovalFieldMcp => 'MCP 请求';

  @override
  String get chatSandboxMode => '沙箱';

  @override
  String get chatSandboxReadOnly => '只读';

  @override
  String get chatSandboxReadOnlyDesc => '只能读，不能改动任何文件（引擎默认）';

  @override
  String get chatSandboxWorkspaceWrite => '可写工作区';

  @override
  String get chatSandboxWorkspaceWriteDesc => '可以改动工作目录内的文件';

  @override
  String get chatSandboxDangerFullAccess => '完全放开';

  @override
  String get chatSandboxDangerFullAccessDesc => '不做任何限制。仅在你清楚风险时使用';

  @override
  String get chatReasoningEffort => '推理强度';

  @override
  String get chatEffortNone => '关闭';

  @override
  String get chatEffortMinimal => '极低';

  @override
  String get chatEffortLow => '低';

  @override
  String get chatEffortMedium => '中';

  @override
  String get chatEffortHigh => '高';

  @override
  String get chatEffortXhigh => '很高';

  @override
  String get chatEffortMax => '最高';

  @override
  String get chatEffortUltra => '极限';

  @override
  String chatSettingWriteFailed(String reason) {
    return '设置未保存：$reason';
  }

  @override
  String get chatTextTruncated => '内容可能不完整';

  @override
  String get chatCopy => '复制';

  @override
  String get chatCopied => '已复制';

  @override
  String get chatCopiedAll => '已复制整段会话';

  @override
  String get chatArtifactOpen => '在右侧打开';

  @override
  String get chatArtifactDownload => '下载';

  @override
  String get chatArtifactClose => '关闭';

  @override
  String get chatArtifactDownloading => '正在保存…';

  @override
  String get chatArtifactSaved => '已保存';

  @override
  String get chatArtifactSaveFailed => '保存失败';

  @override
  String get chatArtifactExpand => '全屏查看';

  @override
  String get chatArtifactCollapse => '退出全屏';

  @override
  String get chatArtifactPanelTitle => '产物';

  @override
  String get chatArtifactPanelEmpty => '本次会话还没有产物';

  @override
  String get chatArtifactUnavailable => '这份内容无法以图形方式渲染，已按原文显示';

  @override
  String get chatEdit => '编辑';

  @override
  String get chatEditRegenerateHint => '保存后将丢弃此消息之后的内容，并用编辑后的内容重新开始本次会话';

  @override
  String get chatRetry => '重新生成';

  @override
  String get chatReadAloud => '朗读';

  @override
  String get chatThumbUp => '赞';

  @override
  String get chatThumbDown => '踩';

  @override
  String get chatApprovalTitle => '需要你确认';

  @override
  String get chatApprovalAllowOnce => '允许一次';

  @override
  String get chatApprovalAllowAlways => '总是允许';

  @override
  String get chatApprovalDeny => '拒绝';

  @override
  String get chatApprovalResolvedAllow => '已允许';

  @override
  String get chatApprovalResolvedAlways => '已设为总是允许';

  @override
  String get chatApprovalResolvedDeny => '已拒绝';

  @override
  String get chatEngineMode => '引擎模式';

  @override
  String get chatEngineModeLocal => '本地引擎';

  @override
  String get chatEngineModeRemote => '云端引擎';

  @override
  String get chatToolRunning => '执行中…';

  @override
  String get chatToolTruncated => '输出已截断，完整内容需展开获取';

  @override
  String get chatThinking1 => '正在思考…';

  @override
  String get chatThinking2 => '正在梳理…';

  @override
  String get chatThinking3 => '正在推敲…';

  @override
  String get chatThinking4 => '正在核对…';

  @override
  String get chatThinking5 => '正在落笔…';

  @override
  String get chatNoticeCompacted => '上下文已压缩';

  @override
  String get chatNoticeDisconnected => '连接已断开';

  @override
  String get chatNoticeUnknown => '未知提示';

  @override
  String chatToolElapsed(int ms) {
    return '$ms ms';
  }

  @override
  String chatNoticeModelRerouted(String to) {
    return '模型已改道：$to';
  }

  @override
  String chatNoticeDropped(int count) {
    return '有 $count 条增量被合并（内容可能不完整）';
  }

  @override
  String chatFaultVersionMismatch(int kernel, int client) {
    return '内核帧格式版本 $kernel 与客户端 $client 不匹配，请升级客户端';
  }

  @override
  String chatStats(int input, int output, int ms) {
    return '输入 $input · 输出 $output · 耗时 $ms ms';
  }

  @override
  String get studioEmpty => '暂无内容';

  @override
  String get studioRefresh => '刷新';

  @override
  String get studioUnsyncedHint => '本地已修改，尚未同步到服务器';

  @override
  String get studioSyncNow => '同步到服务器';

  @override
  String get studioSyncDone => '已同步';

  @override
  String studioSyncConflicts(int count) {
    return '已同步，$count 项有冲突：服务器版本已生效，你的改动存为 .conflict 备份';
  }

  @override
  String get studioRemove => '删除';

  @override
  String studioRemoveConfirm(String name) {
    return '确定删除「$name」？';
  }

  @override
  String studioRemoveConfirmMany(int count) {
    return '确定删除选中的 $count 项？';
  }

  @override
  String get studioStale => '显示的是缓存，正在刷新…';

  @override
  String get studioComingSoon => '该页数据源待接';

  @override
  String get relayProviders => '厂商';

  @override
  String get relayModels => '模型';

  @override
  String get relayKeys => '密钥';

  @override
  String get relayDisabled => '已停用';

  @override
  String get relayCustom => '自建';

  @override
  String get relayPlatform => '平台';

  @override
  String get relayPlatformReadonly => '平台开放的厂商/模型，个人页只读';

  @override
  String get relayBack => '返回';

  @override
  String get relayKeyMasked => '密钥仅显示后 6 位';

  @override
  String relayContextWindow(int n) {
    return '上下文 $n';
  }

  @override
  String get relayToggleOn => '点击启用';

  @override
  String get relayToggleOff => '点击停用';

  @override
  String get relaySync => '同步模型';

  @override
  String get relayNoProvider => '尚未配置任何厂商';

  @override
  String get modelSelector => '选择模型';

  @override
  String get modelSelectorNone => '暂无可用模型';

  @override
  String get navNewChatDone => '已开始新对话';

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
  String get loginSessionExpired => '登录已过期，请重新登录';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsAccount => '账户';

  @override
  String get settingsThemeMode => '主题模式';

  @override
  String get settingsThemeTransparent => '透明';

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
  String get settingsLanguageZh => '简体中文';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsLanguageSearch => '搜索语言';

  @override
  String get settingsResetDefault => '恢复默认';

  @override
  String get settingsPrivacy => '隐私';

  @override
  String get settingsBilling => '账单';

  @override
  String get settingsCapabilities => '能力';

  @override
  String get settingsMemory => '记忆';

  @override
  String get settingsReflect => '反思';

  @override
  String get settingsTimeFocus => '时间和专注';

  @override
  String get settingsClaudeCode => 'Claude Code';

  @override
  String get settingsCustomize => '自定义';

  @override
  String get settingsSkills => '技能';

  @override
  String get settingsConnectors => '连接器';

  @override
  String get settingsPlugins => '插件';

  @override
  String get settingsSearch => '搜索';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsChatFont => '聊天字体';

  @override
  String get settingsTranscriptWidth => '转录宽度';

  @override
  String get settingsTranscriptWidthDesc => '转录与输入列的最大宽度。';

  @override
  String get settingsTranscriptNarrow => '窄';

  @override
  String get settingsTranscriptMedium => '中';

  @override
  String get settingsTranscriptWide => '宽';

  @override
  String get settingsMotion => '动效';

  @override
  String get settingsMotionDesc => '减少流式响应和其他界面元素的动画';

  @override
  String get settingsMotionSystem => '系统';

  @override
  String get settingsMotionReduced => '减少';

  @override
  String get settingsVoice => '语音';

  @override
  String get settingsVoiceLanguage => '语言';

  @override
  String get settingsVoiceStyle => '风格';

  @override
  String get settingsVoiceSpeed => '速度';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsNotifResponseComplete => '响应完成';

  @override
  String get settingsNotifResponseCompleteDesc =>
      '当 Claude 完成响应时通知。对长时间运行的任务很有用。';

  @override
  String get settingsFontAnthropic => 'Anthropic Serif';

  @override
  String get settingsFontSystem => '系统字体';

  @override
  String get settingsVoiceEnglish => 'English';

  @override
  String get settingsVoiceChinese => '中文';

  @override
  String get settingsVoiceStyleButtery => 'Buttery';

  @override
  String get settingsVoiceStyleNormal => 'Normal';

  @override
  String get settingsVoiceSpeedNormal => 'Normal';

  @override
  String get settingsVoiceSpeedFast => 'Fast';

  @override
  String get settingsComingSoon => '即将推出';

  @override
  String get settingsComingSoonDesc => '此功能正在开发中';

  @override
  String get billingFreePlan => '免费版';

  @override
  String get billingTryClaude => '试用 Claude';

  @override
  String get billingUpgradePlan => '升级方案';

  @override
  String get billingFeatureChatPlatforms => '在网页、iOS、Android 及桌面端进行对话';

  @override
  String get billingFeatureGenerateCode => '生成代码并可视化数据';

  @override
  String get billingFeatureWriteEdit => '编写、编辑和创作内容';

  @override
  String get billingFeatureSearchWeb => '支持网页搜索能力';

  @override
  String get billingFeatureMemory => '跨对话的记忆能力';

  @override
  String get billingFeatureCreateFiles => '创建文件并执行代码';

  @override
  String get billingFeatureDesktopExtensions => '通过桌面扩展解锁 Claude 的更多能力';

  @override
  String get billingFeatureConnectWorkspace => '连接 Slack 和 Google Workspace 服务';

  @override
  String get billingFeatureConnectors => '通过远程 MCP 连接器接入任意上下文或工具';

  @override
  String get billingFeatureExtendedThinking => '为复杂任务提供扩展思考';

  @override
  String get memoryTitle => '记忆';

  @override
  String get memoryGenerateFromChats => '从对话中生成记忆';

  @override
  String memoryGenerateFromChatsDesc(Object learnMore) {
    return '允许 Claude 根据您的对话生成记忆。$learnMore';
  }

  @override
  String get memoryGenerateFromChatsLearnMore => '了解更多。';

  @override
  String get memoryLearnMore => '了解更多。';

  @override
  String get memorySensitiveTopics => '在记忆中包含敏感话题';

  @override
  String memorySensitiveTopicsDesc(Object learnMore) {
    return '允许 Claude 将健康状况或宗教信仰等敏感话题的详情保存到记忆中。$learnMore';
  }

  @override
  String get memoryImportFromOtherAi => '从其他 AI 服务商导入记忆';

  @override
  String memoryImportFromOtherAiDesc(Object learnMore) {
    return '将其他 AI 服务商的相关上下文与数据带入 Claude。我们会提供一段提示词，供您从其他账号获取记忆。$learnMore';
  }

  @override
  String get memoryStartImport => '开始导入';

  @override
  String get memoryNoFiles => '暂无文件';

  @override
  String get memoryInputHint => '例如：把清单控制在五项以内';

  @override
  String get memoryDisableTitle => '关闭记忆';

  @override
  String get memoryPauseMemory => '暂停记忆';

  @override
  String get memoryPauseMemoryDesc =>
      'Claude 会保留现有记忆（包括敏感话题），但不会使用记忆，也不会生成新记忆。';

  @override
  String get memoryResetMemory => '重置记忆';

  @override
  String get memoryResetMemoryDesc => '这将永久删除所有记忆（含项目记忆），并关闭敏感话题的保存。此操作无法撤销。';

  @override
  String get reflectTitle => '反思';

  @override
  String get reflectDesc => '基于您在 Claude 对话中的内容。';

  @override
  String get reflectEnableMemoryHintPrefix => '要使用此反思功能，您需要先在';

  @override
  String get reflectMemorySettingsLink => '记忆设置';

  @override
  String get reflectEnableMemoryHintSuffix => '中启用记忆。';

  @override
  String get timeFocusTitle => '时间和专注';

  @override
  String get timeFocusBreakReminders => '休息提醒';

  @override
  String get timeFocusBreakRemindersDesc =>
      '在使用 Claude 时提醒您休息一下。您可以随时暂停提醒或调整时间。';

  @override
  String get timeFocusQuietHours => '静默时段';

  @override
  String get timeFocusQuietHoursDesc => '为 Claude 设置时间限制。您可以随时取消或调整。';

  @override
  String get commonDashPlaceholder => '-';

  @override
  String commonHoursValue(int n) {
    return '$n 小时';
  }

  @override
  String commonMinutesValue(int n) {
    return '$n 分钟';
  }

  @override
  String get commonSunday => '日';

  @override
  String get commonMonday => '一';

  @override
  String get commonTuesday => '二';

  @override
  String get commonWednesday => '三';

  @override
  String get commonThursday => '四';

  @override
  String get commonFriday => '五';

  @override
  String get commonSaturday => '六';

  @override
  String get timeFocusQuietHoursTo => '至';

  @override
  String get timeFocusQuietHoursNextDay => '次日';

  @override
  String get accountAvatar => '头像';

  @override
  String get accountUsername => '用户名';

  @override
  String get accountPassword => '密码';

  @override
  String get accountChangeAvatar => '修改头像';

  @override
  String get accountChangePassword => '修改密码';

  @override
  String get accountCurrentPassword => '当前密码';

  @override
  String get accountNewPassword => '新密码';

  @override
  String get accountConfirmPassword => '确认密码';

  @override
  String get accountUsernamePlaceholder => '请输入用户名';

  @override
  String get accountCurrentPasswordPlaceholder => '请输入当前密码';

  @override
  String get accountNewPasswordPlaceholder => '请输入新密码';

  @override
  String get accountConfirmPasswordPlaceholder => '请再次输入新密码';

  @override
  String get accountPasswordMismatch => '两次输入的密码不一致';

  @override
  String get accountPasswordTooShort => '密码长度至少为6位';

  @override
  String get accountUpdateSuccess => '更新成功';

  @override
  String get accountUpdateFailed => '更新失败';

  @override
  String get accountAvatarTooLarge => '图片过大，请选择小于 5MB 的图片';

  @override
  String get accountProfile => '个人资料';

  @override
  String get accountWorkDescription => '您的工作类型？';

  @override
  String get accountWorkPlaceholder => '选择您的角色';

  @override
  String get accountWorkRoleProductManagement => '产品管理';

  @override
  String get accountWorkRoleEngineering => '工程';

  @override
  String get accountWorkRoleHumanResources => '人力资源';

  @override
  String get accountWorkRoleDesign => '设计';

  @override
  String get accountWorkRoleSoftwareEngineering => '软件工程';

  @override
  String get accountWorkRoleStudent => '学生';

  @override
  String get accountWorkRoleOther => '其他';

  @override
  String get accountInstructions => '给 Claude 的指示';

  @override
  String get accountInstructionsDesc =>
      'Claude 将在 Anthropic 准则范围内，在此账户及关联账户的所有对话和协作中记住这些内容。';

  @override
  String get accountInstructionsPlaceholder => '例如：在学习新概念时，我发现类比特别有帮助';

  @override
  String get accountInstructionsLearnMore => '了解更多';

  @override
  String get accountSectionTitle => '账户';

  @override
  String get accountLogoutAll => '退出所有设备';

  @override
  String get accountLogout => '退出登录';

  @override
  String get accountDelete => '删除您的账户';

  @override
  String get accountDeleteButton => '删除账户';

  @override
  String get accountOrgId => '组织 ID';

  @override
  String get privacyTitle => '隐私';

  @override
  String privacyIntro(Object privacyCenter, Object privacyPolicy) {
    return 'Anthropic 倡导透明的数据实践。了解使用 Anthropic 产品时如何保护您的信息，请访问我们的$privacyCenter和$privacyPolicy了解更多详情。';
  }

  @override
  String get privacyCenter => '隐私中心';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get privacyProtectData => '我们如何保护您的数据';

  @override
  String get privacyUseData => '我们如何使用您的数据';

  @override
  String get privacyPreferences => '偏好设置';

  @override
  String get privacyLocationMetadata => '位置元数据';

  @override
  String privacyLocationMetadataDesc(Object learnMore) {
    return '允许 Claude 使用粗略的位置元数据（城市/地区）来改进产品体验。$learnMore';
  }

  @override
  String get privacyLocationMetadataLearnMore => '了解更多。';

  @override
  String get privacyImproveModels => '帮助改进我们的 AI 模型';

  @override
  String privacyImproveModelsDesc(Object learnMore) {
    return '允许使用您的对话和编程会话来训练和改进 Anthropic AI 模型。$learnMore';
  }

  @override
  String get privacyImproveModelsLearnMore => '了解更多。';

  @override
  String get privacyYourData => '您的数据';

  @override
  String get privacyExportData => '导出数据';

  @override
  String get privacyExportDataButton => '导出数据';

  @override
  String get privacySharedChats => '共享对话';

  @override
  String get privacySharedArtifacts => '共享产物';

  @override
  String get privacyUploadedFiles => '上传的文件';

  @override
  String get privacyYourFeedback => '您的反馈';

  @override
  String get privacyManage => '管理';

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

  @override
  String commonNotWired(String what) {
    return '$what：功能待接';
  }

  @override
  String get studioScopePersonal => '个人';

  @override
  String get studioScopeMaster => '管理';

  @override
  String get studioScopeMasterHint => '管理版：改动对所有用户生效';

  @override
  String get relayAddProvider => '添加厂商';

  @override
  String get relayEditProvider => '编辑厂商';

  @override
  String get relayDeleteProvider => '删除厂商';

  @override
  String get relayDeleteProviderHint => '厂商下若仍有模型或密钥将无法删除，需先在其模型页清空。';

  @override
  String get relayAddModel => '手动添加模型';

  @override
  String get relayEditModel => '编辑模型';

  @override
  String get relayDeleteModel => '删除模型';

  @override
  String get relayKeyPool => '密钥池';

  @override
  String relayKeyPoolTitle(String code) {
    return 'API Key 密钥池 · $code（该品牌下所有模型共用）';
  }

  @override
  String relaySyncConfirmMaster(String code) {
    return '从 $code 厂商接口同步最新模型列表？';
  }

  @override
  String relaySyncConfirmPersonal(String code) {
    return '直连 $code 的接口拉取模型列表？需先填好 Base URL 并添加密钥。';
  }

  @override
  String relayScopeHintMaster(int n) {
    return '共 $n 个模型 · 保存/同步后自动对所有用户生效';
  }

  @override
  String relayScopeHintPersonal(int n) {
    return '共 $n 个模型 · 仅本人可见 · 对话时由 sgcode 直连厂商，不经平台后端';
  }

  @override
  String get relayLocalBadge => '个人（本地）';

  @override
  String get relayAddKey => '新增';

  @override
  String get relayKeyNameHint => '密钥备注名（可选）';

  @override
  String get relayKeyPasteHint => '粘贴 API Key';

  @override
  String get relayNoKeys => '暂无密钥';

  @override
  String get relayNoProviders => '暂无厂商，点右上角「添加厂商」新建。';

  @override
  String get relayFieldModelCode => '品牌代码';

  @override
  String get relayFieldProvider => '厂商标签';

  @override
  String get relayFieldDisplayName => '显示名';

  @override
  String get relayFieldBaseUrl => 'Base URL';

  @override
  String get relayFieldEndpoint => '聊天端点';

  @override
  String get relayFieldModelsEndpoint => '模型列表端点';

  @override
  String get relayFieldUploadBaseUrl => '上传 Base URL';

  @override
  String get relayFieldModelType => '类型';

  @override
  String get relayFieldPriority => '优先级';

  @override
  String get relayFieldModelName => '模型名';

  @override
  String get relayFieldContextWindow => '上下文窗口';

  @override
  String get relayFieldMaxOutput => '最大输出';

  @override
  String get relayFieldAvailable => '可用';

  @override
  String get relayRequiredModelCode => '品牌代码必填（唯一，如 DeepSeek）';

  @override
  String get relayRequiredModelName => '模型代码和模型名必填';

  @override
  String get relayRequiredApiKey => '请输入 API Key';

  @override
  String get commonDelete => '删除';

  @override
  String get commonEdit => '编辑';

  @override
  String get commonAdd => '新增';

  @override
  String get commonConfirm => '确定';

  @override
  String get commonSaved => '已保存';

  @override
  String get commonDeleted => '已删除';

  @override
  String get commonSynced => '已同步';

  @override
  String get relaySyncBlockedDisabled => '厂商已停用，先启用才能同步';

  @override
  String get kernelPhaseConnecting1 => '正在连接内核…';

  @override
  String get kernelPhaseConnecting2 => '正在校验身份…';

  @override
  String get kernelPhaseSandbox1 => '正在启动你的沙箱…';

  @override
  String get kernelPhaseSandbox2 => '正在拉起运行环境…';

  @override
  String get kernelPhaseSandbox3 => '正在准备工作目录…';

  @override
  String get kernelPhaseSandbox4 => '正在加载技能与 MCP 工具…';

  @override
  String get kernelPhaseSandbox5 => '首次启动会慢一些，请稍候…';

  @override
  String get kernelPhaseSandbox6 => '正在等待引擎握手…';

  @override
  String get kernelPhaseReady => '内核已就绪';

  @override
  String get chatSendWhileBusy => '上一轮还在跑，可直接输入插话';

  @override
  String get chatNoModelAvailable => '没有可用模型，请先在中转站启用一个厂商与模型';

  @override
  String get chatNoTurnToSteer => '当前没有进行中的对话，无法插话';

  @override
  String get chatKernelStalled => '内核长时间无响应，已恢复可输入状态';

  @override
  String get chatLocalExecUnavailable =>
      '本地引擎已启动，但命令类能力不可用（未找到 sgcode 可执行文件）—— 可以对话，但无法执行命令或改文件。装上 sgcode 或改用云端引擎。';

  @override
  String get chatOpeningThread => '正在载入这条会话…';

  @override
  String get chatJumpToLatest => '回到最新';

  @override
  String chatThreadOpenFailed(String reason) {
    return '打开会话失败：$reason';
  }

  @override
  String get artifactsTitle => '输出产物';

  @override
  String get artifactsEmpty => '暂无产物';

  @override
  String get artifactsSearch => '搜索产物';

  @override
  String get artifactsSearchHint => '按标题搜索';

  @override
  String get artifactsSearchClose => '关闭搜索';

  @override
  String get artifactsTypeAll => '全部类型';

  @override
  String get artifactsTabAll => '全部';

  @override
  String get artifactsTabYours => '你的';

  @override
  String get artifactsTabShared => '与你共享';

  @override
  String get artifactsViewGrid => '网格视图';

  @override
  String get artifactsViewList => '列表视图';

  @override
  String get artifactsMoreActions => '更多操作';

  @override
  String get artifactsCopyLink => '复制链接';

  @override
  String artifactsEdited(String when) {
    return '编辑于 $when';
  }

  @override
  String get projectsTitle => 'Projects';

  @override
  String get projectsEmpty => '暂无项目';

  @override
  String get projectsCreate => '创建项目';

  @override
  String get projectsCreateDialogTitle => '创建新项目';

  @override
  String get projectsCreateDialogName => '项目名称';

  @override
  String get projectsCreateDialogNameHint => '请输入项目名称';

  @override
  String get projectsCreateDialogNameRequired => '请输入项目名称';

  @override
  String get projectsCreateDialogDescription => '你想实现什么目标？';

  @override
  String get projectsCreateDialogDescriptionHint => '描述你的项目、目标、主题等...';

  @override
  String get projectsSearchHint => '搜索项目...';

  @override
  String get projectsMoreActions => '更多操作';

  @override
  String get projectsPin => '置顶';

  @override
  String get projectsEditDetails => '编辑细节';

  @override
  String get projectsEditDialogTitle => '编辑细节';

  @override
  String get projectsEditDialogName => '名称';

  @override
  String get projectsEditDialogDescription => '描述';

  @override
  String get projectsUpdatedJustNow => '刚刚';

  @override
  String projectsUpdatedMinutesAgo(int n) {
    return '$n 分钟前';
  }

  @override
  String projectsUpdatedHoursAgo(int n) {
    return '$n 小时前';
  }

  @override
  String projectsUpdatedDaysAgo(int n) {
    return '$n 天前';
  }

  @override
  String get customizeTitle => 'Customize';

  @override
  String get customizeTabTheme => '主题';

  @override
  String get customizeTabLayout => '布局';

  @override
  String get customizeTabShortcuts => '快捷键';

  @override
  String get customizeTabConnectors => '连接器';

  @override
  String get customizeTabPlugins => '插件';

  @override
  String get customizeTabYours => '你的';

  @override
  String get customizeTabDiscover => '发现';

  @override
  String get customizeTabForYou => '为你推荐';

  @override
  String get customizeTabNew => '最新';

  @override
  String get customizeSearchSkillsHint => '搜索技能…';

  @override
  String get customizeSearchPluginsHint => '搜索插件…';

  @override
  String get skillsYoursEmptyTitle => '你还没有自建技能';

  @override
  String get skillsYoursEmptyHint => '母版下发的技能在 Discover 里';

  @override
  String get customizeSearchHint => '搜索...';

  @override
  String get capabilitiesToolAccessMode => '工具访问模式';

  @override
  String get capabilitiesToolAccessModeDesc => '控制连接器工具在新对话中的加载方式。';

  @override
  String get capabilitiesToolAccessLoadWhenNeeded => '按需加载工具';

  @override
  String get capabilitiesConnectorSearch => '连接器搜索';

  @override
  String get capabilitiesConnectorSearchDesc =>
      '允许 Claude 搜索连接器目录，并在对话中呈现相关的连接器。';

  @override
  String get capabilitiesSwitchModels => '消息被标记时切换模型';

  @override
  String get capabilitiesSwitchModelsDesc =>
      '当安全机制标记某条消息时，自动切换到其他模型以继续对话。关闭后，对话将暂停。';

  @override
  String get capabilitiesVisuals => '视觉内容';

  @override
  String get capabilitiesArtifacts => 'Artifacts';

  @override
  String get capabilitiesArtifactsDesc => '在对话旁的独立窗口中生成代码、文档和设计。';

  @override
  String get capabilitiesArtifactsLocked => '始终开启，不可关闭。';

  @override
  String get capabilitiesAiArtifacts => 'AI 驱动的 Artifacts';

  @override
  String get capabilitiesAiArtifactsDesc =>
      '构建在 artifact 内部调用 Claude 的应用与交互式文档。';

  @override
  String get capabilitiesInlineVisualizations => '对话内可视化';

  @override
  String get capabilitiesInlineVisualizationsDesc =>
      '允许 Claude 直接在对话中生成交互式可视化、图表和图解。';

  @override
  String get capabilitiesCodeExecution => '代码执行与文件创建';

  @override
  String get capabilitiesCodeExecutionDesc =>
      'Claude 可以执行代码，并创建和编辑文档、表格、演示文稿、PDF 和数据报告。技能功能依赖此项。';

  @override
  String get capabilitiesNetworkEgress => '允许网络出站';

  @override
  String capabilitiesNetworkEgressDesc(
    String viewDomains,
    String securityRisks,
  ) {
    return '允许 Claude 访问常用包管理器，以安装用于数据分析、可视化和文件处理的包与库。$viewDomains。请密切监控对话，因为这会带来$securityRisks。';
  }

  @override
  String get capabilitiesNetworkEgressViewDomains => '查看包管理器域名';

  @override
  String get capabilitiesNetworkEgressSecurityRisks => '安全风险';

  @override
  String get capabilitiesSkills => '技能';

  @override
  String capabilitiesSkillsMoved(String customize) {
    return '技能已移至「$customize」。';
  }

  @override
  String get searchSectionRecents => '最近';

  @override
  String get searchSectionActions => '操作';

  @override
  String get searchTabAll => '全部';

  @override
  String get searchTabArtifacts => '输出物';

  @override
  String get searchTabChats => '聊天';

  @override
  String get searchTabProjects => '项目';

  @override
  String get searchTabSessions => '会话';

  @override
  String get searchTabTasks => '任务';

  @override
  String get searchTabScheduled => '定时';

  @override
  String searchNoResultsIn(String type) {
    return '$type 中没有结果';
  }

  @override
  String get searchSearchAll => '搜索全部';

  @override
  String get searchNewChat => '新建对话';

  @override
  String get searchTimeToday => '今天';

  @override
  String get searchTimePastWeek => '过去一周';

  @override
  String get searchTimePastMonth => '过去一月';

  @override
  String get searchTimePastYear => '过去一年';

  @override
  String get searchTimeOlder => '更早';

  @override
  String get searchFooterClose => '关闭';

  @override
  String get searchFooterChangeType => '切换分类';

  @override
  String get searchFooterFilters => '筛选';

  @override
  String get searchFooterActions => '更多';

  @override
  String get searchFooterCompose => '输入';

  @override
  String get searchFiltersTitle => '筛选分类';

  @override
  String get searchOpen => '打开';

  @override
  String get searchFilterBy => '筛选';

  @override
  String get searchFilterOwner => '所有者';

  @override
  String get searchFilterDate => '日期';

  @override
  String get searchFilterType => '类型';

  @override
  String get searchFilterArchived => '已归档';

  @override
  String get searchFilterActions => '操作';

  @override
  String get searchOwnerMe => '我';

  @override
  String get searchOwnerShared => '与我共享';

  @override
  String get searchActionsHint => '搜索操作';
}
