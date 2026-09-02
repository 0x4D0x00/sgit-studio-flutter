import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_mock.dart';

/// 桌面（io）侧的内核通道选择。
///
/// ⚠️ 桌面目标是 **Windows**（我们的开发机是 Linux，不出 Linux 桌面包）。
/// `sgit-ffi` 的内核符号还没写完，所以这里暂时回落到 mock —— 桌面端的对话链
/// 与 Web 是两条独立的壳，Web 先跑通。
///
/// 补完后这里换成 `dart:ffi` 调 `sgit_ffi.dll` 的 `sgit_kernel_*`，
/// 上层（`ChatController` 及全部 UI）一行不用改。
KernelClient createKernelClient() => MockKernelClient();
