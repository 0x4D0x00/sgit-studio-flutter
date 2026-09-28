import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/i18n/locale_controller.dart';

/// 语言选择弹窗：卡片网格，选中项高亮 + 打勾。从侧栏用户菜单的「语言」项打开。
///
/// 从设置弹窗页面里独立出来，不再挂在设置弹窗的语言分区下。
Future<void> showLanguageDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _LanguageDialog(),
  );
}

class _LanguageOption {
  const _LanguageOption(this.locale, this.label);
  final Locale? locale;
  final String label;
}

class _LanguageDialog extends ConsumerWidget {
  const _LanguageDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeControllerProvider);

    final options = [
      _LanguageOption(null, l10n.settingsThemeSystem),
      _LanguageOption(const Locale('zh'), l10n.settingsLanguageZh),
      _LanguageOption(const Locale('en'), l10n.settingsLanguageEn),
    ];

    return Dialog(
      backgroundColor: skin.containerBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: skin.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.settingsLanguage,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: skin.text,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: skin.textSecondary),
                    tooltip: l10n.commonClose,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Divider(height: 1, thickness: 1, color: skin.borderSecondary),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final opt in options)
                    _LanguageCard(
                      label: opt.label,
                      selected: opt.locale == locale,
                      onTap: () {
                        ref.read(localeControllerProvider.notifier).setLocale(opt.locale);
                        Navigator.of(context).pop();
                      },
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

class _LanguageCard extends StatefulWidget {
  const _LanguageCard({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends State<_LanguageCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final theme = Theme.of(context);

    Color bgColor;
    if (widget.selected || _hovering) {
      bgColor = skin.text.withValues(alpha: 0.06);
    } else {
      bgColor = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          width: 180,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: skin.text,
                  ),
                ),
              ),
              if (widget.selected)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xs),
                  child: Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
