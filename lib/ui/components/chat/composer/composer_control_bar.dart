import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/tokens/composer_metrics.dart';

/// 输入框**下方**那一条控制条。
///
/// 1:1 对齐 studio 的 `ControlBar`（`features/ChatInput/ControlBar/index.tsx:16-40`）：
/// 高 28 / 左右 4 / 项间 4；左簇可变宽、会横向滚动，右簇钉死不缩。
///
/// ## 内容换成了 sgcode 自己的
///
/// studio 左簇放的是「对话/智能模式 + 执行设备 + 工作目录 + Git」—— 那几样是
/// lobe 的产品概念，我们不抄。我们这边左簇放 sgcode 真有的：沙箱档位、推理强度；
/// 右簇放上下文窗口占用。
///
/// ## 左簇为什么是横滚而不是换行
///
/// 换行会让整条从 28 变成 56，输入框位置跟着跳。窄窗口下宁可让用户横向拨一下 ——
/// 这是 studio 的原始决定（`leftGroup: overflow: auto hidden`），照搬。
/// 滚动条藏起来，滚轮/触控板照常。
///
/// ⚠️ 纯展示组件。
class ComposerControlBar extends StatelessWidget {
  const ComposerControlBar({
    super.key,
    required this.leading,
    required this.trailing,
  });

  /// 左簇（可被挤压 → 横滚）。
  final List<Widget> leading;

  /// 右簇（钉死不缩）。
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ComposerMetrics.controlBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ComposerMetrics.controlBarPaddingInline,
        ),
        child: Row(
          children: [
            Expanded(
              child: ScrollConfiguration(
                // 藏滚动条：这条只有 28 高，一根滚动条会占掉视觉上的一大截。
                behavior: const _NoScrollbar(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _spaced(leading),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: _spaced(trailing),
            ),
          ],
        ),
      ),
    );
  }

  /// 项间插 4px。用 `spacing:` 也行，但那要 Flutter 3.27+，这里不赌版本。
  static List<Widget> _spaced(List<Widget> items) => [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: ComposerMetrics.controlBarGap),
          items[i],
        ],
      ];
}

class _NoScrollbar extends ScrollBehavior {
  const _NoScrollbar();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
