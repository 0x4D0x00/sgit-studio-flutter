import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/app/app.dart';
import 'package:sgit_studio_flutter/features/chat/application/chat_ports_impl.dart';
import 'package:sgit_studio_flutter/data/transport/ffi/sgit_request_ffi.dart';
import 'package:sgit_studio_flutter/services/brand/brand_config.dart';
import 'package:sgit_studio_flutter/platform/desktop_window.dart';
import 'package:sgit_studio_flutter/core/storage/local_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 本地存储(主题/语言/token 持久化) + 品牌文本配置(产品名/版权)。
  // 两者互不依赖，并行预热；都要在 runApp 前拿到——品牌名窗口标题/标签页标题要用。
  await Future.wait([
    LocalStorage.init(),
    BrandConfig.load(),
  ]);

  // ⚠️ **必须在 runApp 之前把 FFI 会话拉起来。**
  //
  // `AuthController.build()` 第一件事就是同步问 `isAuthenticated()`：
  // - 桌面：Rust 从本地库恢复会话，同步可得，没问题；
  // - Web ：会话在 wasm 里，wasm 还没实例化时 `isAuthenticated()` 恒 false
  //   → 明明登录着，刷新页面却必然先落到登录页。
  //
  // 原来 `warmupCrypto()` 只在登录页 mount 时调，于是「已登录用户刷新」
  // 这个最常见的路径反而每次都要重登一次。放在这里一次就够。
  //
  // 失败不阻塞启动：真起不来时，后续请求会以鉴权失败的形式暴露，
  // 而那时 `AuthController` 会把人送到登录页（见 core/result/auth_failure.dart）。
  //
  // ⚠️ 必须 try/catch 而不是 `.catchError` —— `SgitRequestFfi.instance` 是个
  // **getter**，DLL 缺失时它在求值阶段就同步抛（`_open()` 失败），
  // 那时还没有 Future 可以挂 `catchError`，异常会直接打断 `main()`。
  try {
    await SgitRequestFfi.instance.warmupCrypto();
  } catch (e) {
    debugPrint('[main] FFI 预热失败（继续启动）：$e');
  }

  runApp(
    ProviderScope(
      overrides: [chatPortsOverride],
      child: const SgitStudioApp(),
    ),
  );

  // 桌面无边框透明窗口(仅 Windows/Linux/macOS 生效)。
  await initDesktopWindow();
}
