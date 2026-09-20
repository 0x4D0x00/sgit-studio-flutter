import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/composer_metrics.dart';

/// 空态右下角的模型名触发器 —— 显示模型**名字**而不是一个图标。
///
/// 1:1 对齐 studio 的 `ModelLabel`（`ActionBar/ModelLabel/index.tsx:17-49,88-100`）：
/// 高 28 / 左右 6 / 圆角 4 / 字号 12 / 名字最宽 160 省略 / chevron 12。
///
/// 与会话态那个模型**图标**是两个控件：studio 首页 `rightActions: ['modelLabel']`、
/// 会话页 `leftActions: [..., 'model', ...]`。名字版占地大但一眼能看见用的是谁，
/// 适合还没开聊的空态；开聊后位置让给内容，退成图标。
///
/// ## 没有自己的 InkWell
///
/// 它总是 `AppMenuAnchor` 的触发器，而锚点在外面已经套了一层 `InkWell`。
/// 这里再套一层，内层会先命中并吃掉点击 —— 菜单永远打不开，且看不出异常。
///
/// ⚠️ 纯展示组件：不查模型列表，名字与可用性由外部喂。
class ComposerModelLabel extends StatelessWidget {
  const ComposerModelLabel({
    super.key,
    required this.displayName,
    required this.semanticLabel,
    this.enabled = true,
    this.loading = false,
  });

  /// 已经算好的显示名。加载中/无模型时的兜底文案也由外部决定 ——
  /// 组件不认识"默认""无可用模型"这些业务概念。
  final String displayName;

  /// 读屏标签。
  final String semanticLabel;

  /// 是否可点（没有可用模型时为 false）。
  ///
  /// ⚠️ 不可点时**仍然渲染**，只是转灰。早期模型选择器在取不到模型时整个
  /// `SizedBox.shrink()`，用户以为功能没做（见 `model_selector.dart` 的注释）。
  final bool enabled;

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: enabled,
      child: Container(
        height: ComposerMetrics.modelLabelHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: ComposerMetrics.modelLabelPaddingInline,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              SizedBox(
                width: ComposerMetrics.modelLabelChevronSize,
                height: ComposerMetrics.modelLabelChevronSize,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: skin.textTertiary,
                ),
              ),
              const SizedBox(width: ComposerMetrics.modelLabelGap),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ComposerMetrics.modelLabelMaxWidth,
              ),
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: ComposerMetrics.modelLabelFontSize,
                  color: enabled ? skin.textSecondary : skin.textTertiary,
                ),
              ),
            ),
            const SizedBox(width: ComposerMetrics.modelLabelGap),
            Icon(
              Icons.expand_more_rounded,
              size: ComposerMetrics.modelLabelChevronSize,
              // studio 用 colorTextQuaternary —— 比名字还淡一档，
              // 让 chevron 不跟名字抢注意力。
              color: enabled ? skin.textTertiary : skin.borderSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
