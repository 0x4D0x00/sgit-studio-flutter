import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/studio/application/relay_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// L3 密钥池 —— **品牌级**，一个厂商下所有模型共用这一池。
///
/// 做成弹窗（而不是第三层页面）是照 React studio：密钥不需要再往下钻，
/// 弹窗能让用户看着模型列表加密钥，不用来回跳。
///
/// ⚠️ 界面只显示**后 6 位**（`RelayApiKey.masked`）。后端返回的是明文，
/// React studio 直接全量渲染到页面上了 —— 我们不跟，密钥不该在屏幕上可读，
/// 截图/录屏/肩窥都是真实泄露路径。
Future<void> showKeyPool(
  BuildContext context, {
  required String providerCode,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _KeyPoolDialog(providerCode: providerCode),
    );

class _KeyPoolDialog extends ConsumerStatefulWidget {
  const _KeyPoolDialog({required this.providerCode});

  final String providerCode;

  @override
  ConsumerState<_KeyPoolDialog> createState() => _KeyPoolDialogState();
}

class _KeyPoolDialogState extends ConsumerState<_KeyPoolDialog> {
  final _name = TextEditingController();
  final _key = TextEditingController();
  String? _err;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 打开即拉当前厂商的密钥。
    Future.microtask(
        () => ref.read(relayProvider.notifier).openKeyPool(widget.providerCode));
  }

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _add(AppLocalizations l10n) async {
    final k = _key.text.trim();
    if (k.isEmpty) {
      setState(() => _err = l10n.relayRequiredApiKey);
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });
    final ok = await ref
        .read(relayProvider.notifier)
        .createKey(widget.providerCode, k, name: _name.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    // 成功才清输入 —— 失败时把用户粘好的密钥清掉最讨人嫌（得重新去翻）。
    if (ok) {
      _key.clear();
      _name.clear();
    }
  }

  Future<void> _delete(String id) async {
    setState(() => _busy = true);
    await ref.read(relayProvider.notifier).deleteKey(widget.providerCode, id);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final scheme = Theme.of(context).colorScheme;
    final s = ref.watch(relayProvider);
    final err = _err ?? s.error;

    return AlertDialog(
      title: Text(l10n.relayKeyPoolTitle(widget.providerCode),
          style: const TextStyle(fontSize: 14)),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (err != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(err,
                    style: TextStyle(fontSize: 12, color: scheme.error)),
              ),
            // 列表：给个高度上限并可滚，密钥多了不至于把弹窗顶出屏幕。
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: s.keys.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md),
                      child: Text(l10n.relayNoKeys,
                          style: TextStyle(
                              fontSize: 12, color: skin.textTertiary)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: s.keys.length,
                      itemBuilder: (_, i) {
                        final k = s.keys[i];
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.xxs),
                          child: Row(
                            children: [
                              Icon(Icons.key_rounded,
                                  size: 13, color: skin.textTertiary),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  k.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    color: k.enabled
                                        ? skin.text
                                        : skin.textTertiary,
                                  ),
                                ),
                              ),
                              if (!k.enabled)
                                Text(l10n.relayDisabled,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: skin.textTertiary)),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 16),
                                color: scheme.error,
                                visualDensity: VisualDensity.compact,
                                tooltip: l10n.commonDelete,
                                onPressed: _busy ? null : () => _delete(k.id),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: AppSpacing.md),
            TextField(
              controller: _name,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: l10n.relayKeyNameHint,
                hintStyle: const TextStyle(fontSize: 12),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _key,
                    // 密钥输入即遮挡 —— 粘贴进来就不该再显示出来。
                    obscureText: true,
                    style: const TextStyle(fontSize: 13),
                    onSubmitted: (_) => _busy ? null : _add(l10n),
                    decoration: InputDecoration(
                      hintText: l10n.relayKeyPasteHint,
                      hintStyle: const TextStyle(fontSize: 12),
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                FilledButton(
                  onPressed: _busy ? null : () => _add(l10n),
                  child: Text(l10n.relayAddKey),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
      ],
    );
  }
}
