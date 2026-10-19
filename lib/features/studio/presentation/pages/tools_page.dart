import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/studio/tool_catalog.dart';
import 'package:sgit_studio_flutter/features/studio/application/tools_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/async_view.dart';
import 'package:sgit_studio_flutter/ui/components/hover_lift.dart';

/// 工具页 —— sgcode 引擎的**内置工具**，按类别分组展示。
///
/// 不套 `ResourceListPage`：这些工具没有 id 分组前缀、不能增删，
/// 分组来自固定的功能类别而不是目录名。
///
/// 两个标记是这一页信息量的关键：
/// - **核心** —— 引擎无条件注册，没有开关，关不掉；
/// - **按需** —— 已注册但首轮不直接给模型，靠 `tool_search` 发现。
///   这与"被关掉了"完全不同，混在一起用户会以为工具坏了。
class ToolsPage extends ConsumerWidget {
  const ToolsPage({super.key, required this.title, this.query = ''});

  final String title;

  /// 页面顶部搜索框的词。空串表示不过滤。
  final String query;

  /// 按名称 / 技术名 / 描述 / 类别名过滤。
  ///
  /// 过滤掉的行直接从所在分组里拿掉；整组空了就不画那个组头 ——
  /// 否则搜索后满屏是「X · 0」。
  List<ToolGroup> _filter(List<ToolGroup> groups) {
    if (query.isEmpty) return groups;
    final q = query.toLowerCase();
    bool hit(ToolRow r) =>
        r.def.label.toLowerCase().contains(q) ||
        r.def.id.toLowerCase().contains(q) ||
        r.def.desc.toLowerCase().contains(q);

    return [
      for (final g in groups)
        if (g.name.toLowerCase().contains(q))
          g
        else if (g.rows.any(hit))
          ToolGroup(
            name: g.name,
            rows: g.rows.where(hit).toList(growable: false),
          ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final s = ref.watch(toolsProvider);
    final ctrl = ref.read(toolsProvider.notifier);
    final groups = _filter(s.groups);
    final count = groups.fold<int>(0, (n, g) => n + g.rows.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(skin, l10n, count, ctrl),
        if (s.error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              s.error!,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        Expanded(
          child: AsyncView<ToolRow>(
            loading: s.loading,
            // 错误已在上面单独展示 —— 传 null，避免开关写失败时整页变错误态、
            // 把用户正在看的清单换成一句报错。
            error: null,
            stale: s.stale,
            isEmpty: groups.isEmpty,
            emptyText: l10n.studioEmpty,
            retryText: l10n.commonRetry,
            onRetry: ctrl.reload,
            builder: (_) => ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.lg),
              children: [
                for (final g in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        0, AppSpacing.sm, 0, AppSpacing.xs),
                    child: Text(
                      '${g.name} · ${g.rows.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: skin.textSecondary,
                      ),
                    ),
                  ),
                  for (final r in g.rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: _Row(
                        row: r,
                        busy: s.busyId == r.def.id,
                        onToggle: r.def.kind == ToolKind.core
                            ? null
                            : (v) => ctrl.toggle(r.def, v),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(
    AppSkin skin,
    AppLocalizations l10n,
    int count,
    ToolsController ctrl,
  ) => Padding(
    padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
    child: Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: skin.text,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$count',
          style: TextStyle(fontSize: 12, color: skin.textTertiary),
        ),
        const Spacer(),
        IconButton(
          iconSize: 18,
          tooltip: l10n.studioRefresh,
          color: skin.textSecondary,
          icon: const Icon(Icons.refresh_rounded),
          // force：用户主动点的，不能被合并窗口吞掉。
          onPressed: () => ctrl.reload(force: true),
        ),
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.row, required this.busy, this.onToggle});

  final ToolRow row;
  final bool busy;

  /// null = 核心工具，没有开关。
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final def = row.def;

    // 与资源卡片同一套 token + 同一份悬停手感，两类页面放在一起不会像两个产品。
    return HoverLift(
      builder: (_, hovering) => AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: skin.containerBgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: skin.borderSecondary),
          boxShadow: hovering
              ? [
                  BoxShadow(
                    color: skin.border.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          def.label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: skin.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (def.kind == ToolKind.core)
                        _tag(skin, '核心', skin.textTertiary),
                      if (row.enabled && def.exposure == ToolExposure.deferred)
                        _tag(skin, '按需', skin.textTertiary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    def.desc,
                    style: TextStyle(fontSize: 11, color: skin.textTertiary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // 技术名：和日志、提示词里出现的名字对上。
                  Text(
                    def.id,
                    style: TextStyle(
                      fontSize: 10,
                      color: skin.textTertiary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (onToggle == null)
              // 核心工具：显示成常开且不可点，tooltip 说明原因 ——
              // 别让用户对着点不动的开关猜。
              Tooltip(
                message: '核心能力，引擎始终启用',
                child: Switch(value: true, onChanged: null),
              )
            else
              Switch(value: row.enabled, onChanged: onToggle),
          ],
        ),
      ),
    );
  }

  Widget _tag(AppSkin skin, String text, Color color) => Padding(
    padding: const EdgeInsets.only(left: 6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: skin.borderSecondary),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, color: color)),
    ),
  );
}
