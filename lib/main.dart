import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/platform/desktop_window.dart';
import 'core/storage/local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 本地存储(主题/语言/token 持久化)。
  await LocalStorage.init();

  runApp(const ProviderScope(child: SgitNexusApp()));

  // 桌面无边框透明窗口(仅 Windows/Linux/macOS 生效)。
  await initDesktopWindow();
}
