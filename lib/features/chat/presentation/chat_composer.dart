import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/composer_metrics.dart';
import 'package:sgit_studio_flutter/domain/models/chat/message_quotes.dart';
import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_focus_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_quotes_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/transcript_selection_pin.dart';
import 'package:sgit_studio_flutter/features/chat/application/model_list_controller.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/composer/composer_menus.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/composer/composer_sections.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/services/layout/transcript_width.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_send_button.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_shell.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/orbit_beam.dart';
import 'package:sgit_studio_flutter/services/chat/workspace_mode.dart';

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
  final _focus = PinnableFocusNode(composerSelectionPin);

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
    composerSelectionPin.node = _focus;
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
    if (composerSelectionPin.node == _focus) {
      composerSelectionPin.value = false;
      composerSelectionPin.node = null;
    }
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
    // 引用拼在正文前面一起发出（格式见 [MessageQuotes]）。
    final quotes = ref.read(composerQuotesProvider);
    final payload = MessageQuotes.encode(quotes, text);
    final accepted = busy
        ? ctrl.steer(payload)
        : ctrl.send(payload, model: model);
    // ⚠️ **只在受理后才清空**。被拒时保留用户输入，让他改完能直接重发。
    if (accepted) {
      _ctl.clear();
      ref.read(composerQuotesProvider.notifier).clear();
      // 一次性装饰反馈：从"消息被受理"这一刻起跑。
      // 被拒（没模型 / 未连接 / busy）时**不跑** —— 那会给出"已发送"的错误暗示。
      // 同理，系统关掉动态效果时也不点这一下。
      final animationsOff =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
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
    final quotes = ref.watch(composerQuotesProvider);

    // 系统的「减弱动态效果」= studio 的 `disableAnimation`。
    final animationsOff = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    // 别处（搜索弹窗的 Tab）请求把光标送到输入框。只认计数变化，
    // 挂载时不会凭空抢一次焦点。
    ref.listen(composerFocusProvider, (prev, next) {
      if (prev == null || next <= prev) return;
      _focus.requestFocus();
    });

    // 引擎设置写失败要让用户知道 —— 静默失败的开关比没有开关更糟（用户以为设上了）。
    ref.listen(composerSettingsProvider.select((s) => s.error), (_, err) {
      if (err == null || !mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.chatSettingWriteFailed(err))));
      ref.read(composerSettingsProvider.notifier).clearError();
    });

    return Center(
      child: ConstrainedBox(
        // 宽度跟着设置页的「转录宽度」档走，与正文列同源 —— 外壳那层的 `Center`
        // 只负责居中，宽度上限在这里。写死 768 的话，宽档下输入框会比正文窄
        // 一截，窄档下又会比正文宽出去。
        constraints: BoxConstraints(
          maxWidth: ref.watch(transcriptWidthProvider).composerWidth,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ComposerStatsLine(),
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
                    if (_attachments.isNotEmpty || quotes.isNotEmpty)
                      ComposerAttachmentArea(
                        quotes: quotes,
                        attachments: _attachments,
                        onRemoveAttachment: _removeAttachment,
                      ),
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
              const ComposerBottomRow(),
            if (widget.variant == ComposerVariant.empty)
              const ComposerModeChips(),
          ],
        ),
      ),
    );
  }

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
          final base =
              _draggedHeight ?? ComposerMetrics.editorMinHeightConversation;
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
              hintText: busy
                  ? l10n.chatSteerHint
                  : switch (ref.watch(workspaceModeProvider)) {
                      WorkspaceMode.chat => l10n.workspaceInputHint,
                      WorkspaceMode.docs => l10n.workspaceInputHintDocs,
                      WorkspaceMode.slides => l10n.workspaceInputHintSlides,
                      WorkspaceMode.design => l10n.workspaceInputHintDesign,
                    },
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
    final settings = ref.watch(
      composerSettingsProvider.select((s) => s.settings),
    );

    final (mode, tooltip, enabled) = switch ((busy, hasText)) {
      (true, false) => (ComposerSendMode.stop, l10n.chatStop, true),
      (true, true) => (ComposerSendMode.steer, l10n.chatSteerHint, true),
      (false, final has) => (ComposerSendMode.send, l10n.workspaceSend, has),
    };

    return Padding(
      padding: const EdgeInsets.only(
        left: ComposerMetrics.actionBarPaddingStart,
        right: ComposerMetrics.actionBarPaddingEnd,
      ),
      child: Row(
        children: [
          ComposerPlusMenu(
            settings: settings,
            onPickFile: () => _pick(FileType.any),
          ),
          ComposerApprovalMenu(current: settings.approvalPolicy),
          ComposerEngineMenu(current: settings.engineMode),
          const Spacer(),
          if (widget.variant == ComposerVariant.empty) ...[
            const ComposerModelMenu(),
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
}
