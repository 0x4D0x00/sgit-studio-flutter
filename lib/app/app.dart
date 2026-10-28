import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/services/brand/brand_config.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/services/i18n/locale_controller.dart';
import 'package:sgit_studio_flutter/router/app_router.dart';
import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/services/theme/theme_controller.dart';
import 'package:sgit_studio_flutter/platform/input/zoom_gesture.dart';
import 'package:sgit_studio_flutter/ui/components/chat/task_surface_overlay.dart';

/// 应用根。串起 theme(含动态主色/次色/字号) / locale / router。
class SgitStudioApp extends ConsumerWidget {
  const SgitStudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(themeControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      // 产品名来自 brand.json(外置优先),禁止写死;Web 上这个值即浏览器标签页标题。
      title: BrandConfig.instance.title,
      debugShowCheckedModeBanner: false,
      themeMode: theme.mode.flutterMode,
      // 透明模式在**主题构建期**就决定，落进 AppSkin 这个 ThemeExtension。
      // 下游组件因此不需要 watch 任何 provider 去问"现在是不是透明模式"。
      theme: AppTheme.light(
        primary: theme.primary,
        secondary: theme.secondary,
        transparent: theme.transparentMode,
      ),
      darkTheme: AppTheme.dark(
        primary: theme.primary,
        secondary: theme.secondary,
        transparent: theme.transparentMode,
      ),
      locale: locale,
      supportedLocales: LocaleController.supported,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 全局注入:Ctrl+滚轮字号缩放 + 动态字号(textScaler)。
      builder: (context, child) {
        return FontScaleListener(
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: theme.fontScale,
            maxScaleFactor: theme.fontScale,
            child: Theme(
              data: _withToastStyle(context),
              // 全局 Stack：主内容之上叠一层常驻的后台任务卡片（右下角）。
              // 卡片的悬停预览用 MaterialApp 自带的 Overlay，无需额外 Navigator。
              child: Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  // 卡片层自带 Overlay（见 TaskSurfaceOverlay 注释），用 Positioned.fill
                  // 给它一个有界区域；它内部用 Positioned 把卡片摆到右下角。
                  const Positioned.fill(child: TaskSurfaceOverlay()),
                ],
              ),
            ),
          ),
        );
      },
      routerConfig: router,
    );
  }
}

/// 全局提示条(SnackBar)样式：圆角卡片，浮在右下角，而非整行黑条；颜色跟随深浅主题。
/// 右对齐靠 margin 的 left 随窗口宽度算出(SnackBar 自身不支持对齐)。
ThemeData _withToastStyle(BuildContext context) {
  const maxWidth = 360.0;
  const gap = 16.0;
  final base = Theme.of(context);
  final scheme = base.colorScheme;
  final screenW = MediaQuery.sizeOf(context).width;
  final left = (screenW - maxWidth - gap).clamp(gap, double.infinity);
  return base.copyWith(
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.surface,
      elevation: 6,
      showCloseIcon: true,
      closeIconColor: scheme.onSurfaceVariant,
      // 必须基于 textTheme，裸 TextStyle 没有全局字体，缺字回退会造成粗细不一。
      contentTextStyle: base.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      insetPadding: EdgeInsets.fromLTRB(left, gap, gap, gap),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
  );
}
