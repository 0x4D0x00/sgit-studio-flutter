import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/studio/resource_item.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_section.dart';
import 'package:sgit_studio_flutter/features/studio/application/resource_list_controller.dart';
import 'package:sgit_studio_flutter/app/app_providers.dart';
import 'package:sgit_studio_flutter/features/studio/studio_page_specs.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/feedback/async_view.dart';
import 'package:sgit_studio_flutter/ui/feedback/confirm.dart';

/// 记忆笔记列表。
///
/// 五态交给 [AsyncView]（加载中 / 出错 / 空 / 有数据 / 刷新中）——
/// **不自己再写一套**，否则这页的"空"和别的页的"空"迟早长得不一样。
///
/// 条目渲染成单行（标题 + 摘要），不用 studio 那边的分组卡片网格：
/// `memories/` 没有团队目录这层语义，硬套四个团队分组只会把每条都塞进
/// 「通用」。这里按文件路径平铺，路径本身就够说明来源（项目记忆带子目录）。
class MemoryNoteList extends ConsumerWidget {
  const MemoryNoteList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    const spec = StudioPageSpecs.memory;
    final s = ref.watch(resourceListProvider(spec));
    final ctrl = ref.read(resourceListProvider(spec).notifier);

    return AsyncView<ResourceItem>(
      loading: s.loading,
      error: s.error,
      stale: s.stale,
      isEmpty: s.items.isEmpty,
      emptyText: l10n.memoryNoFiles,
      retryText: l10n.commonRetry,
      onRetry: ctrl.reload,
      builder: (_) => ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: s.items.length,
        separatorBuilder: (_, _) => const SettingsSectionDivider(),
        itemBuilder: (ctx, i) => MemoryNoteRow(
          item: s.items[i],
          skin: skin,
          onTap: () => _editNote(context, ref, s.items[i]),
          onDelete: () => _confirmDelete(context, ref, s.items[i]),
        ),
      ),
    );
  }

  /// 点开一条记忆：**先读全文，再开编辑器**。
  ///
  /// 不能拿列表里那份摘要凑数 —— `ResourceItem` 只有标题与两行摘要，
  /// 拿它当正文保存会把整篇记忆截断成两行。所以这里走 `settings.read('memories', id)`
  /// 取磁盘原文（与 `sgit_settings_write` 同一套 kind/id 解析，见 Rust
  /// `settings.rs::path_of`）。
  Future<void> _editNote(
    BuildContext context,
    WidgetRef ref,
    ResourceItem item,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(settingsRepositoryProvider);
    final ctrl = ref.read(
      resourceListProvider(StudioPageSpecs.memory).notifier,
    );

    final String content;
    try {
      content = await repo.read('memories', item.id);
    } catch (e) {
      // Web 上没有"取整份 markdown"的端点（见 WebSettingsRepository.read），
      // 会抛到这里。明确告诉用户，而不是弹一个空编辑器让人白改一遍。
      messenger.showSnackBar(SnackBar(content: Text(_msg(e))));
      return;
    }
    if (!context.mounted) return;

    final saved = await showMemoryEditorDialog(
      context,
      title: item.name.isNotEmpty ? item.name : item.id,
      initialContent: content,
    );
    if (saved == null) return;

    try {
      await repo.write('memories', item.id, saved);
      await ctrl.reload(force: true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.commonSaved)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  /// 删除一条记忆。不可撤销，先确认 —— 与 studge 资源页的 `_confirmRemove` 同形。
  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ResourceItem item,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(settingsRepositoryProvider);
    final ctrl = ref.read(
      resourceListProvider(StudioPageSpecs.memory).notifier,
    );

    final ok = await confirmDanger(
      context,
      title: l10n.studioRemoveConfirm(item.name.isNotEmpty ? item.name : item.id),
      confirmText: l10n.studioRemove,
    );
    if (!ok) return;

    try {
      // 桌面走 `sgit_studio_remove('memory', id)` → `settings::delete_raw`
      // （先服务器后本地 + 脏队列）；Web 上这条会抛「不支持」，明确失败而非假装删掉。
      await repo.removeFromPage('memory', item.id);
      await ctrl.reload(force: true);
      messenger.showSnackBar(SnackBar(content: Text(l10n.commonDeleted)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }
}

/// 把异常摊平成给用户看的一句话。
///
/// 去掉 `ApiException: ` / `Exception: ` 这类前缀 —— 它们对用户没有意义，
/// 真正有用的原因（「Web 端不支持直接读取 memories 正文」）在后面。
String _msg(Object e) =>
    e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '');

/// 一条记忆笔记：标题（Markdown 首个标题，Rust 侧已解析）+ 摘要 + 路径。
class MemoryNoteRow extends StatelessWidget {
  const MemoryNoteRow({
    super.key,
    required this.item,
    required this.skin,
    required this.onTap,
    required this.onDelete,
  });

  final ResourceItem item;
  final AppSkin skin;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.name.isNotEmpty ? item.name : item.id,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: skin.text,
                    ),
                  ),
                ),
                Tooltip(
                  message: l10n.studioRemove,
                  child: InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 15,
                        color: skin.textTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: skin.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xxs),
            Text(
              item.id,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: skin.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 记忆正文编辑器。返回保存后的全文，取消返回 null。
///
/// 编辑的是**整份 markdown**（含 frontmatter 与 `#` 标题）—— 引擎把记忆当
/// 普通 markdown 文件读，只改正文会把它自己的结构弄丢。
Future<String?> showMemoryEditorDialog(
  BuildContext context, {
  required String title,
  required String initialContent,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        MemoryEditorDialog(title: title, initialContent: initialContent),
  );
}

class MemoryEditorDialog extends StatefulWidget {
  const MemoryEditorDialog({
    super.key,
    required this.title,
    required this.initialContent,
  });

  final String title;
  final String initialContent;

  @override
  State<MemoryEditorDialog> createState() => _MemoryEditorDialogState();
}

class _MemoryEditorDialogState extends State<MemoryEditorDialog> {
  late final _controller = TextEditingController(text: widget.initialContent);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: skin.containerBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: skin.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: skin.text,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 20,
                      color: skin.textSecondary,
                    ),
                    tooltip: l10n.commonClose,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: skin.containerBgSecondary,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: skin.borderSecondary),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: skin.text,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // 没改过就不让保存 —— 否则一次误点就会把 mtime 刷新，
                  // 同步侧会把它当成一次真实改动。
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (ctx, _) => FilledButton(
                      onPressed: _controller.text == widget.initialContent
                          ? null
                          : () => Navigator.of(ctx).pop(_controller.text),
                      child: Text(l10n.commonSave),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
