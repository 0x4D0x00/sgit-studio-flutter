import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sgit_studio_flutter/design/tokens/composer_metrics.dart';
import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/model_list_controller.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/model_selector.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/memory/memory_disable_dialog.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/router/route_names.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_action_icon.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_control_button.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_model_label.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 空态右下的模型名。数据与 [ModelSelector] 同源，只是长相不同。
class ComposerModelMenu extends ConsumerWidget {
  const ComposerModelMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final s = ref.watch(modelListProvider);
    final selected = ref.watch(
      composerSettingsProvider.select((x) => x.settings.selectedModel),
    );
    final notifier = ref.read(composerSettingsProvider.notifier);
    // 用 effective 而不是 find：没选过时显示并勾中**列表第一个**，与发送用的同一个。
    final current = s.effective(selected);

    return AppMenuAnchor(
      enabled: !s.isEmpty,
      semanticLabel: l10n.modelSelector,
      align: AppMenuAlign.above,
      minWidth: 260,
      maxWidth: 340,
      maxHeight: 420,
      entries: [
        // 只列真实模型，**没有「默认模型」这一项**。勾的是实际会用的那个：
        // 选过的，否则列表第一个。
        for (final g in s.groups) ...[
          AppMenuLabel(g.name),
          for (final m in g.models)
            AppMenuAction(
              label: m.displayName,
              trailingValue: m.contextWindow == null
                  ? null
                  : l10n.relayContextWindow(m.contextWindow!),
              checked: m.id == current?.id,
              onTap: () => notifier.setSelectedModel(m.id),
            ),
        ],
      ],
      child: ComposerModelLabel(
        loading: s.loading,
        semanticLabel: l10n.modelSelector,
        displayName: switch ((s.loading, s.isEmpty, current)) {
          (true, _, _) => l10n.commonLoading,
          (_, true, _) => l10n.modelSelectorNone,
          (_, _, final m?) => m.displayName,
          _ => l10n.modelSelectorNone,
        },
        // ⚠️ 不传 onTap：AppMenuAnchor 已在外面套了 InkWell 负责开合。
        // 再套一层内层会先命中、吃掉点击 —— 菜单永远打不开且看不出异常。
        enabled: !s.isEmpty,
      ),
    );
  }
}

/// `+` 菜单。**内容全是 sgcode 真有的能力**。
///
/// 技能 / 知识库是**跳转**而不是在菜单里列出来：本机技能可能上千个
/// （见 `settings_repository_io.dart:42` 记的那次界面冻住），把它们塞进一个
/// 输入框菜单必然重演。studio 页自己有分页与懒加载，交给它。
class ComposerPlusMenu extends ConsumerWidget {
  const ComposerPlusMenu({
    super.key,
    required this.settings,
    required this.onPickFile,
  });

  final ComposerSettings settings;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(composerSettingsProvider.notifier);

    return AppMenuAnchor(
      align: AppMenuAlign.above,
      semanticLabel: l10n.chatAddMenu,
      entries: [
        AppMenuAction(
          icon: Icons.attach_file,
          label: l10n.chatAttachFiles,
          onTap: () => onPickFile(),
        ),
        const AppMenuDivider(),
        AppMenuSwitch(
          icon: Icons.public,
          label: l10n.chatWebSearch,
          value: settings.webSearch.enabled,
          onChanged: (_) => notifier.toggleWebSearch(),
        ),
        AppMenuSwitch(
          icon: Icons.psychology_outlined,
          label: l10n.chatMemory,
          value: settings.memoryEnabled,
          // 关闭要先确认（暂停 / 重置），与设置弹窗同一入口；开启直接落盘。
          onChanged: (on) => on
              ? notifier.setMemoryEnabled(true)
              : requestDisableMemory(context, ref),
        ),
        const AppMenuDivider(),
        AppMenuAction(
          icon: Icons.extension_outlined,
          label: l10n.chatSkills,
          onTap: () => context.go(RouteNames.studio('skill')),
        ),
        AppMenuAction(
          icon: Icons.library_books_outlined,
          label: l10n.chatKnowledge,
          onTap: () => context.go(RouteNames.studio('knowledge')),
        ),
        AppMenuAction(
          icon: Icons.hub_outlined,
          label: l10n.chatAgentGateway,
          onTap: () => context.go(RouteNames.studio('llm-relay')),
        ),
      ],
      // ⚠️ 不传 onTap —— 点击由 AppMenuAnchor 处理，见 ComposerActionIcon 的类注释。
      child: ComposerActionIcon(icon: Icons.add, tooltip: l10n.chatAddMenu),
    );
  }
}

