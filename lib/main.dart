import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/app/app.dart';
import 'package:sgit_studio_flutter/services/brand/brand_config.dart';
import 'package:sgit_studio_flutter/platform/desktop_window.dart';
import 'package:sgit_studio_flutter/core/storage/local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 本地存储(主题/语言/token 持久化)。
  await LocalStorage.init();

  // 品牌文本配置(产品名/版权)。必须在 runApp 前拿到——窗口标题/标签页标题要用。
  await BrandConfig.load();

  runApp(const ProviderScope(child: SgitStudioApp()));

  // 桌面无边框透明窗口(仅 Windows/Linux/macOS 生效)。
  await initDesktopWindow();
}
