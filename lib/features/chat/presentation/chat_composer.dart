import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/model_selector.dart';
import 'package:sgit_studio_flutter/router/route_names.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

/// 输入区。三个状态，全靠 `busy` 一个字段切：
///
/// | 状态 | 提示语 | 右侧按钮 |
/// |---|---|---|
/// | 空闲 | 有什么可以帮你的？ | 发送 |
/// | 跑着（有内容）| 插话改方向… | 插话（steer，**不打断**）|
/// | 跑着（空）| 插话改方向… | 停止（interrupt）|
///
/// **steer 与 stop 是两件事**，别合成一个按钮：CLI 里 `turn/steer` 是把新指示并进
/// 当前 turn（不重来），`turn/interrupt` 是掐掉。合并了用户就没法"补一句话继续跑"。
///
/// [showModelInside] 控制模型选择器位置：true=在输入框内右下角，false=在输入框外右下角。
class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({super.key, this.showModelInside = true});

  final bool showModelInside;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  final _ctl = TextEditingController();
  final _focus = FocusNode();

  /// 选中的模型（null = 用内核默认）。随 turn/start 一起发。
  String? _model;

  /// 已选择的附件列表
  final List<PlatformFile> _attachments = [];

  @override
  void initState() {
    super.initState();
    // 用 controller 监听而不是 TextField.onChanged：`_ctl.clear()` 这种**程序化**改动
    // 也要触发重建，否则 steer 之后按钮不会从「插话」切回「停止」（被 UI 测试抓到过）。
    _ctl.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result.isNotEmpty) {
        setState(() {
          _attachments.addAll(result);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
      );

      if (result.isNotEmpty) {
        setState(() {
          _attachments.addAll(result);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  @override
  void dispose() {
    _ctl.removeListener(_onTextChanged);
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(ChatController ctrl, bool busy) {
    final text = _ctl.text.trim();
    if (text.isEmpty) {
      if (busy) ctrl.interrupt();
      return;
    }
    // 跑着的时候提交 = 插话；空闲时提交 = 新一轮。
    final accepted = busy ? ctrl.steer(text) : ctrl.send(text, model: _model);
    // ⚠️ **只在受理后才清空**。被拒时保留用户输入，让他改完能直接重发。
    if (accepted) _ctl.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    // 只订阅用得到的字段，不整块 watch。
    final busy = ref.watch(chatControllerProvider.select((s) => s.busy));
    final usage = ref.watch(chatControllerProvider.select((s) => s.lastUsage));
    final timing = ref.watch(chatControllerProvider.select((s) => s.lastTiming));
    final ctrl = ref.read(chatControllerProvider.notifier);

    final hasText = _ctl.text.trim().isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: WorkspaceMetrics.inputAreaWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (usage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                child: Text(
                  // 用量与耗时都是内核算好的，我们只显示，不重算。
                  l10n.chatStats(usage.inputTokens, usage.outputTokens,
                      timing?.durationMs ?? 0),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: skin.textTertiary),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: skin.inputBg,
                borderRadius:
                    BorderRadius.circular(WorkspaceMetrics.inputAreaRadius),
                border: Border.all(color: skin.inputBorder),
                boxShadow: skin.inputShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 附件列表
                  if (_attachments.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: _attachments.asMap().entries.map((entry) {
                          final index = entry.key;
                          final file = entry.value;
                          final isImage = file.extension != null &&
                              ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp']
                                  .contains(file.extension!.toLowerCase());

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: AppSpacing.xxs,
                            ),
                            decoration: BoxDecoration(
                              color: skin.containerBgSecondary,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: skin.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isImage ? Icons.image : Icons.insert_drive_file,
                                  size: 16,
                                  color: skin.textSecondary,
                                ),
                                const SizedBox(width: AppSpacing.xxs),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 150),
                                  child: Text(
                                    file.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: skin.text,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xxs),
                                InkWell(
                                  onTap: () => _removeAttachment(index),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: skin.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  // 文本输入框
                  TextField(
                    controller: _ctl,
                    focusNode: _focus,
                    maxLines: 6,
                    minLines: 1,
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
                          : l10n.workspaceInputHint,
                      hintStyle: TextStyle(color: skin.textTertiary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // 「+」菜单 + 模型选择器 + 发送按钮
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _addMenu(context, skin, l10n),
                      const Spacer(),
                      if (widget.showModelInside) ...[
                        ModelSelector(
                          selected: _model,
                          onChanged: (m) => setState(() => _model = m),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      _action(ctrl, l10n, busy, hasText),
                    ],
                  ),
                ],
              ),
            ),
            // 模型选择器在输入框外时显示
            if (!widget.showModelInside)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ModelSelector(
                    selected: _model,
                    onChanged: (m) => setState(() => _model = m),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 「+」菜单：附件 / 联网搜索目前内核还没放开对应能力，先留占位提示；
  /// Agent Gateway 直接跳大模型中转站页（已有落地页，不需要占位）。
  Widget _addMenu(BuildContext context, AppSkin skin, AppLocalizations l10n) {
    void comingSoon() => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonComingSoon),
            duration: const Duration(seconds: 1),
          ),
        );

    return AppMenuAnchor(
      align: AppMenuAlign.above,
      semanticLabel: l10n.chatAddMenu,
      entries: [
        AppMenuSubmenu(
          icon: Icons.attach_file,
          label: l10n.chatAttachFiles,
          entries: [
            AppMenuAction(
              icon: Icons.insert_drive_file,
              label: '选择文件',
              onTap: _pickFiles,
            ),
            AppMenuAction(
              icon: Icons.image,
              label: '选择图片',
              onTap: _pickImages,
            ),
          ],
        ),
        AppMenuAction(
          icon: Icons.public,
          label: l10n.chatWebSearch,
          checked: true,
          onTap: comingSoon,
        ),
        AppMenuAction(
          icon: Icons.hub_outlined,
          label: l10n.chatAgentGateway,
          onTap: () => context.go(RouteNames.studio('llm-relay')),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        child: Icon(Icons.add, size: 20, color: skin.textSecondary),
      ),
    );
  }

  Widget _action(ChatController ctrl, AppLocalizations l10n, bool busy,
      bool hasText) {
    // 三态用 switch 表达式：加第四态（如"重试"）时这里会显形。
    final (icon, tooltip, enabled) = switch ((busy, hasText)) {
      (true, false) => (Icons.stop_rounded, l10n.chatStop, true),
      (true, true) => (Icons.reply_rounded, l10n.chatSteerHint, true),
      (false, final has) =>
        (Icons.arrow_upward_rounded, l10n.workspaceSend, has),
    };

    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18),
      onPressed: enabled ? () => _submit(ctrl, busy) : null,
    );
  }
}