/// 审批策略 —— sgcode 原生四档。
///
/// 选中 granular 时把 5 个子开关**展开在同一个菜单里**（studio 同款）：
/// 让人选完档位再去别处找子开关，多半找不到。
class ComposerApprovalMenu extends ConsumerWidget {
  const ComposerApprovalMenu({super.key, required this.current});

  final ApprovalPolicy current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(composerSettingsProvider.notifier);
    final granular = switch (current) {
      GranularApproval(:final config) => config,
      _ => const GranularApprovalConfig(),
    };

    AppMenuRichAction row(
      ApprovalPolicy policy,
      IconData icon,
      String title,
      String desc,
    ) => AppMenuRichAction(
      icon: icon,
      title: title,
      description: desc,
      checked: current.runtimeType == policy.runtimeType,
      onTap: () => notifier.setApprovalPolicy(policy),
    );

    return AppMenuAnchor(
      align: AppMenuAlign.above,
      semanticLabel: l10n.chatApprovalPolicy,
      minWidth: ComposerMetrics.popoverMinWidth,
      maxWidth: ComposerMetrics.popoverMaxWidth,
      entries: [
        row(
          const OnRequestApproval(),
          Icons.back_hand_outlined,
          l10n.chatApprovalOnRequest,
          l10n.chatApprovalOnRequestDesc,
        ),
        row(
          const UntrustedApproval(),
          Icons.verified_user_outlined,
          l10n.chatApprovalUntrusted,
          l10n.chatApprovalUntrustedDesc,
        ),
        row(
          const NeverApproval(),
          Icons.bolt_outlined,
          l10n.chatApprovalNever,
          l10n.chatApprovalNeverDesc,
        ),
        row(
          GranularApproval(granular),
          Icons.checklist_outlined,
          l10n.chatApprovalGranular,
          l10n.chatApprovalGranularDesc,
        ),
        if (current is GranularApproval) ...[
          const AppMenuDivider(),
          for (final f in GranularApprovalConfig.fields)
            AppMenuSwitch(
              label: _granularLabel(l10n, f),
              value: granular.valueOf(f),
              onChanged: (v) => notifier.setApprovalPolicy(
                GranularApproval(granular.withField(f, v)),
              ),
            ),
        ],
      ],
      child: ComposerActionIcon(
        icon: _approvalIcon(current),
        tooltip: l10n.chatApprovalPolicy,
        // 非默认档时点亮 —— 「从不询问」这种档位悄悄开着很危险，
        // 图标必须看得出来"我改过设置"。
        active: current is! OnRequestApproval,
      ),
    );
  }

  static IconData _approvalIcon(ApprovalPolicy p) => switch (p) {
    OnRequestApproval() => Icons.back_hand_outlined,
    UntrustedApproval() => Icons.verified_user_outlined,
    NeverApproval() => Icons.bolt_outlined,
    GranularApproval() => Icons.checklist_outlined,
  };

  static String _granularLabel(AppLocalizations l10n, GranularField f) =>
      switch (f) {
        GranularField.sandboxApproval => l10n.chatApprovalFieldSandbox,
        GranularField.rules => l10n.chatApprovalFieldRules,
        GranularField.skillApproval => l10n.chatApprovalFieldSkill,
        GranularField.requestPermissions => l10n.chatApprovalFieldPermissions,
        GranularField.mcpElicitations => l10n.chatApprovalFieldMcp,
      };
}

/// 引擎模式选择器（本地 / 云端）。
class ComposerEngineMenu extends ConsumerWidget {
  const ComposerEngineMenu({super.key, required this.current});

  final EngineMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(composerSettingsProvider.notifier);

