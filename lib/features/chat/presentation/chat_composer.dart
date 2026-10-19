import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/design/tokens/composer_metrics.dart';
import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/model_list_controller.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/model_selector.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/router/route_names.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/services/layout/transcript_width.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_action_icon.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_attachment_chip.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_control_bar.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_control_button.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_model_label.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_send_button.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_shell.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/orbit_beam.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_token_tag.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 输入框所处的形态。
///
/// sgit-studio 对这两处用的是**两套**动作栏配置（首页
/// `leftActions: ['plus','approvalPolicy','skillTag']` + `rightActions: ['modelLabel']`；
/// 会话页 `leftActions: ['model','plus','approvalPolicy']`），我们照搬。
///
/// ⚠️ 这里以前是个 `bool showModelInside`，但两态的差别**不止**模型位置：
/// 编辑区最小高度、能不能拖拽、动作栏放什么、底下有没有控制条，全都不同。
/// bool 表达不了四个维度，且违反「能 switch 绝不 if-elif」。
enum ComposerVariant {
  /// 空态（还没开聊）。编辑区更高、没有控制条 —— 此刻输入框是页面主角。
  empty,

  /// 会话态。编辑区收窄、可拖拽、底下挂控制条。
  conversation,
}

/// 输入区 —— 1:1 复刻 sgit-studio 的 ChatInput（外观），能力对接 sgcode（内核）。
///
/// ## 三个状态，全靠 `busy` 一个字段切
///
/// | 状态 | 提示语 | 右侧按钮 |
/// |---|---|---|
/// | 空闲 | 有什么可以帮你的？ | 发送 |
/// | 跑着（有内容）| 插话改方向… | 插话（steer，**不打断**）|
/// | 跑着（空）| 插话改方向… | 停止（interrupt）|
///
/// **steer 与 stop 是两件事**，别合成一个按钮：引擎里 `turn/steer` 是把新指示并进
/// 当前 turn（不重来），`turn/interrupt` 是掐掉。合并了用户就没法"补一句话继续跑"。
///
/// ## 这里**没有**什么
///
/// studio 输入框上还挂着「对话/智能模式」「执行设备」「工作目录」「Git 状态」
/// 「参数面板」——那些是 lobe 自己的产品概念，存在它的 agent config 里，
/// **sgcode 没有对应物**，所以一个都不抄。要表达"这轮能做多狠"，sgcode 的答案是
/// [SandboxMode]；要表达"想多深"，是 [ReasoningEffort]。控制条放的就是这两个。
/// 回车发送的意图。
///
/// 存在的唯一理由：`TextField(maxLines: null)` 的 `textInputAction` 默认是
/// `newline`，回车会被它吃掉换成换行，`onSubmitted` 不触发。所以自己在
/// `Shortcuts` 里把 Enter 映射成这个意图，再在 `Actions` 里转去提交。
class _SendIntent extends Intent {
  const _SendIntent();
}

