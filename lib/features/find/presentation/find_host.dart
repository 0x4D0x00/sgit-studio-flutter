import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/find/application/find_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/find/find_bar.dart';
import 'package:sgit_studio_flutter/ui/components/find/find_highlight.dart';

/// 页内查找的宿主：把 [FindController] 的状态广播给子树（[FindScope]），
/// 并在窗口右上角浮出查找框。包在整个外壳外面。
class FindHost extends ConsumerStatefulWidget {
  const FindHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<FindHost> createState() => _FindHostState();
}

class _FindHostState extends ConsumerState<FindHost> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(findControllerProvider);
    final ctrl = ref.read(findControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);

    // 再按 Ctrl+F：焦点回到输入框并全选，方便直接改词。
    ref.listen(findControllerProvider.select((s) => s.focusTick), (_, _) {
      _focus.requestFocus();
      _text.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _text.text.length,
      );
    });
    // 关闭 → 清空，下次打开是空白框（词不残留，高亮也跟着没了）。
    ref.listen(findControllerProvider.select((s) => s.open), (was, now) {
      if (was == true && !now) {
        _text.clear();
        ctrl.setQuery('');
      }
    });

    final active = s.open && s.query.isNotEmpty;
    final scope = FindScope(
      query: active ? s.query : '',
      navCurrent: active && s.current < s.navCount ? s.current : -1,
      transcriptCurrent: active && s.current >= s.navCount
          ? s.current - s.navCount
          : -1,
      child: widget.child,
    );

    return Stack(
      children: [
        Positioned.fill(child: scope),
        if (s.open)
          Positioned(
            top: AppWindow.titleBarHeight + 16,
            right: 24,
            child: FindBar(
              textController: _text,
              focusNode: _focus,
              hint: l10n.findHint,
              countText: !active
                  ? ''
                  : s.total == 0
                  ? '0/0'
                  : '${s.current + 1}/${s.total}',
              hasMatches: active && s.total > 0,
              onChanged: ctrl.setQuery,
              onNext: ctrl.next,
              onPrevious: ctrl.previous,
              onClose: ctrl.close,
              previousTooltip: l10n.findPrevious,
              nextTooltip: l10n.findNext,
              closeTooltip: l10n.findClose,
            ),
          ),
      ],
    );
  }
}