    return AppMenuAnchor(
      align: AppMenuAlign.above,
      semanticLabel: l10n.chatEngineMode,
      minWidth: 200,
      entries: [
        AppMenuAction(
          icon: Icons.computer_outlined,
          label: l10n.chatEngineModeLocal,
          checked: current == EngineMode.local,
          onTap: () => _switchEngine(ref, notifier, EngineMode.local),
        ),
        AppMenuAction(
          icon: Icons.cloud_outlined,
          label: l10n.chatEngineModeRemote,
          checked: current == EngineMode.remote,
          onTap: () => _switchEngine(ref, notifier, EngineMode.remote),
        ),
      ],
      child: ComposerActionIcon(
        icon: _engineModeIcon(current),
        tooltip: l10n.chatEngineMode,
        // 非默认值时高亮
        active: current != EngineMode.defaults,
      ),
    );
  }

  static IconData _engineModeIcon(EngineMode m) => switch (m) {
    EngineMode.local => Icons.computer_outlined,
    EngineMode.remote => Icons.cloud_outlined,
  };

  /// 切引擎 = 改设置 **+ 重新建连**。
  ///
  /// ⚠️ 少了重连这一步，切换就是个摆设：页面初始化时早已用默认模式连上，
  /// 而 `connect()` 幂等、不会重建。用户以为切到云端了，实际还在本地引擎上跑
  /// —— 两条路的帧、动作、界面完全一样，**从表现上看不出来**（实测踩过：
  /// 选了云端发消息，回答其实是本地引擎给的）。
  void _switchEngine(
    WidgetRef ref,
    ComposerSettingsController notifier,
    EngineMode next,
  ) {
    if (!notifier.setEngineMode(next)) return; // 没变就不折腾连接
    unawaited(ref.read(chatControllerProvider.notifier).reconnectWithMode());
  }
}

class ComposerSandboxMenu extends ConsumerWidget {
  const ComposerSandboxMenu({super.key, required this.current});

  final SandboxMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(composerSettingsProvider.notifier);

    return AppMenuAnchor(
      align: AppMenuAlign.above,
      semanticLabel: l10n.chatSandboxMode,
      minWidth: ComposerMetrics.popoverMinWidth,
      maxWidth: ComposerMetrics.popoverMaxWidth,
      entries: [
        for (final m in SandboxMode.values)
          AppMenuRichAction(
            icon: _sandboxIcon(m),
            title: _sandboxLabel(l10n, m),
            description: _sandboxDesc(l10n, m),
            checked: m == current,
            onTap: () => notifier.setSandboxMode(m),
          ),
      ],
      child: ComposerControlButton(
        icon: _sandboxIcon(current),
        label: _sandboxLabel(l10n, current),
      ),
    );
  }

  static IconData _sandboxIcon(SandboxMode m) => switch (m) {
    SandboxMode.readOnly => Icons.lock_outline,
    SandboxMode.workspaceWrite => Icons.edit_outlined,
    SandboxMode.dangerFullAccess => Icons.lock_open_outlined,
  };

  static String _sandboxLabel(AppLocalizations l10n, SandboxMode m) =>
      switch (m) {
        SandboxMode.readOnly => l10n.chatSandboxReadOnly,
        SandboxMode.workspaceWrite => l10n.chatSandboxWorkspaceWrite,
        SandboxMode.dangerFullAccess => l10n.chatSandboxDangerFullAccess,
      };

  static String _sandboxDesc(AppLocalizations l10n, SandboxMode m) =>
      switch (m) {
        SandboxMode.readOnly => l10n.chatSandboxReadOnlyDesc,
        SandboxMode.workspaceWrite => l10n.chatSandboxWorkspaceWriteDesc,
        SandboxMode.dangerFullAccess => l10n.chatSandboxDangerFullAccessDesc,
      };
}

class ComposerEffortMenu extends ConsumerWidget {
  const ComposerEffortMenu({super.key, required this.current});

  final ReasoningEffort current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(composerSettingsProvider.notifier);

    return AppMenuAnchor(
      align: AppMenuAlign.above,
      semanticLabel: l10n.chatReasoningEffort,
      entries: [
        AppMenuRadioGroup<ReasoningEffort>(
          values: ReasoningEffort.values,
          selected: current,
          labelOf: (e) => _effortLabel(l10n, e),
          onSelect: notifier.setReasoningEffort,
        ),
      ],
      child: ComposerControlButton(
        icon: Icons.speed_outlined,
        label: _effortLabel(l10n, current),
      ),
    );
  }

  static String _effortLabel(AppLocalizations l10n, ReasoningEffort e) =>
      switch (e) {
        ReasoningEffort.none => l10n.chatEffortNone,
        ReasoningEffort.minimal => l10n.chatEffortMinimal,
        ReasoningEffort.low => l10n.chatEffortLow,
        ReasoningEffort.medium => l10n.chatEffortMedium,
        ReasoningEffort.high => l10n.chatEffortHigh,
        ReasoningEffort.xhigh => l10n.chatEffortXhigh,
        ReasoningEffort.max => l10n.chatEffortMax,
        ReasoningEffort.ultra => l10n.chatEffortUltra,
      };
}
