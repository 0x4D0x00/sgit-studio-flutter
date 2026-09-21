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
  String get navSearchDialogHint => 'Search chats';

  @override
  String get navSearchDialogEmpty => 'No matching chats found';

  @override
  String get navNewChat => 'New chat';

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
  String get chatAttachFiles => 'Attachments';

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
  String get modelSelectorDefault => 'Default model';

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
  String get settingsResetDefault => 'Reset to default';

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
  String get chatNoTurnToSteer => 'No turn in progress to steer';

  @override
  String get chatKernelStalled =>
      'The kernel stopped responding — input re-enabled';

  @override
  String get artifactsTitle => 'Artifacts';

  @override
  String get artifactsEmpty => 'No artifacts yet';

  @override
  String get artifactsSearch => 'Search artifacts';

  @override
  String get artifactsSearchHint => 'Search by title';

  @override
  String get artifactsSearchClose => 'Close search';

  @override
  String get artifactsRange => 'Time range';

  @override
  String get artifactsRangeToday => 'Today';

  @override
  String get artifactsRangeWeek => 'This week';

  @override
  String get artifactsRangeMonth => 'This month';

  @override
  String get artifactsRangeYear => 'This year';

  @override
  String get artifactsRangeAll => 'All';

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
  String get customizeSearchHint => 'Search skills...';
}
