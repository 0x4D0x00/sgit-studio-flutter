import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/brand/brand_config.dart';
import 'core/l10n/generated/app_localizations.dart';
import 'core/l10n/locale_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'shared/layout/font_scale_listener.dart';

/// 应用根。串起 theme(含动态主色/次色/字号) / locale / router。
class SgitNexusApp extends ConsumerWidget {
  const SgitNexusApp({super.key});

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
      theme: AppTheme.light(primary: theme.primary, secondary: theme.secondary),
      darkTheme: AppTheme.dark(primary: theme.primary, secondary: theme.secondary),
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
