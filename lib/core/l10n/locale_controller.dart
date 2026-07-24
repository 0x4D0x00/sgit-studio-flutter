import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/local_storage.dart';

/// 语言控制器。`null` = 跟随系统。
class LocaleController extends Notifier<Locale?> {
  static const List<Locale> supported = <Locale>[Locale('zh'), Locale('en')];

  @override
  Locale? build() {
    final code = LocalStorage.instance.locale;
    return code == null ? null : Locale(code);
  }

  void setLocale(Locale? locale) {
    state = locale;
    LocalStorage.instance.setLocale(locale?.languageCode);
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);