class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({super.key, required this.variant});

  final ComposerVariant variant;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  /// 发送后沿输入框跑一圈的光。详见 [OrbitBeam]。
  bool _beamActive = false;

  final _ctl = TextEditingController();
  final _focus = FocusNode();

  // ⚠️ 选中的模型**不在这里** —— 它住在 `composerSettingsProvider`。
  //
  // 空态与会话态是 `workspace_page.dart` 里三元切换出来的**两棵不同子树**，
  // 发第一条消息时这个 State 会被销毁重建。模型选择放在私有字段里活不过那一下，
  // 表现就是"L1 选好的模型，进 L2 变回默认"。

  /// 已选择的附件。
  final List<PlatformFile> _attachments = [];

  /// 用户拖拽指定的编辑区高度。null = 跟着内容自适应。
  ///
  /// 只有 [ComposerVariant.conversation] 会用到（studio 那边 `resize` 在空态是
  /// `false`）—— 空态本来就给足了高度，再让人拖没有意义。
  double? _draggedHeight;

  @override
  void initState() {
    super.initState();
    // 用 controller 监听而不是 TextField.onChanged：`_ctl.clear()` 这种**程序化**改动
    // 也要触发重建，否则 steer 之后按钮不会从「插话」切回「停止」（被 UI 测试抓到过）。
    _ctl.addListener(_onTextChanged);
  }

  /// 首次挂载时如果**本轮已经在跑**，补一次光。
  ///
  /// 对应 studio `Conversation/ChatInput/index.tsx:338-345` 的「挂载时补播」：
  /// 空态发出首条消息后，`workspace_page` 会把整棵空态子树换成会话态子树，
  /// 刚起跑的光随 `_beamActive` 一起销毁 —— **最常见的那条路径上反而看不到光**。
  ///
  /// 放在 `didChangeDependencies` 而不是 `initState`：要读 `MediaQuery`
  /// 判断系统"减弱动态效果"，那时 `initState` 里还拿不到。
  bool _mountBeamChecked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_mountBeamChecked) return;
    _mountBeamChecked = true;
    final animationsOff = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (animationsOff) return;
    if (ref.read(chatControllerProvider).busy) {
      setState(() => _beamActive = true);
    }
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _ctl.removeListener(_onTextChanged);
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ---- 附件 ----

  Future<void> _pick(FileType type) async {
    final l10n = AppLocalizations.of(context);
    try {
      final result = await FilePicker.pickFiles(type: type);
      if (result.isNotEmpty) setState(() => _attachments.addAll(result));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatPickFileFailed(e.toString()))),
      );
    }
  }

  void _removeAttachment(int index) =>
      setState(() => _attachments.removeAt(index));

  // ---- 发送 ----

  void _submit(ChatController ctrl, bool busy) {
    final text = _ctl.text.trim();
    if (text.isEmpty) {
      if (busy) ctrl.interrupt();
      return;
    }
    // 跑着的时候提交 = 插话；空闲时提交 = 新一轮。
    //
    // 模型规则：用户选的 → 否则模型列表第一个 → 列表为空则拒绝发送
    // （`ChatController.send` 收到空模型会拒）。**永远由这里定好再下发**，
    // 不下发 null 让引擎自己兜底。`effective` 与选择器显示的是同一个。
    final model = ref
        .read(modelListProvider)
        .effective(ref.read(composerSettingsProvider).settings.selectedModel)
        ?.id;
    final accepted = busy ? ctrl.steer(text) : ctrl.send(text, model: model);
    // ⚠️ **只在受理后才清空**。被拒时保留用户输入，让他改完能直接重发。
    if (accepted) {
      _ctl.clear();
      // 一次性装饰反馈：从"消息被受理"这一刻起跑。
      // 被拒（没模型 / 未连接 / busy）时**不跑** —— 那会给出"已发送"的错误暗示。
      // 同理，系统关掉动态效果时也不点这一下。
      final animationsOff = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (!_beamActive && !animationsOff) setState(() => _beamActive = true);
    }
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // 只订阅用得到的字段，不整块 watch。
    final busy = ref.watch(chatControllerProvider.select((s) => s.busy));
    final ctrl = ref.read(chatControllerProvider.notifier);

    // 系统的「减弱动态效果」= studio 的 `disableAnimation`。
    final animationsOff = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // 引擎设置写失败要让用户知道 —— 静默失败的开关比没有开关更糟（用户以为设上了）。
    ref.listen(composerSettingsProvider.select((s) => s.error), (_, err) {
      if (err == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.chatSettingWriteFailed(err))),
      );
      ref.read(composerSettingsProvider.notifier).clearError();
    });

    return Center(
      child: ConstrainedBox(
        // 宽度跟着设置页的「转录宽度」档走，与正文列同源 —— 外壳那层的 `Center`
        // 只负责居中，宽度上限在这里。写死 768 的话，宽档下输入框会比正文窄
        // 一截，窄档下又会比正文宽出去。
        constraints: BoxConstraints(
            maxWidth: ref.watch(transcriptWidthProvider).composerWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statsLine(l10n),
            // 发送反馈：受理消息那一刻起跑一圈光，跑完就消失。
            // 与 studio 的 `OrbitBeam` 同一语义 —— 是**一次性**装饰，
            // 不表示"正在生成"，所以不跟 busy 绑。
            OrbitBeam(
              // 系统关掉动态效果时整道不画（studio 的 `disableAnimation`）。
              // 只在这里判、不去 setState 清 `_beamActive` —— 开关再打开时
              // 光还能正常跑，不需要额外状态。
              active: _beamActive && !animationsOff,
              borderRadius: ComposerMetrics.shellRadius,
              onComplete: () {
                if (mounted) setState(() => _beamActive = false);
              },
              child: ComposerShell(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_attachments.isNotEmpty) _attachmentArea(l10n),
                    if (widget.variant == ComposerVariant.conversation)
                      _resizeHandle(),
                    _editor(l10n, busy, ctrl),
                    const SizedBox(height: ComposerMetrics.actionBarGapTop),
                    _actionBar(l10n, busy, ctrl),
                  ],
                ),
              ),
            ),
            if (widget.variant == ComposerVariant.conversation)
              _bottomRow(l10n),
          ],
        ),
      ),
    );
  }

  // ---- 上一轮的用量与耗时 ----

  /// 输入框**上方**的那行小字。
  ///
  /// studio 没有这一行（它把用量塞进 token 标签的悬浮卡里），但我们保留 ——
  /// 它显示的是**上一轮的成本与延迟**，和控制条上那个"上下文还剩多少"是两回事，
  /// 后者替代不了前者。位置也维持原样，免得老用户找不到。
  ///
  /// 数字全部是内核算好的，我们只显示，不重算。
  Widget _statsLine(AppLocalizations l10n) {
    final skin = AppSkin.of(context);
    final usage = ref.watch(chatControllerProvider.select((s) => s.lastUsage));
    final timing = ref.watch(chatControllerProvider.select((s) => s.lastTiming));
    if (usage == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Text(
        l10n.chatStats(
          usage.inputTokens,
          usage.outputTokens,
          timing?.durationMs ?? 0,
        ),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: skin.textTertiary),
      ),
    );
  }

  // ---- 头部：附件 ----

  Widget _attachmentArea(AppLocalizations l10n) => Padding(
        padding: const EdgeInsets.only(
          left: ComposerMetrics.attachmentAreaPaddingInline,
          right: ComposerMetrics.attachmentAreaPaddingInline,
          bottom: AppSpacing.xs,
        ),
        child: Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (index, file) in _attachments.indexed)
              ComposerAttachmentChip(
                name: file.name,
                isImage: _isImage(file),
                removeSemanticLabel: l10n.chatRemoveAttachment,
                onRemove: () => _removeAttachment(index),
              ),
          ],
        ),
      );

  static const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'};

  static bool _isImage(PlatformFile f) =>
      _imageExts.contains(f.extension?.toLowerCase());

  // ---- 拖拽把手 ----

  /// 顶边的拖拽区（studio 的 `resize={true}`）。往上拖变高。
  ///
  /// 没有可见的把手条 —— studio 那边也没有，靠鼠标指针变形提示。
  /// 画一根横线反而会被误读成"这里是分隔符"。
  Widget _resizeHandle() => MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragUpdate: (d) {
            setState(() {
              final base = _draggedHeight ??
                  ComposerMetrics.editorMinHeightConversation;
              // 往上拖（dy 为负）= 变高，所以减。
              _draggedHeight = (base - d.delta.dy).clamp(
                ComposerMetrics.editorMinHeightConversation,
                ComposerMetrics.editorMaxHeight,
              );
            });
          },
          child: const SizedBox(
            height: ComposerMetrics.editorResizeHandleHeight,
            width: double.infinity,
          ),
        ),
      );

  // ---- 编辑区 ----

  Widget _editor(AppLocalizations l10n, bool busy, ChatController ctrl) {
    final skin = AppSkin.of(context);
    final minHeight = switch (widget.variant) {
      ComposerVariant.empty => ComposerMetrics.editorMinHeightEmpty,
      ComposerVariant.conversation =>
        _draggedHeight ?? ComposerMetrics.editorMinHeightConversation,
    };
    // 拖拽指定高度后就**钉死**（不再随内容长高）—— 用户明确表达过想要多高。
    final maxHeight = _draggedHeight ?? ComposerMetrics.editorMaxHeight;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
      // ⚠️ **回车发送必须自己拦键，不能靠 `onSubmitted`。**
      //
      // `maxLines: null` 的多行 TextField 在 Flutter 里的 `textInputAction`
      // 默认是 `newline`，回车被它当场吃掉换成换行，`onSubmitted` **根本不会触发**
      // —— 表现就是"按回车毫无反应，字还留在框里"。
      //
      // 这里用 `Shortcuts` 把 Enter / 小键盘 Enter 映射成一个自有意图，
      // 再在 `Actions` 里转去 `_submit`。Shift+Enter 仍然保留为换行（多行编辑的
      // 常规约定），不拦截它。
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): _SendIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): _SendIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _SendIntent: CallbackAction<_SendIntent>(
              onInvoke: (_) {
                _submit(ctrl, busy);
                return null;
              },
            ),
          },
          child: TextField(
            controller: _ctl,
            focusNode: _focus,
            maxLines: null,
            // 保留它作为兜底（单行输入法 / 无障碍输入会走这条）。
            onSubmitted: (_) => _submit(ctrl, busy),
            // ⚠️ 不能用 InputDecoration.collapsed：它不设 filled，会继承全局
            // inputDecorationTheme 的 filled+fillColor+border，在玻璃框里
            // 又套出一个灰底输入框。这里逐项显式关掉。
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: busy ? l10n.chatSteerHint : l10n.workspaceInputHint,
              hintStyle: TextStyle(color: skin.textTertiary),
            ),
          ),
        ),
      ),
    );
  }

  // ---- 动作栏 ----

  Widget _actionBar(AppLocalizations l10n, bool busy, ChatController ctrl) {
    final hasText = _ctl.text.trim().isNotEmpty;
    final settings =
        ref.watch(composerSettingsProvider.select((s) => s.settings));

    final (mode, tooltip, enabled) = switch ((busy, hasText)) {
      (true, false) => (ComposerSendMode.stop, l10n.chatStop, true),
      (true, true) => (ComposerSendMode.steer, l10n.chatSteerHint, true),
      (false, final has) =>
        (ComposerSendMode.send, l10n.workspaceSend, has),
    };

    return Padding(
      padding: const EdgeInsets.only(
        left: ComposerMetrics.actionBarPaddingStart,
        right: ComposerMetrics.actionBarPaddingEnd,
      ),
      child: Row(
        children: [
          _plusMenu(l10n, settings),
          _approvalMenu(l10n, settings.approvalPolicy),
          _engineModeMenu(l10n, settings.engineMode),
          const Spacer(),
          if (widget.variant == ComposerVariant.empty) ...[
            _modelLabel(l10n),
            const SizedBox(width: ComposerMetrics.sendAreaGap),
          ],
          ComposerSendButton(
            mode: mode,
            tooltip: tooltip,
            onPressed: enabled ? () => _submit(ctrl, busy) : null,
          ),
        ],
      ),
    );
  }

  /// 空态右下的模型名。数据与 [ModelSelector] 同源，只是长相不同。
  Widget _modelLabel(AppLocalizations l10n) {
    final s = ref.watch(modelListProvider);
    final selected =
        ref.watch(composerSettingsProvider.select((x) => x.settings.selectedModel));
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

  /// `+` 菜单。**内容全是 sgcode 真有的能力**。
  ///
  /// 技能 / 知识库是**跳转**而不是在菜单里列出来：本机技能可能上千个
  /// （见 `settings_repository_io.dart:42` 记的那次界面冻住），把它们塞进一个
  /// 输入框菜单必然重演。studio 页自己有分页与懒加载，交给它。
  Widget _plusMenu(AppLocalizations l10n, ComposerSettings settings) {
    final notifier = ref.read(composerSettingsProvider.notifier);

    return AppMenuAnchor(
      align: AppMenuAlign.above,
      semanticLabel: l10n.chatAddMenu,
      entries: [
        AppMenuAction(
          icon: Icons.attach_file,
          label: l10n.chatAttachFiles,
          onTap: () => _pick(FileType.any),
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
          onChanged: notifier.setMemoryEnabled,
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
      child: ComposerActionIcon(
        icon: Icons.add,
        tooltip: l10n.chatAddMenu,
      ),
    );
  }

  /// 审批策略 —— sgcode 原生四档。
  ///
  /// 选中 granular 时把 5 个子开关**展开在同一个菜单里**（studio 同款）：
  /// 让人选完档位再去别处找子开关，多半找不到。
  Widget _approvalMenu(AppLocalizations l10n, ApprovalPolicy current) {
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
    ) =>
        AppMenuRichAction(
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

  /// 引擎模式选择器（本地 / 云端）。
  Widget _engineModeMenu(AppLocalizations l10n, EngineMode current) {
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
          onTap: () => _switchEngine(notifier, EngineMode.local),
        ),
        AppMenuAction(
          icon: Icons.cloud_outlined,
          label: l10n.chatEngineModeRemote,
          checked: current == EngineMode.remote,
          onTap: () => _switchEngine(notifier, EngineMode.remote),
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
    ComposerSettingsController notifier,
    EngineMode next,
  ) {
    if (!notifier.setEngineMode(next)) return; // 没变就不折腾连接
    unawaited(ref.read(chatControllerProvider.notifier).reconnectWithMode());
  }

  static String _granularLabel(AppLocalizations l10n, GranularField f) =>
      switch (f) {
        GranularField.sandboxApproval => l10n.chatApprovalFieldSandbox,
        GranularField.rules => l10n.chatApprovalFieldRules,
        GranularField.skillApproval => l10n.chatApprovalFieldSkill,
        GranularField.requestPermissions => l10n.chatApprovalFieldPermissions,
        GranularField.mcpElicitations => l10n.chatApprovalFieldMcp,
      };

  // ---- 控制条 ----

  Widget _controlBar(AppLocalizations l10n) {
    final settings =
        ref.watch(composerSettingsProvider.select((s) => s.settings));
    final usage = ref.watch(chatControllerProvider.select((s) => s.lastUsage));
    final models = ref.watch(modelListProvider);

    final used = usage?.totalTokens ?? 0;
    // ⚠️ 用 effective 而不是 find：没选过模型时 find 返回 null → maxTokens 为 0
    // → `ComposerTokenTag.shouldShow` 恒为 false → **上下文窗口条永远不出现**。
    // 引擎实际用的是列表第一个，窗口大小也该按它算。
    final maxTokens =
        models.effective(settings.selectedModel)?.contextWindow ?? 0;

    return ComposerControlBar(
      leading: [
        _sandboxMenu(l10n, settings.sandboxMode),
        _effortMenu(l10n, settings.reasoningEffort),
      ],
      trailing: [
        // 占用不到一半时整个不画 —— 还剩一大半的时候这个数字没有决策价值，
        // 常驻只会让人焦虑（studio 同款判断）。
        if (ComposerTokenTag.shouldShow(used: used, max: maxTokens))
          ComposerTokenTag(
            used: used,
            max: maxTokens,
            tooltip: l10n.chatContextWindowDetail(used, maxTokens),
          ),
      ],
    );
  }

  Widget _sandboxMenu(AppLocalizations l10n, SandboxMode current) {
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

  Widget _effortMenu(AppLocalizations l10n, ReasoningEffort current) {
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

  // ---- 底部行（会话态）：控制条 + 模型选择器 ----

  Widget _bottomRow(AppLocalizations l10n) {
    final settings =
        ref.watch(composerSettingsProvider.select((s) => s.settings));

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _controlBar(l10n)),
          const SizedBox(width: AppSpacing.xs),
          ModelSelector(
            selected: settings.selectedModel,
            onChanged: (m) => ref
                .read(composerSettingsProvider.notifier)
                .setSelectedModel(m),
          ),
        ],
      ),
    );
  }
}
