import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_web.dart';

/// Web 侧的内核通道：走 `sgit-ffi-web` 的 WASM → gateway `/sgcode-kernel/ws`。
KernelClient createKernelClient() => WebKernelClient();
