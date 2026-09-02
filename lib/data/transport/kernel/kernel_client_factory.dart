import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';

import 'kernel_client_factory_io.dart'
    if (dart.library.js_interop) 'kernel_client_factory_web.dart' as impl;

/// 按平台选内核通道实现。
///
/// - Web  → `WebKernelClient`（wasm → gateway `/sgcode-kernel/ws`）
/// - 桌面 → 暂为 mock（`sgit-ffi` 的内核符号待补）
///
/// 上层只认 [KernelClient] 接口，换实现不影响 `ChatController` 与任何 UI。
KernelClient createKernelClient() => impl.createKernelClient();
