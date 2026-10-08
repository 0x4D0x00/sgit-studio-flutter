import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/domain/models/chat/code_artifact.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/layout/layout_controller.dart';
import 'package:sgit_studio_flutter/ui/components/chat/bubble_actions_row.dart';

/// 文本气泡。**流式期间只有它自己重建。**
///
/// 订阅的是 [TextItem.revision] 这一条 `ValueListenable`，不是整个列表的状态 ——
/// 所以 native 推来一条 delta，重建范围就是这一个气泡，而不是 `ListView` 全体。
/// 这是长回答不掉帧的关键，改之前先读 `docs/KERNEL_FFI.md` §4。
class TextBubble extends ConsumerStatefulWidget {
  const TextBubble({
    super.key,
    required this.item,
    required this.truncatedHint,
    this.isLastAnswer = false,
    this.onEditSave,
  });

  final TextItem item;

  /// 「内容可能不完整」提示文案（native 背压丢过 delta 时显示）。
  final String truncatedHint;

  /// 这条是不是当前会话最后一组回答的末尾气泡 —— 是的话工具行常驻显示，
  /// 不需要悬停（用户气泡从不常驻，只有回答气泡走这条）。
  final bool isLastAnswer;

  /// 仅用户气泡传入：气泡内联编辑保存后调用，参数是编辑后的文本。
  /// 调用方（[ChatTranscript]）据此丢弃这条之后的内容并重新发送。
  final void Function(String text)? onEditSave;

  @override
  ConsumerState<TextBubble> createState() => _TextBubbleState();
}

class _TextBubbleState extends ConsumerState<TextBubble> {
  bool _hovering = false;

  /// 正在气泡内编辑。非 null 时气泡内容替换成输入框。
  TextEditingController? _editCtl;

  void _startEdit(String text) {
    setState(() => _editCtl = TextEditingController(text: text)
      ..selection = TextSelection.collapsed(offset: text.length));
  }

  void _cancelEdit() {
    _editCtl?.dispose();
    setState(() => _editCtl = null);
  }

  void _saveEdit() {
    final text = _editCtl!.text.trim();
    if (text.isEmpty || text == widget.item.text.trim()) return;
    widget.onEditSave?.call(text);
    _editCtl!.dispose();
    setState(() => _editCtl = null);
  }

  @override
  void dispose() {
    _editCtl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final item = widget.item;
    final isUser = item.role == ChatRole.user;
    // 用户气泡从不常驻，只有"当前回答"的末尾气泡才常驻。
    final showActions = _hovering || (widget.isLastAnswer && !isUser);
    final editing = _editCtl != null;

    return RepaintBoundary(
      child: ValueListenableBuilder<int>(
        valueListenable: item.revision,
        builder: (context, _, _) {
          // 提取代码块
          final artifacts = item.done
              ? CodeArtifact.extractFromMarkdown(item.text)
              : <CodeArtifact>[];

          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: MouseRegion(
                onEnter: (_) => setState(() => _hovering = true),
                onExit: (_) => setState(() => _hovering = false),
                child: editing
                    ? _buildEditor(context, skin)
                    : _buildBubble(context, skin, item, isUser, showActions,
                        artifacts),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBubble(
    BuildContext context,
    AppSkin skin,
    TextItem item,
    bool isUser,
    bool showActions,
    List<CodeArtifact> artifacts,
  ) {
    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: isUser ? skin.navItemActive : skin.containerBgSecondary,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: skin.borderSecondary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                item.text,
                style: TextStyle(fontSize: 14, height: 1.6, color: skin.text),
              ),
              if (item.truncated)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(
                    widget.truncatedHint,
                    style: TextStyle(fontSize: 11, color: skin.textTertiary),
                  ),
                ),
              // 代码块操作按钮
              if (artifacts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    for (final artifact in artifacts)
                      _ArtifactChip(
                        artifact: artifact,
                        onTap: () => ref
                            .read(layoutControllerProvider.notifier)
                            .showArtifact(artifact),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // 悬浮工具行占位高度固定，避免显示/隐藏时内容跳动。
        SizedBox(
          height: 24,
          child: showActions
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: BubbleActionsRow(
                    isUser: isUser,
                    createdAt: item.createdAt,
                    onCopy: () => copyToClipboard(context, item.text,
                        AppLocalizations.of(context).chatCopied),
                    onEdit: isUser ? () => _startEdit(item.text) : null,
                  ),
                )
              : null,
        ),
      ],
    );
  }

  /// 气泡内联编辑态：替换成输入框 + 取消/保存。**保存会丢弃这条之后的内容并
  /// 重新发送**，取消原样恢复。
  Widget _buildEditor(BuildContext context, AppSkin skin) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
            child: TextField(
              controller: _editCtl,
              autofocus: true,
              maxLines: null,
              style: TextStyle(fontSize: 14, height: 1.6, color: skin.text),
              decoration: InputDecoration(
                filled: true,
                fillColor: skin.containerBgSecondary,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: skin.borderSecondary),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: skin.borderSecondary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: scheme.primary, width: 2),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: l10n.chatEditRegenerateHint,
                  child: Icon(Icons.info_outline,
                      size: 14, color: skin.textTertiary),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: _cancelEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: skin.text,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l10n.commonCancel,
                      style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: AppSpacing.xs),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _editCtl!,
                  builder: (context, value, _) {
                    // 内容为空或与原文一致（没改动）时保存不可点。
                    final trimmed = value.text.trim();
                    final enabled =
                        trimmed.isNotEmpty && trimmed != widget.item.text.trim();
                    return TextButton(
                      onPressed: enabled ? _saveEdit : null,
                      style: TextButton.styleFrom(
                        foregroundColor:
                            enabled ? scheme.primary : skin.textTertiary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(l10n.commonSave,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 代码块芯片 —— 点击后在右侧打开。
class _ArtifactChip extends StatelessWidget {
  const _ArtifactChip({
    required this.artifact,
    required this.onTap,
  });

  final CodeArtifact artifact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: skin.containerBg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: skin.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.code,
              size: 14,
              color: skin.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              artifact.title,
              style: TextStyle(
                fontSize: 12,
                color: skin.text,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward,
              size: 12,
              color: skin.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}
