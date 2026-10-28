import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_section.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 页头标题。抽出来是因为已开启形态下它要参与外层 [Column] 的布局，
/// 不能像未开启形态那样直接塞进 `ListView` 里。
class MemoryTitle extends StatelessWidget {
  const MemoryTitle({super.key});

  @override
  Widget build(BuildContext context) =>
      SettingsSectionHeader(AppLocalizations.of(context).memoryTitle);
}

/// 一段带行内「了解更多」链接的说明文字。按占位符拆分才能在换语言后
/// 让链接仍落在正确的位置上。
///
/// 拆分用不可见哨兵字符 `\u0000`，因为它不会出现在自然语言里。
///
/// 链接用 [WidgetSpan] + `InkWell` 而不是 `TextSpan.recognizer`：
/// recognizer 是**有状态对象**，每次 build 新建一个就得自己负责 dispose，
/// 漏掉就是一条泄漏；`WidgetSpan` 里的组件由框架管生命周期，不用管。
class LearnMoreParagraph {
  LearnMoreParagraph._();

  static const String _sentinel = '\u0000';

  static Widget build(
    ThemeData theme,
    String Function(String placeholder) template,
    String linkText,
    VoidCallback onTap,
  ) {
    final base = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final raw = template(_sentinel);
    final at = raw.indexOf(_sentinel);

    if (at < 0) return Text(raw, style: base);

    return RichText(
      text: TextSpan(
        style: base,
        children: [
          TextSpan(text: raw.substring(0, at)),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: InkWell(
              onTap: onTap,
              child: Text(
                linkText,
                style: base?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
          TextSpan(text: raw.substring(at + _sentinel.length)),
        ],
      ),
    );
  }
}

/// 右侧带描边的动作按钮（「开始导入」）。
class MemoryOutlineActionButton extends StatelessWidget {
  const MemoryOutlineActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Text(label),
    );
  }
}

/// 记忆输入框：底部常驻，把一句话交给 SGIT 记下来。
class MemoryInputBar extends StatefulWidget {
  const MemoryInputBar({super.key, required this.onSubmit});

  final VoidCallback onSubmit;

  @override
  State<MemoryInputBar> createState() => _MemoryInputBarState();
}

class _MemoryInputBarState extends State<MemoryInputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isEmpty) return;
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              style: TextStyle(fontSize: 14, color: skin.text),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                filled: false,
                hintText: l10n.memoryInputHint,
                hintStyle: TextStyle(fontSize: 14, color: skin.textTertiary),
                suffixIcon: MemorySendButton(onPressed: _submit),
              ),
            ),
          ),
        ],
        //),
      ),
    );
  }
}

/// 圆形上箭头发送键。
class MemorySendButton extends StatelessWidget {
  const MemorySendButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return SizedBox(
      width: 26,
      height: 26,
      child: Material(
        color: skin.text.withValues(alpha: 0.08),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Icon(Icons.arrow_upward, size: 18, color: skin.text),
        ),
      ),
    );
  }
}
