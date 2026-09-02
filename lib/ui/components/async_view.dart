import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

/// 三态视图：加载中 / 出错 / 空 / 有数据。**全 app 统一这一个**，各页不各写一遍。
///
/// 两个刻意的取舍：
/// - **有数据时即使在加载也照常显示**（配合 SWR：先显示缓存，后台刷新）——
///   转圈盖住已有内容是最糟的做法。刷新中用 [stale] 标一条细进度即可。
/// - **出错时如果已有数据，只在顶部挂一条提示**，不清空内容。
class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.loading,
    required this.error,
    required this.isEmpty,
    required this.builder,
    required this.emptyText,
    required this.retryText,
    this.stale = false,
    this.onRetry,
  });

  final bool loading;
  final String? error;
  final bool isEmpty;
  final WidgetBuilder builder;
  final String emptyText;
  final String retryText;

  /// 当前内容来自缓存，后台正在刷新。
  final bool stale;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final scheme = Theme.of(context).colorScheme;
    final hasContent = !isEmpty;

    // 首次加载且什么都没有 → 才允许转圈。
    if (loading && !hasContent && error == null) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (error != null && !hasContent) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 28, color: scheme.error),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: skin.textSecondary),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(onPressed: onRetry, child: Text(retryText)),
            ],
          ],
        ),
      );
    }

    if (isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: TextStyle(fontSize: 13, color: skin.textTertiary),
        ),
      );
    }

    return Column(
      children: [
        // 刷新中/出错都用一条细提示，不盖住已有内容。
        if (loading || stale)
          const LinearProgressIndicator(minHeight: 2)
        else if (error != null)
          Container(
            width: double.infinity,
            color: scheme.error.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
            child: Text(error!,
                style: TextStyle(fontSize: 11, color: scheme.error)),
          ),
        Expanded(child: builder(context)),
      ],
    );
  }
}
