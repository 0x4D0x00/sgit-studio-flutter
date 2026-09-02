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
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      routerConfig: router,
    );
  }
}
