import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/features/studio/application/accessible_menus_controller.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/pages/relay_page.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/pages/resource_list_page.dart';
import 'package:sgit_studio_flutter/features/studio/studio_feature.dart';
import 'package:sgit_studio_flutter/features/studio/studio_page_specs.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 「智能体」子页容器 —— 对应 studio 的 `/?studio=<key>` 就地渲染。
///
/// ⚠️ **这里也要判权**：侧栏隐藏入口只防误点，不防手输 URL。无权限时直接拒绝渲染，
/// 与侧栏用的是同一份 [visibleStudioPagesProvider]（拒绝式：加载中/判权失败都不放行）。
///
/// 页面分派：7 页走通用 [ResourceListPage]（各页只是一份 spec），
/// 中转站走 [RelayPage]（三级页，形状差太远，硬套只会更难懂）。
class StudioPage extends ConsumerWidget {
  const StudioPage({super.key, required this.pageKey});

  final String pageKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final page = ref
        .watch(visibleStudioPagesProvider)
        .where((p) => p.key == pageKey)
        .firstOrNull;

    // 判权未通过：可能是加载中、无权限、或后端不可用。统一给"无权访问"，
    // 不区分原因（区分了等于把菜单是否存在这件事泄露出去）。
    if (page == null) {
      final loading = ref.watch(accessibleMenusProvider).isLoading;
      return Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
            : _hint(
                icon: Icons.lock_outline_rounded,
                iconColor: skin.textTertiary,
                text: l10n.studioAccessDenied,
                textStyle: TextStyle(fontSize: 14, color: skin.textSecondary),
              ),
      );
    }

    final title = page.label(l10n);

    // 中转站单独一页。
    if (pageKey == 'llm-relay') return RelayPage(title: title);

    // 其余：有 spec 就是通用列表页。
    final spec = StudioPageSpecs.of(pageKey);
    if (spec != null) return ResourceListPage(spec: spec, title: title);

    // tools / memory 的数据源还没接（工具是开关组、记忆全平台已暂停）。
    // 明说"待接"，别拿空列表冒充"没数据"。
    return Center(
      child: _hint(
        icon: page.icon,
        iconColor: skin.textTertiary,
        text: '$title · ${l10n.studioComingSoon}',
        textStyle: TextStyle(fontSize: 14, color: skin.textSecondary),
      ),
    );
  }

  Widget _hint({
    required IconData icon,
    required Color iconColor,
    required String text,
    required TextStyle textStyle,
  }) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: iconColor),
          const SizedBox(height: 12),
          Text(text, style: textStyle),
        ],
      );
}
