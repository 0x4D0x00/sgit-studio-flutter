import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/features/studio/application/accessible_menus_controller.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/pages/relay_page.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/pages/resource_list_page.dart';
import 'package:sgit_studio_flutter/features/studio/presentation/pages/tools_page.dart';
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
  const StudioPage({super.key, required this.pageKey, this.query = ''});

  final String pageKey;

  /// 顶部搜索框的词，原样交给各子页自己过滤。
  ///
  /// 在子页过滤而不是在这里过滤：各页的数据形状不同（资源列表 /
  /// 工具开关组 / 中转站三级页），只有页面自己知道哪些字段该搜。
  final String query;

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
                child: CircularProgressIndicator(strokeWidth: 2),
              )
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
    if (pageKey == 'llm-relay') return RelayPage(title: title, query: query);

    // 工具是**开关组**而不是列表（config.toml 的 [features]），
    // 套通用列表页得为每项编一套假 id 与分组，更难懂 —— 单独一页。
    if (pageKey == 'tools') return ToolsPage(title: title, query: query);

    // 其余：有 spec 就是通用列表页（分组卡片网格）。
    final spec = StudioPageSpecs.of(pageKey);
    if (spec != null) {
      return ResourceListPage(spec: spec, title: title, query: query);
    }

    // 兜底：菜单里有、但这里还没接的页。正常不该走到。
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
  }) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 32, color: iconColor),
      const SizedBox(height: 12),
      Text(text, style: textStyle),
    ],
  );
}
