import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/studio/relay_models.dart';
import 'package:sgit_studio_flutter/features/studio/application/relay_controller.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/widgets/relay_forms.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/widgets/relay_key_pool.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/async_view.dart';
import 'package:sgit_studio_flutter/ui/components/confirm.dart';

/// 大模型中转站 —— **两级页 + 密钥弹窗**：L1 厂商卡片墙 → L2 模型 → L3 密钥池
/// （对齐 memory `relay-l1l2l3-provider-crud`）。
///
/// 这是 8 个子页里唯一不走通用 `ResourceListPage` 的：它有层级、有下钻、
/// 数据在后端 SeekDB（走 SWR 两态），形状和其余 7 页差得远，硬套只会更难懂。
///
/// ## L3 为什么是弹窗而不是第三层页面
/// 密钥是**品牌级**的 —— 一个厂商下所有模型共用一池，不隶属于某个模型。
/// 做成下钻会让人以为"每个模型一池"（我最初就是这么错的，还把模型名当 key 传，
/// 结果永远查不到密钥）。弹窗从 L2 打开，语义上就挂在厂商上。
class RelayPage extends ConsumerWidget {
  const RelayPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final s = ref.watch(relayProvider);
    final ctrl = ref.read(relayProvider.notifier);

    final inL2 = s.selectedProvider != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(context, ref, skin, l10n, s, ctrl, inL2),
        Expanded(
          child: inL2
              ? _models(context, ref, skin, l10n, s, ctrl)
              : _providers(context, ref, skin, l10n, s, ctrl),
        ),
      ],
    );
  }

  /// 工具栏：标题 + 作用域切换 + 该层的动作。
  ///
  /// ⚠️ **必须按宽度自适应**。L2 这一排要放下 返回/标题/个人标记/作用域切换/
  /// 同步/密钥池/新增/刷新 八样东西 —— 原先硬塞在一个 `Row` 里，实测**连
  /// 1100px 都溢出 134px**（1366 勉强不炸，所以只测 1366 时没发现）。
  /// 现在窄屏把动作按钮折到第二行，永远不溢出，也不用猜阈值猜得刚好。
  Widget _toolbar(
    BuildContext context,
    WidgetRef ref,
    AppSkin skin,
    AppLocalizations l10n,
    RelayState s,
    RelayController ctrl,
    bool inL2,
  ) {
    final active = _activeProvider(s);
    final actions = _actions(context, l10n, s, ctrl, inL2, active);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
      child: LayoutBuilder(
        builder: (_, c) {
          // ⚠️ 窄屏下**丢掉冗余元素**，而不是硬挤：「个人（本地）」这个标记
          // 只是说明数据在哪，宽度不够时第一个该让位的就是它。
          final showBadge = c.maxWidth >= 420;

          final title = Row(
            children: [
              if (inL2)
                IconButton(
                  iconSize: 18,
                  tooltip: l10n.relayBack,
                  color: skin.textSecondary,
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: ctrl.back,
                ),
              Expanded(
                child: Text(
                  inL2 ? '${active?.label ?? s.selectedProvider}' : this.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: skin.text),
                ),
              ),
              // 个人版加个标记，免得用户以为自己在改全平台配置。
              if (showBadge)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: Text(l10n.relayLocalBadge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 11, color: skin.textTertiary)),
                  ),
                ),
              IconButton(
                iconSize: 18,
                tooltip: l10n.studioRefresh,
                color: skin.textSecondary,
                icon: const Icon(Icons.refresh_rounded),
                // L2 是下钻视图，重拉该厂商即可；L1 走整页刷新。
                // 两条都标成用户主动触发，不能被合并窗口吞掉。
                onPressed: inL2
                    ? () => ctrl.openProvider(s.selectedProvider!, refetch: true)
                    : () => ctrl.loadProviders(force: true),
              ),
            ],
          );

          // 1200 是实测出来的：L2 全铺开约需 1230px，留点余量。
          if (c.maxWidth >= 1200) {
            return Row(children: [
              Expanded(child: title),
              const SizedBox(width: AppSpacing.xs),
              ...actions,
            ]);
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: AppSpacing.xxs),
              // Wrap 而不是 Row：动作数量会变（L1/L2 不同），交给它自己换行。
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpacing.xxs,
                runSpacing: AppSpacing.xxs,
                children: actions,
              ),
            ],
          );
        },
      ),
    );
  }

  /// 该层的动作按钮。抽出来是因为宽窄两种排布要复用同一批。
  List<Widget> _actions(
    BuildContext context,
    AppLocalizations l10n,
    RelayState s,
    RelayController ctrl,
    bool inL2,
    RelayProvider? active,
  ) {
    if (!inL2) {
      return [
        FilledButton.icon(
          icon: const Icon(Icons.add_rounded, size: 15),
          label: Text(l10n.relayAddProvider,
              style: const TextStyle(fontSize: 12)),
          onPressed: () =>
              _editProvider(context, ctrl, RelayProvider.empty, isNew: true),
        ),
      ];
    }
    return [
      // 同步模型。⚠️ 厂商停用时后端一定拒（memory
      // relay-sync-blocked-by-provider-status），所以直接禁用 + tooltip
      // 说清原因，别让用户点了才看到"同步失败"。
      Tooltip(
        message: active?.enabled == false
            ? l10n.relaySyncBlockedDisabled
            : l10n.relaySync,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.sync_rounded, size: 15),
          label: Text(l10n.relaySync, style: const TextStyle(fontSize: 12)),
          onPressed: (active?.enabled ?? false)
              ? () => _sync(context, ctrl, s.selectedProvider!)
              : null,
        ),
      ),
      OutlinedButton.icon(
        icon: const Icon(Icons.key_rounded, size: 15),
        label: Text(l10n.relayKeyPool, style: const TextStyle(fontSize: 12)),
        onPressed: () =>
            showKeyPool(context, providerCode: s.selectedProvider!),
      ),
      FilledButton.icon(
        icon: const Icon(Icons.add_rounded, size: 15),
        label: Text(l10n.relayAddModel, style: const TextStyle(fontSize: 12)),
        onPressed: () => _editModel(
            context, ctrl, RelayModel.emptyFor(s.selectedProvider!),
            isNew: true),
      ),
    ];
  }

  // ---- L1：厂商卡片墙 ----

  Widget _providers(BuildContext context, WidgetRef ref, AppSkin skin,
          AppLocalizations l10n, RelayState s, RelayController ctrl) =>
      AsyncView<void>(
        loading: s.loading,
        error: s.error,
        stale: s.stale,
        isEmpty: s.providers.isEmpty,
        emptyText: l10n.relayNoProviders,
        retryText: l10n.commonRetry,
        onRetry: ctrl.loadProviders,
        builder: (_) => GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 300,
            // ⚠️ 高度要容得下开关 + 两行文字 + 操作图标。卡片内的行一律用
            // Expanded 自适应（见 layout_test：靠算像素迟早再溢出一次）。
            mainAxisExtent: 112,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
          ),
          itemCount: s.providers.length,
          itemBuilder: (_, i) {
            final p = s.providers[i];
            return _providerCard(context, skin, l10n, p, ctrl);
          },
        ),
      );

  Widget _providerCard(BuildContext context, AppSkin skin,
          AppLocalizations l10n, RelayProvider p, RelayController ctrl) =>
      Material(
        color: skin.containerBgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // 传 isCustom：同 code 的平台行与自建行并存，只有 tag 能区分点的是哪一行。
          onTap: () => ctrl.openProvider(p.code, isCustom: p.isCustom),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm, AppSpacing.xs, AppSpacing.xxs, AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: p.enabled ? skin.text : skin.textTertiary,
                          ),
                        ),
                      ),
                      if (p.isCustom)
                        _tag(context, l10n.relayCustom, false)
                      else
                        // 平台开放的厂商：标出来并且**全行只读**。个人页的写
                        // 一律落 tag=custom，改它只会新建一条同名影子行。
                        _tag(context, l10n.relayPlatform, false),
                      // 启用开关。缩到 0.75：网格项高度固定，全尺寸会顶出内容。
                      Transform.scale(
                        scale: 0.75,
                        child: Tooltip(
                          message: p.isCustom
                              ? (p.enabled
                                  ? l10n.relayToggleOff
                                  : l10n.relayToggleOn)
                              : l10n.relayPlatformReadonly,
                          child: Switch(
                            value: p.enabled,
                            onChanged: p.isCustom
                                ? (_) => ctrl.toggleProvider(p)
                                : null,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.baseUrl.isEmpty ? p.code : p.baseUrl,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: skin.textTertiary),
                        ),
                      ),
                      // 平台行只读：按钮禁用而不是隐藏 —— 隐藏了用户会以为
                      // 功能没做，禁用 + tooltip 才说得清"为什么不能改"。
                      IconButton(
                        iconSize: 15,
                        visualDensity: VisualDensity.compact,
                        tooltip: p.isCustom
                            ? l10n.relayEditProvider
                            : l10n.relayPlatformReadonly,
                        color: skin.textSecondary,
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: p.isCustom
                            ? () => _editProvider(context, ctrl, p, isNew: false)
                            : null,
                      ),
                      IconButton(
                        iconSize: 15,
                        visualDensity: VisualDensity.compact,
                        tooltip: p.isCustom
                            ? l10n.relayDeleteProvider
                            : l10n.relayPlatformReadonly,
                        color: Theme.of(context).colorScheme.error,
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed:
                            p.isCustom ? () => _deleteProvider(context, ctrl, p) : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  // ---- L2：模型列表 ----

  Widget _models(
    BuildContext context,
    WidgetRef ref,
    AppSkin skin,
    AppLocalizations l10n,
    RelayState s,
    RelayController ctrl,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 只做个人页：数据落本机 per-cid 库，平台开放的行只读。
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              l10n.relayScopeHintPersonal(s.models.length),
              style: TextStyle(fontSize: 11, color: skin.textTertiary),
            ),
          ),
          Expanded(
            child: AsyncView<void>(
              loading: s.loading,
              error: s.error,
              stale: s.stale,
              isEmpty: s.models.isEmpty,
              emptyText: l10n.studioEmpty,
              retryText: l10n.commonRetry,
              onRetry: () => ctrl.openProvider(s.selectedProvider ?? ''),
              builder: (_) => ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                itemCount: s.models.length,
                itemBuilder: (_, i) =>
                    _modelRow(context, skin, l10n, s.models[i], ctrl),
              ),
            ),
          ),
        ],
      );

  Widget _modelRow(BuildContext context, AppSkin skin, AppLocalizations l10n,
          RelayModel m, RelayController ctrl) =>
      Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.xxs),
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm, AppSpacing.xxs, AppSpacing.xxs, AppSpacing.xxs),
        decoration: BoxDecoration(
          color: skin.containerBgSecondary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Transform.scale(
              scale: 0.75,
              child: Tooltip(
                message:
                    m.available ? l10n.relayToggleOff : l10n.relayToggleOn,
                child: Switch(
                  value: m.available,
                  onChanged: (_) => ctrl.toggleModel(m),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: m.available ? skin.text : skin.textTertiary,
                    ),
                  ),
                  Text(
                    m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: skin.textTertiary),
                  ),
                ],
              ),
            ),
            // 窄屏下上下文窗口是最先该省掉的信息（模型名和开关才是主角）。
            if (m.contextWindow != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: Text(l10n.relayContextWindow(m.contextWindow!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: skin.textTertiary)),
                ),
              ),
            IconButton(
              iconSize: 15,
              visualDensity: VisualDensity.compact,
              tooltip: l10n.relayEditModel,
              color: skin.textSecondary,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editModel(context, ctrl, m, isNew: false),
            ),
            IconButton(
              iconSize: 15,
              visualDensity: VisualDensity.compact,
              tooltip: l10n.relayDeleteModel,
              color: Theme.of(context).colorScheme.error,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _deleteModel(context, ctrl, m),
            ),
          ],
        ),
      );

  // ---- 动作 ----

  Future<void> _editProvider(
    BuildContext context,
    RelayController ctrl,
    RelayProvider draft, {
    required bool isNew,
  }) async {
    final edited =
        await showProviderForm(context, draft: draft, isNew: isNew);
    if (edited == null) return;
    isNew ? await ctrl.createProvider(edited) : await ctrl.updateProvider(edited);
  }

  Future<void> _deleteProvider(
      BuildContext context, RelayController ctrl, RelayProvider p) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDanger(
      context,
      title: '${l10n.relayDeleteProvider} ${p.label}?',
      // 后端在其下仍有模型/密钥时会拒 —— 提前说清，省一次失败往返。
      message: l10n.relayDeleteProviderHint,
      confirmText: l10n.commonDelete,
    );
    if (ok) await ctrl.deleteProvider(p.code);
  }

  Future<void> _editModel(
    BuildContext context,
    RelayController ctrl,
    RelayModel draft, {
    required bool isNew,
  }) async {
    final edited = await showModelForm(context, draft: draft, isNew: isNew);
    if (edited == null) return;
    isNew ? await ctrl.createModel(edited) : await ctrl.updateModel(edited);
  }

  Future<void> _deleteModel(
      BuildContext context, RelayController ctrl, RelayModel m) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDanger(
      context,
      title: '${l10n.relayDeleteModel} ${m.name}?',
      confirmText: l10n.commonDelete,
    );
    if (ok) await ctrl.deleteModel(m);
  }

  Future<void> _sync(
      BuildContext context, RelayController ctrl, String code) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDanger(
      context,
      title: l10n.relaySync,
      message: l10n.relaySyncConfirmPersonal(code),
      confirmText: l10n.commonConfirm,
      danger: false,
    );
    if (ok) await ctrl.syncProvider(code);
  }

  RelayProvider? _activeProvider(RelayState s) => s.providers
      .where((p) => p.code == s.selectedProvider)
      .firstOrNull;

  Widget _tag(BuildContext context, String text, bool warn) {
    final scheme = Theme.of(context).colorScheme;
    final c = warn ? scheme.error : scheme.primary;
    return Container(
      margin: const EdgeInsets.only(left: AppSpacing.xxs),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(text, style: TextStyle(fontSize: 9, color: c)),
    );
  }
}
