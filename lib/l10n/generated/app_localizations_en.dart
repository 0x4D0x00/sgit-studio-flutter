// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get navSearch => 'Search';

  @override
  String get navGetApps => 'Get apps and extensions';

  @override
  String get navSearchDialogHint => 'Search chats';

  @override
  String get navSearchDialogEmpty => 'No matching chats found';

  @override
  String get navNewChat => 'New chat';

  @override
  String get navNew => 'New';

  @override
  String get navProjects => 'Projects';

  @override
  String get navCustomize => 'Customize';

  @override
  String get navHistory => 'History';

  @override
  String get navChatPin => 'Pin';

  @override
  String get navChatRename => 'Rename';

  @override
  String get navViewAll => 'View all';

  @override
  String get navSelect => 'Select';

  @override
  String get navSelectAll => 'Select all';

  @override
  String get navDeselectAll => 'Deselect all';

  @override
  String navSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get commonClose => 'Close';

  @override
  String get navAssistants => 'Assistants';

  @override
  String get assistantPentest => 'Pentest assistant';

  @override
  String get assistantDefense => 'Defense assistant';

  @override
  String get assistantContest => 'Contest assistant';

  @override
  String get assistantOffice => 'Office assistant';

  @override
  String get assistantSwitcher => 'Switch assistant';

  @override
  String get navStudioGroup => 'Studio';

  @override
  String get navGetHelp => 'Get help';

  @override
  String get navLearnMore => 'Learn more';

  @override
  String navAboutBrand(String brand) {
    return 'About $brand';
  }

  @override
  String get navUsagePolicy => 'Usage policy';

  @override
  String get navPrivacyPolicy => 'Privacy policy';

  @override
  String get navTermsOfService => 'Terms of service';

  @override
  String get navPrivacyChoices => 'Your privacy choices';

  @override
  String get navKeyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get navSettings => 'Settings';

  @override
  String get navLogout => 'Log out';

  @override
  String get chatGroupBy => 'Group by';

  @override
  String get chatSortBy => 'Sort by';

  @override
  String get chatGroupNone => 'None';

  @override
  String get chatGroupDate => 'Date';

  @override
  String get chatGroupAssistant => 'Assistant';

  @override
  String get chatSortName => 'Name';

  @override
  String get chatSortLastActivity => 'Last activity';

  @override
  String get chatGroupToday => 'Today';

  @override
  String get chatGroupYesterday => 'Yesterday';

  @override
  String get chatGroupOlder => 'Older';

  @override
  String get chatGroupUnknown => 'Unknown date';

  @override
  String get chatRenameHint => 'Keep it short and recognizable.';

  @override
  String get chatHistoryEmptyAction => 'Start a new chat';

  @override
  String get shellExpandNav => 'Expand navigation';

  @override
  String get shellCollapseNav => 'Collapse navigation';

  @override
  String get shellToggleOutput => 'Output panel';

  @override
  String get shellOutputTitle => 'Outputs';

  @override
  String get shellOutputEmpty => 'No outputs yet';

  @override
  String workspaceWelcome(String name) {
    return '$name is standing by';
  }

  @override
  String get workspaceInputHint => 'How can I help?';

  @override
  String get workspaceInputHintDocs => 'What should this document be about?';

  @override
  String get workspaceInputHintSlides => 'What should this deck be about?';

  @override
  String get workspaceInputHintDesign => 'What should this design show?';

  @override
  String get workspaceModeDocs => 'Docs';

  @override
  String get workspaceModeSlides => 'Slides';

  @override
  String get workspaceModeDesign => 'Design';

  @override
  String get workspaceDesignSystem => 'system';

  @override
  String get workspaceModeRemoveDocs => 'Remove document';

  @override
  String get workspaceModeRemoveSlides => 'Remove deck';

  @override
  String get workspaceModeRemoveDesign => 'Remove design';

  @override
  String get workspaceSend => 'Send';

  @override
  String get studioAccessDenied => 'You don\'t have access to this feature';

  @override
  String get studioScenes => 'Scenes';

  @override
  String get studioSubagent => 'Subagents';

  @override
  String get studioSkill => 'Skills';

  @override
  String get studioMcp => 'MCP';

  @override
  String get studioTools => 'Tools';

  @override
  String get studioMemory => 'Memory';

  @override
  String get studioKnowledge => 'Knowledge';

  @override
  String get studioLlmRelay => 'Model relay';

  @override
  String get studioApiKey => 'API keys';

  @override
  String get chatFaultNotConnected => 'Not connected to the kernel';

  @override
  String get chatReconnect => 'Reconnect';

  @override
  String get chatAddMenu => 'More options';

  @override
  String get chatAttachFiles => 'Add files/images';

  @override
  String get chatWebSearch => 'Web search';

  @override
  String get chatAgentGateway => 'Agent Gateway';

  @override
  String get chatStop => 'Stop';

  @override
  String get chatSteerHint => 'Steer mid-turn…';

  @override
  String get chatPickFile => 'Choose a file';

  @override
  String get chatPickImage => 'Choose an image';

  @override
  String chatPickFileFailed(String reason) {
    return 'Couldn\'t open the file picker: $reason';
  }

  @override
  String get chatRemoveAttachment => 'Remove attachment';

  @override
  String get chatReply => 'Reply';

  @override
  String get chatQuoteTitle => 'Quote';

  @override
  String get chatRemoveQuote => 'Remove quote';

  @override
  String get chatClearScene => 'Leave scene';

  @override
  String get chatMemory => 'Memory';

  @override
  String get chatSkills => 'Skills';

  @override
  String get chatKnowledge => 'Knowledge';

  @override
  String get chatContextWindow => 'Context window';

  @override
  String chatContextWindowDetail(int used, int total) {
    return '$used of $total tokens used';
  }

  @override
  String get chatApprovalPolicy => 'Approvals';

  @override
  String get chatApprovalUntrusted => 'Trust reads only';

  @override
  String get chatApprovalUntrustedDesc =>
      'Auto-approve known-safe read-only commands; ask about everything else';

  @override
  String get chatApprovalOnRequest => 'Model decides';

  @override
  String get chatApprovalOnRequestDesc =>
      'The model judges when to ask you (engine default)';

  @override
  String get chatApprovalNever => 'Never ask';

  @override
  String get chatApprovalNeverDesc =>
      'Never interrupt you; failures go straight back to the model';

  @override
  String get chatApprovalGranular => 'Fine-grained';

  @override
  String get chatApprovalGranularDesc =>
      'Choose which kinds of action need approval';

  @override
  String get chatApprovalFieldSandbox => 'Shell commands';

  @override
  String get chatApprovalFieldRules => 'Rule changes';

  @override
  String get chatApprovalFieldSkill => 'Skill calls';

  @override
  String get chatApprovalFieldPermissions => 'Permission requests';

  @override
  String get chatApprovalFieldMcp => 'MCP requests';

  @override
  String get chatSandboxMode => 'Sandbox';

  @override
  String get chatSandboxReadOnly => 'Read-only';

  @override
  String get chatSandboxReadOnlyDesc =>
      'Can read, cannot change any file (engine default)';

  @override
  String get chatSandboxWorkspaceWrite => 'Workspace write';

  @override
  String get chatSandboxWorkspaceWriteDesc =>
      'Can change files inside the working directory';

  @override
  String get chatSandboxDangerFullAccess => 'Full access';

  @override
  String get chatSandboxDangerFullAccessDesc =>
      'No restrictions. Only if you understand the risk';

  @override
  String get chatReasoningEffort => 'Reasoning';

  @override
  String get chatEffortNone => 'Off';

  @override
  String get chatEffortMinimal => 'Minimal';

  @override
  String get chatEffortLow => 'Low';

  @override
  String get chatEffortMedium => 'Medium';

  @override
  String get chatEffortHigh => 'High';

  @override
  String get chatEffortXhigh => 'Very high';

  @override
  String get chatEffortMax => 'Max';

  @override
  String get chatEffortUltra => 'Ultra';

  @override
  String chatSettingWriteFailed(String reason) {
    return 'Setting not saved: $reason';
  }

  @override
  String get chatTextTruncated => 'Content may be incomplete';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatCopied => 'Copied';

  @override
  String get chatCopiedAll => 'Whole conversation copied';

  @override
  String get chatArtifactOpen => 'Open in panel';

  @override
  String get chatArtifactDownload => 'Download';

  @override
  String get chatArtifactClose => 'Close';

  @override
  String get chatArtifactDownloading => 'Saving…';

  @override
  String get chatArtifactSaved => 'Saved';

  @override
  String get chatArtifactSaveFailed => 'Couldn\'t save';

  @override
  String get chatArtifactExpand => 'Fullscreen';

  @override
  String get chatArtifactCollapse => 'Exit fullscreen';

  @override
  String get chatArtifactPanelTitle => 'Artifacts';

  @override
  String get chatArtifactPanelEmpty => 'No artifacts in this conversation yet';

  @override
  String get chatArtifactUnavailable =>
      'This content can\'t be rendered graphically — showing the raw text';

  @override
  String get chatEdit => 'Edit';

  @override
  String get chatEditRegenerateHint =>
      'Saving discards everything after this message and restarts the conversation from your edit';

  @override
  String get chatRetry => 'Retry';

  @override
  String get chatReadAloud => 'Read aloud';

  @override
  String get chatThumbUp => 'Good response';

  @override
  String get chatThumbDown => 'Bad response';

  @override
  String get chatApprovalTitle => 'Needs your confirmation';

  @override
  String get chatApprovalAllowOnce => 'Allow once';

  @override
  String get chatApprovalAllowAlways => 'Always allow';

  @override
  String get chatApprovalDeny => 'Deny';

  @override
  String get chatApprovalResolvedAllow => 'Allowed';

  @override
  String get chatApprovalResolvedAlways => 'Always allowed';

  @override
  String get chatApprovalResolvedDeny => 'Denied';

  @override
  String get chatEngineMode => 'Engine Mode';

  @override
  String get chatEngineModeLocal => 'Local Engine';

  @override
  String get chatEngineModeRemote => 'Remote Engine';

  @override
  String get chatToolRunning => 'Running…';

  @override
  String get chatToolTruncated =>
      'Output truncated — expand to fetch the full text';

  @override
  String get chatThinking1 => 'Thinking…';

  @override
  String get chatThinking2 => 'Working through it…';

  @override
  String get chatThinking3 => 'Weighing options…';

  @override
  String get chatThinking4 => 'Checking details…';

  @override
  String get chatThinking5 => 'Drafting…';

  @override
  String get chatNoticeCompacted => 'Context compacted';

  @override
  String get chatNoticeDisconnected => 'Disconnected';

  @override
  String get chatNoticeUnknown => 'Notice';

  @override
  String chatToolElapsed(int ms) {
    return '$ms ms';
  }

  @override
  String chatNoticeModelRerouted(String to) {
    return 'Model rerouted to $to';
  }

  @override
  String chatNoticeDropped(int count) {
    return '$count deltas were merged (content may be incomplete)';
  }

  @override
  String chatFaultVersionMismatch(int kernel, int client) {
    return 'Kernel frame version $kernel does not match client $client. Please upgrade the client.';
  }

  @override
  String chatStats(int input, int output, int ms) {
    return 'in $input · out $output · $ms ms';
  }

  @override
  String get studioEmpty => 'Nothing here yet';

  @override
  String get studioRefresh => 'Refresh';

  @override
  String get studioUnsyncedHint =>
      'Changed locally, not yet synced to the server';

  @override
  String get studioSyncNow => 'Sync to server';

  @override
  String get studioSyncDone => 'Synced';

  @override
  String studioSyncConflicts(int count) {
    return 'Synced. $count item(s) conflicted: the server version won, your edits were kept as .conflict backups';
  }

  @override
  String get studioRemove => 'Delete';

  @override
  String studioRemoveConfirm(String name) {
    return 'Delete “$name”?';
  }

  @override
  String studioRemoveConfirmMany(int count) {
    return 'Delete $count selected items?';
  }

  @override
  String get studioStale => 'Showing cached data, refreshing…';

  @override
  String get studioComingSoon => 'Data source not wired yet';

  @override
  String get relayProviders => 'Providers';

  @override
  String get relayModels => 'Models';

  @override
  String get relayKeys => 'API keys';

  @override
  String get relayDisabled => 'Disabled';

  @override
  String get relayCustom => 'Custom';

  @override
  String get relayPlatform => 'Platform';

  @override
  String get relayPlatformReadonly =>
      'Platform-provided; read-only on your personal page';

  @override
  String get relayBack => 'Back';

  @override
  String get relayKeyMasked => 'Only the last 6 characters are shown';

  @override
  String relayContextWindow(int n) {
    return 'ctx $n';
  }

  @override
  String get relayToggleOn => 'Click to enable';

  @override
  String get relayToggleOff => 'Click to disable';

  @override
  String get relaySync => 'Sync models';

  @override
  String get relayNoProvider => 'No provider configured yet';

  @override
  String get modelSelector => 'Select model';

  @override
  String get modelSelectorNone => 'No models available';

  @override
  String get navNewChatDone => 'Started a new conversation';

  @override
  String get loginButton => 'Sign in';

  @override
  String get loginIdentifierPlaceholder => 'Enter your username';

  @override
  String get loginPasswordPlaceholder => 'Enter your password';

  @override
  String get loginCaptchaPlaceholder => 'Enter the code';

  @override
  String get loginCaptchaRefresh => 'Click to refresh the captcha';

  @override
  String get loginCaptchaFailed =>
      'Failed to load the captcha — click the image to retry';

  @override
  String get loginIdentifierRequired => 'Please enter your username';

  @override
  String get loginPasswordRequired => 'Please enter your password';

  @override
  String get loginCaptchaRequired => 'Please enter the image captcha';

  @override
  String get loginSessionExpired =>
      'Your session has expired — please sign in again';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsThemeMode => 'Theme mode';

  @override
  String get settingsThemeTransparent => 'Transparent';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsPrimaryColor => 'Primary color';

  @override
  String get settingsSecondaryColor => 'Secondary color';

  @override
  String get settingsFontScale => 'Font scale';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageZh => '简体中文';

  @override
  String get settingsLanguageEn => 'English';

  @override
  String get settingsLanguageSearch => 'Search languages';

  @override
  String get settingsResetDefault => 'Reset to default';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsBilling => 'Billing';

  @override
  String get settingsCapabilities => 'Capabilities';

  @override
  String get settingsMemory => 'Memory';

  @override
  String get settingsReflect => 'Reflect';

  @override
  String get settingsTimeFocus => 'Time and focus';

  @override
  String get settingsClaudeCode => 'Claude Code';

  @override
  String get settingsCustomize => 'Customize';

  @override
  String get settingsSkills => 'Skills';

  @override
  String get settingsConnectors => 'Connectors';

  @override
  String get settingsPlugins => 'Plugins';

  @override
  String get settingsSearch => 'Search';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsChatFont => 'Chat font';

  @override
  String get settingsTranscriptWidth => 'Transcript width';

  @override
  String get settingsTranscriptWidthDesc =>
      'Maximum width of the transcript and composer columns.';

  @override
  String get settingsTranscriptNarrow => 'Narrow';

  @override
  String get settingsTranscriptMedium => 'Medium';

  @override
  String get settingsTranscriptWide => 'Wide';

  @override
  String get settingsMotion => 'Motion';

  @override
  String get settingsMotionDesc =>
      'Reduce animation in streaming responses and other interface elements.';

  @override
  String get settingsMotionSystem => 'System';

  @override
  String get settingsMotionReduced => 'Reduced';

  @override
  String get settingsVoice => 'Voice';

  @override
  String get settingsVoiceLanguage => 'Language';

  @override
  String get settingsVoiceStyle => 'Style';

  @override
  String get settingsVoiceSpeed => 'Speed';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotifResponseComplete => 'Response completions';

  @override
  String get settingsNotifResponseCompleteDesc =>
      'Get notified when Claude has finished a response. Useful for long-running tasks.';

  @override
  String get settingsFontAnthropic => 'Anthropic Serif';

  @override
  String get settingsFontSystem => 'System font';

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
  String get settingsComingSoon => 'Coming soon';

  @override
  String get settingsComingSoonDesc => 'This feature is under development';

  @override
  String get billingFreePlan => 'Free plan';

  @override
  String get billingTryClaude => 'Try Claude';

  @override
  String get billingUpgradePlan => 'Upgrade plan';

  @override
  String get billingFeatureChatPlatforms =>
      'Chat on web, iOS, Android, and on your desktop';

  @override
  String get billingFeatureGenerateCode => 'Generate code and visualize data';

  @override
  String get billingFeatureWriteEdit => 'Write, edit, and create content';

  @override
  String get billingFeatureSearchWeb => 'Ability to search the web';

  @override
  String get billingFeatureMemory => 'Memory across conversations';

  @override
  String get billingFeatureCreateFiles => 'Create files and execute code';

  @override
  String get billingFeatureDesktopExtensions =>
      'Unlock more from Claude with desktop extensions';

  @override
  String get billingFeatureConnectWorkspace =>
      'Connect Slack and Google Workspace services';

  @override
  String get billingFeatureConnectors =>
      'Integrate any context or tool through connectors with remote MCP';

  @override
  String get billingFeatureExtendedThinking =>
      'Extended thinking for complex work';

  @override
  String get memoryTitle => 'Memory';

  @override
  String get memoryGenerateFromChats => 'Generate memory from chats';

  @override
  String memoryGenerateFromChatsDesc(Object learnMore) {
    return 'Allow Claude to generate memory from your chats. $learnMore';
  }

  @override
  String get memoryGenerateFromChatsLearnMore => 'Learn more.';

  @override
  String get memoryLearnMore => 'Learn more.';

  @override
  String get memorySensitiveTopics => 'Include sensitive topics in memory';

  @override
  String memorySensitiveTopicsDesc(Object learnMore) {
    return 'Allow Claude to save details about sensitive topics like health conditions or religious beliefs to memory. $learnMore';
  }

  @override
  String get memoryImportFromOtherAi => 'Import memory from other AI providers';

  @override
  String memoryImportFromOtherAiDesc(Object learnMore) {
    return 'Bring relevant context and data from another AI provider to Claude. We\'ll provide a prompt you can use to fetch the memory from your other account. $learnMore';
  }

  @override
  String get memoryStartImport => 'Start import';

  @override
  String get memoryNoFiles => 'No files yet';

  @override
  String get memoryInputHint => 'My dog\'s name is Beans';

  @override
  String get memoryDisableTitle => 'Turn off memory';

  @override
  String get memoryPauseMemory => 'Pause memory';

  @override
  String get memoryPauseMemoryDesc =>
      'Claude keeps its existing memory, including sensitive topics, but won\'t use memory or make new memories.';

  @override
  String get memoryResetMemory => 'Reset memory';

  @override
  String get memoryResetMemoryDesc =>
      'This will permanently delete all memories, including project memories, and turn off saving sensitive topics. This can\'t be undone.';

  @override
  String get reflectTitle => 'Reflect';

  @override
  String get reflectDesc => 'Based on your conversations in Claude chat.';

  @override
  String get reflectEnableMemoryHintPrefix =>
      'For this reflection to work, you\'ll need to enable memory in ';

  @override
  String get reflectMemorySettingsLink => 'memory settings';

  @override
  String get reflectEnableMemoryHintSuffix => '.';

  @override
  String get timeFocusTitle => 'Time and focus';

  @override
  String get timeFocusBreakReminders => 'Break reminders';

  @override
  String get timeFocusBreakRemindersDesc =>
      'Get a nudge to take a break from Claude. You can snooze or adjust anytime.';

  @override
  String get timeFocusQuietHours => 'Quiet hours';

  @override
  String get timeFocusQuietHoursDesc =>
      'Set time limits for Claude. You can dismiss or adjust anytime.';

  @override
  String get commonDashPlaceholder => '-';

  @override
  String commonHoursValue(int n) {
    return '$n hr';
  }

  @override
  String commonMinutesValue(int n) {
    return '$n min';
  }

  @override
  String get commonSunday => 'S';

  @override
  String get commonMonday => 'M';

  @override
  String get commonTuesday => 'T';

  @override
  String get commonWednesday => 'W';

  @override
  String get commonThursday => 'T';

  @override
  String get commonFriday => 'F';

  @override
  String get commonSaturday => 'S';

  @override
  String get timeFocusQuietHoursTo => 'to';

  @override
  String get timeFocusQuietHoursNextDay => 'next day';

  @override
  String get accountAvatar => 'Avatar';

  @override
  String get accountUsername => 'Username';

  @override
  String get accountPassword => 'Password';

  @override
  String get accountChangeAvatar => 'Change avatar';

  @override
  String get accountChangePassword => 'Change password';

  @override
  String get accountCurrentPassword => 'Current password';

  @override
  String get accountNewPassword => 'New password';

  @override
  String get accountConfirmPassword => 'Confirm password';

  @override
  String get accountUsernamePlaceholder => 'Enter your username';

  @override
  String get accountCurrentPasswordPlaceholder => 'Enter current password';

  @override
  String get accountNewPasswordPlaceholder => 'Enter new password';

  @override
  String get accountConfirmPasswordPlaceholder => 'Enter new password again';

  @override
  String get accountPasswordMismatch => 'Passwords do not match';

  @override
  String get accountPasswordTooShort =>
      'Password must be at least 6 characters';

  @override
  String get accountUpdateSuccess => 'Updated successfully';

  @override
  String get accountUpdateFailed => 'Update failed';

  @override
  String get accountAvatarTooLarge =>
      'Image is too large, please choose one under 5MB';

  @override
  String get accountProfile => 'Profile';

  @override
  String get accountWorkDescription => 'What best describes your work?';

  @override
  String get accountWorkPlaceholder => 'Select your role';

  @override
  String get accountWorkRoleProductManagement => 'Product management';

  @override
  String get accountWorkRoleEngineering => 'Engineering';

  @override
  String get accountWorkRoleHumanResources => 'Human resources';

  @override
  String get accountWorkRoleDesign => 'Design';

  @override
  String get accountWorkRoleSoftwareEngineering => 'Software engineering';

  @override
  String get accountWorkRoleStudent => 'Student';

  @override
  String get accountWorkRoleOther => 'Other';

  @override
  String get accountInstructions => 'Instructions for Claude';

  @override
  String get accountInstructionsDesc =>
      'Claude will keep these in mind for this and any of your associated accounts across chats and Cowork within Anthropic\'s guidelines.';

  @override
  String get accountInstructionsPlaceholder =>
      'e.g. when learning new concepts, I find analogies particularly helpful';

  @override
  String get accountInstructionsLearnMore => 'Learn more';

  @override
  String get accountSectionTitle => 'Account';

  @override
  String get accountLogoutAll => 'Log out of all devices';

  @override
  String get accountLogout => 'Log out';

  @override
  String get accountDelete => 'Delete your account';

  @override
  String get accountDeleteButton => 'Delete account';

  @override
  String get accountOrgId => 'Organization ID';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String privacyIntro(Object privacyCenter, Object privacyPolicy) {
    return 'Anthropic believes in transparent data practices. Learn how your information is protected when using Anthropic products, and visit our $privacyCenter and $privacyPolicy for more details.';
  }

  @override
  String get privacyCenter => 'Privacy Center';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyProtectData => 'How we protect your data';

  @override
  String get privacyUseData => 'How we use your data';

  @override
  String get privacyPreferences => 'Preferences';

  @override
  String get privacyLocationMetadata => 'Location metadata';

  @override
  String privacyLocationMetadataDesc(Object learnMore) {
    return 'Allow Claude to use coarse location metadata (city/region) to improve product experiences. $learnMore';
  }

  @override
  String get privacyLocationMetadataLearnMore => 'Learn more.';

  @override
  String get privacyImproveModels => 'Help improve our AI models';

  @override
  String privacyImproveModelsDesc(Object learnMore) {
    return 'Allow the use of your chats and coding sessions to train and improve Anthropic AI models. $learnMore';
  }

  @override
  String get privacyImproveModelsLearnMore => 'Learn more.';

  @override
  String get privacyYourData => 'Your data';

  @override
  String get privacyExportData => 'Export data';

  @override
  String get privacyExportDataButton => 'Export data';

  @override
  String get privacySharedChats => 'Shared chats';

  @override
  String get privacySharedArtifacts => 'Shared artifacts';

  @override
  String get privacyUploadedFiles => 'Uploaded files';

  @override
  String get privacyYourFeedback => 'Your feedback';

  @override
  String get privacyManage => 'Manage';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonLoading => 'Loading…';

  @override
  String get commonEmpty => 'No data';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get commonComingSoon => 'Coming soon';

  @override
  String commonNotWired(String what) {
    return '$what: not wired up yet';
  }

  @override
  String get studioScopePersonal => 'Personal';

  @override
  String get studioScopeMaster => 'Manage';

  @override
  String get studioScopeMasterHint =>
      'Manage scope: changes apply to all users';

  @override
  String get relayAddProvider => 'Add provider';

  @override
  String get relayEditProvider => 'Edit provider';

  @override
  String get relayDeleteProvider => 'Delete provider';

  @override
  String get relayDeleteProviderHint =>
      'Providers that still have models or keys cannot be deleted. Clear them on the models page first.';

  @override
  String get relayAddModel => 'Add model';

  @override
  String get relayEditModel => 'Edit model';

  @override
  String get relayDeleteModel => 'Delete model';

  @override
  String get relayKeyPool => 'Key pool';

  @override
  String relayKeyPoolTitle(String code) {
    return 'API key pool · $code (shared by all models of this brand)';
  }

  @override
  String relaySyncConfirmMaster(String code) {
    return 'Sync the latest model list from $code?';
  }

  @override
  String relaySyncConfirmPersonal(String code) {
    return 'Pull the model list directly from $code? Fill in Base URL and add a key first.';
  }

  @override
  String relayScopeHintMaster(int n) {
    return '$n models · saved/synced changes apply to all users';
  }

  @override
  String relayScopeHintPersonal(int n) {
    return '$n models · visible only to you · sgcode connects to the vendor directly';
  }

  @override
  String get relayLocalBadge => 'Personal (local)';

  @override
  String get relayAddKey => 'Add';

  @override
  String get relayKeyNameHint => 'Key label (optional)';

  @override
  String get relayKeyPasteHint => 'Paste API key';

  @override
  String get relayNoKeys => 'No keys yet';

  @override
  String get relayNoProviders =>
      'No providers yet. Use \"Add provider\" to create one.';

  @override
  String get relayFieldModelCode => 'Brand code';

  @override
  String get relayFieldProvider => 'Vendor tag';

  @override
  String get relayFieldDisplayName => 'Display name';

  @override
  String get relayFieldBaseUrl => 'Base URL';

  @override
  String get relayFieldEndpoint => 'Chat endpoint';

  @override
  String get relayFieldModelsEndpoint => 'Models endpoint';

  @override
  String get relayFieldUploadBaseUrl => 'Upload base URL';

  @override
  String get relayFieldModelType => 'Type';

  @override
  String get relayFieldPriority => 'Priority';

  @override
  String get relayFieldModelName => 'Model name';

  @override
  String get relayFieldContextWindow => 'Context window';

  @override
  String get relayFieldMaxOutput => 'Max output';

  @override
  String get relayFieldAvailable => 'Available';

  @override
  String get relayRequiredModelCode =>
      'Brand code is required (unique, e.g. DeepSeek)';

  @override
  String get relayRequiredModelName => 'Model code and model name are required';

  @override
  String get relayRequiredApiKey => 'Enter an API key';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSaved => 'Saved';

  @override
  String get commonDeleted => 'Deleted';

  @override
  String get commonSynced => 'Synced';

  @override
  String get relaySyncBlockedDisabled =>
      'Provider is disabled — enable it before syncing';

  @override
  String get kernelPhaseConnecting1 => 'Connecting to the kernel…';

  @override
  String get kernelPhaseConnecting2 => 'Verifying your session…';

  @override
  String get kernelPhaseSandbox1 => 'Starting your sandbox…';

  @override
  String get kernelPhaseSandbox2 => 'Bringing up the runtime…';

  @override
  String get kernelPhaseSandbox3 => 'Preparing the workspace…';

  @override
  String get kernelPhaseSandbox4 => 'Loading skills and MCP tools…';

  @override
  String get kernelPhaseSandbox5 => 'First start takes a little longer…';

  @override
  String get kernelPhaseSandbox6 => 'Waiting for the engine handshake…';

  @override
  String get kernelPhaseReady => 'Kernel ready';

  @override
  String get chatSendWhileBusy =>
      'Still running — type to steer the current turn';

  @override
  String get chatNoModelAvailable =>
      'No model available — enable a provider and model in Relay first';

  @override
  String get chatNoTurnToSteer => 'No turn in progress to steer';

  @override
  String get chatKernelStalled =>
      'The kernel stopped responding — input re-enabled';

  @override
  String get chatLocalExecUnavailable =>
      'Local engine started, but command tools are unavailable (sgcode executable not found) — chat works, running commands and editing files does not. Install sgcode or switch to the remote engine.';

  @override
  String get chatOpeningThread => 'Loading this conversation…';

  @override
  String get chatJumpToLatest => 'Jump to latest';

  @override
  String chatThreadOpenFailed(String reason) {
    return 'Couldn\'t open the conversation: $reason';
  }

  @override
  String get artifactsTitle => 'Artifacts';

  @override
  String get artifactsMakeNew => 'Make something new';

  @override
  String get artifactsCreateDocs => 'Docs';

  @override
  String get artifactsCreateSlides => 'Slides';

  @override
  String get artifactsCreateDesign => 'Design';

  @override
  String get artifactsNewBadge => 'New';

  @override
  String get artifactsEmpty => 'No artifacts yet';

  @override
  String get artifactsSearch => 'Search artifacts';

  @override
  String get artifactsSearchHint => 'Search by title';

  @override
  String get artifactsSearchClose => 'Close search';

  @override
  String get artifactsTypeAll => 'All types';

  @override
  String get artifactsTabAll => 'All';

  @override
  String get artifactsTabYours => 'Yours';

  @override
  String get artifactsTabShared => 'Shared with you';

  @override
  String get artifactsViewGrid => 'Grid view';

  @override
  String get artifactsViewList => 'List view';

  @override
  String get artifactsMoreActions => 'More actions';

  @override
  String get artifactsCopyLink => 'Copy link';

  @override
  String artifactsEdited(String when) {
    return 'Edited $when';
  }

  @override
  String get projectsTitle => 'Projects';

  @override
  String get projectsEmpty => 'No projects yet';

  @override
  String get projectsCreate => 'Create project';

  @override
  String get projectsCreateDialogTitle => 'Create new project';

  @override
  String get projectsCreateDialogName => 'Project name';

  @override
  String get projectsCreateDialogNameHint => 'Enter project name';

  @override
  String get projectsCreateDialogNameRequired => 'Please enter a project name';

  @override
  String get projectsCreateDialogDescription =>
      'What are you trying to achieve?';

  @override
  String get projectsCreateDialogDescriptionHint =>
      'Describe your project, goals, subject, etc...';

  @override
  String get projectsSearchHint => 'Search projects...';

  @override
  String get projectsMoreActions => 'More actions';

  @override
  String get projectsPin => 'Pin';

  @override
  String get projectsEditDetails => 'Edit details';

  @override
  String get projectsEditDialogTitle => 'Edit details';

  @override
  String get projectsEditDialogName => 'Name';

  @override
  String get projectsEditDialogDescription => 'Description';

  @override
  String get projectsUpdatedJustNow => 'Just now';

  @override
  String projectsUpdatedMinutesAgo(int n) {
    return '$n minutes ago';
  }

  @override
  String projectsUpdatedHoursAgo(int n) {
    return '$n hours ago';
  }

  @override
  String projectsUpdatedDaysAgo(int n) {
    return '$n days ago';
  }

  @override
  String get customizeTitle => 'Customize';

  @override
  String get customizeTabTheme => 'Theme';

  @override
  String get customizeTabLayout => 'Layout';

  @override
  String get customizeTabShortcuts => 'Shortcuts';

  @override
  String get customizeTabConnectors => 'Connectors';

  @override
  String get customizeTabPlugins => 'Plugins';

  @override
  String get customizeTabYours => 'Yours';

  @override
  String get customizeTabDiscover => 'Discover';

  @override
  String get customizeTabForYou => 'For you';

  @override
  String get customizeTabNew => 'New';

  @override
  String get customizeSearchSkillsHint => 'Search skills...';

  @override
  String get customizeSearchPluginsHint => 'Search plugins...';

  @override
  String get skillsYoursEmptyTitle => 'You have no skills of your own yet';

  @override
  String get skillsYoursEmptyHint =>
      'Skills pushed from the master library live in Discover';

  @override
  String get customizeSearchHint => 'Search...';

  @override
  String get capabilitiesToolAccessMode => 'Tool access mode';

  @override
  String get capabilitiesToolAccessModeDesc =>
      'Controls how connector tools are loaded in new conversations.';

  @override
  String get capabilitiesToolAccessLoadWhenNeeded => 'Load tools when needed';

  @override
  String get capabilitiesConnectorSearch => 'Connector search';

  @override
  String get capabilitiesConnectorSearchDesc =>
      'Let Claude search the connector directory and surface ones relevant to your conversation.';

  @override
  String get capabilitiesSwitchModels =>
      'Switch models when a message is flagged';

  @override
  String get capabilitiesSwitchModelsDesc =>
      'When safeguards flag a message, automatically switch to a different model to keep chatting. When off, your chat will pause instead.';

  @override
  String get capabilitiesVisuals => 'Visuals';

  @override
  String get capabilitiesArtifacts => 'Artifacts';

  @override
  String get capabilitiesArtifactsDesc =>
      'Generate code, documents, and designs in a dedicated window alongside your conversation.';

  @override
  String get capabilitiesArtifactsLocked =>
      'Always on and can\'t be turned off.';

  @override
  String get capabilitiesAiArtifacts => 'AI-powered artifacts';

  @override
  String get capabilitiesAiArtifactsDesc =>
      'Build apps and interactive documents that use Claude inside the artifact.';

  @override
  String get capabilitiesInlineVisualizations => 'Inline visualizations';

  @override
  String get capabilitiesInlineVisualizationsDesc =>
      'Allow Claude to generate interactive visualizations, charts, and diagrams directly in the conversation.';

  @override
  String get capabilitiesCodeExecution => 'Code execution and file creation';

  @override
  String get capabilitiesCodeExecutionDesc =>
      'Claude can execute code and create and edit docs, spreadsheets, presentations, PDFs, and data reports. Required for skills.';

  @override
  String get capabilitiesNetworkEgress => 'Allow network egress';

  @override
  String capabilitiesNetworkEgressDesc(
    String viewDomains,
    String securityRisks,
  ) {
    return 'Allow Claude to access common package managers to install packages and libraries for data analysis, visualizations, and file processing. $viewDomains. Monitor chats closely as this comes with $securityRisks.';
  }

  @override
  String get capabilitiesNetworkEgressViewDomains =>
      'View package manager domains';

  @override
  String get capabilitiesNetworkEgressSecurityRisks => 'security risks';

  @override
  String get capabilitiesSkills => 'Skills';

  @override
  String capabilitiesSkillsMoved(String customize) {
    return 'Skills have moved to $customize.';
  }

  @override
  String get searchSectionRecents => 'Recents';

  @override
  String get searchSectionActions => 'Actions';

  @override
  String get searchTabAll => 'All';

  @override
  String get searchTabArtifacts => 'Artifacts';

  @override
  String get searchTabChats => 'Chats';

  @override
  String get searchTabProjects => 'Projects';

  @override
  String get searchTabSessions => 'Sessions';

  @override
  String get searchTabTasks => 'Tasks';

  @override
  String get searchTabScheduled => 'Scheduled';

  @override
  String searchNoResultsIn(String type) {
    return 'No results in $type';
  }

  @override
  String get searchSearchAll => 'Search all';

  @override
  String get searchNewChat => 'New chat';

  @override
  String get searchTimeToday => 'Today';

  @override
  String get searchTimePastWeek => 'Past week';

  @override
  String get searchTimePastMonth => 'Past month';

  @override
  String get searchTimePastYear => 'Past year';

  @override
  String get searchTimeOlder => 'Older';

  @override
  String get searchFooterClose => 'Close';

  @override
  String get searchFooterChangeType => 'Change type';

  @override
  String get searchFooterFilters => 'Filters';

  @override
  String get searchFooterActions => 'Actions';

  @override
  String get searchFooterCompose => 'Compose';

  @override
  String get searchFiltersTitle => 'Filter by type';

  @override
  String get searchOpen => 'Open';

  @override
  String get searchFilterBy => 'Filter by';

  @override
  String get searchFilterOwner => 'Owner';

  @override
  String get searchFilterDate => 'Date';

  @override
  String get searchFilterType => 'Type';

  @override
  String get searchFilterArchived => 'Archived';

  @override
  String get searchFilterActions => 'Actions';

  @override
  String get searchOwnerMe => 'Me';

  @override
  String get searchOwnerShared => 'Shared with me';

  @override
  String get searchActionsHint => 'Search actions';

  @override
  String get searchCmdAllChats => 'All chats';

  @override
  String get searchCmdToggleSidebar => 'Toggle sidebar';

  @override
  String get toolbarBack => 'Back';

  @override
  String get toolbarForward => 'Forward';

  @override
  String get menuFile => 'File';

  @override
  String get menuEdit => 'Edit';

  @override
  String get menuView => 'View';

  @override
  String get menuHelp => 'Help';

  @override
  String get editUndo => 'Undo';

  @override
  String get editRedo => 'Redo';

  @override
  String get editCut => 'Cut';

  @override
  String get editCopy => 'Copy';

  @override
  String get editPaste => 'Paste';

  @override
  String get editSelectAll => 'Select all';

  @override
  String get railMore => 'More';

  @override
  String get railImages => 'Images';

  @override
  String get railTasks => 'Scheduled tasks';

  @override
  String get railLibrary => 'Library';

  @override
  String get imagesTabHot => 'Popular';

  @override
  String get imagesTabTemplates => 'Templates';

  @override
  String get libraryTabRecommended => 'Recommended';

  @override
  String get libraryTabFavorites => 'Favorites';

  @override
  String get libraryTabFolders => 'Folders';

  @override
  String get libraryTabImages => 'Images';

  @override
  String get libraryTabAll => 'All';

  @override
  String get tasksNew => 'New task';

  @override
  String get tasksUpcoming => 'Upcoming';

  @override
  String get tasksEmpty => 'No tasks scheduled';

  @override
  String get menuNewWindow => 'New window';

  @override
  String get menuNewProject => 'New project...';

  @override
  String get menuOpenFolder => 'Open folder';

  @override
  String get menuClose => 'Close';

  @override
  String menuQuitBrand(String brand) {
    return 'Quit $brand';
  }

  @override
  String get editDelete => 'Delete';

  @override
  String get menuToggleSidebar => 'Show/hide sidebar';

  @override
  String get menuOpenTerminal => 'Open terminal';

  @override
  String get menuSwitchChatTabs => 'Switch between chat and tabs';

  @override
  String get menuBrowser => 'Browser';

  @override
  String get menuFind => 'Find';

  @override
  String get menuZoomIn => 'Zoom in';

  @override
  String get menuZoomOut => 'Zoom out';

  @override
  String get menuActualSize => 'Actual size';

  @override
  String get menuFullScreen => 'Toggle full screen';

  @override
  String get helpDocs => 'Documentation';

  @override
  String get helpWhatsNew => 'What\'s new';

  @override
  String get helpTroubleshoot => 'Troubleshooting';

  @override
  String get helpSystemStatus => 'System status';

  @override
  String get helpFeedback => 'Feedback';

  @override
  String get helpTaskManager => 'Task manager';

  @override
  String get helpStartTrace => 'Start performance trace';

  @override
  String get helpCheckUpdates => 'Check for updates...';
}
