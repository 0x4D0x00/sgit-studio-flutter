import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_io.dart';

/// 桌面 / 移动（io）侧的内核通道：`dart:ffi` 调 `sgit_ffi.dll` / `libsgit_ffi.so`
/// 的 `sgit_kernel_*` 符号 → gateway `/sgcode-kernel/ws` → 该 cid 的 docker 沙箱。
///
/// 与 Web 那条是**同一套中继协议、同一份帧格式**，只换了传输壳
/// （Web 是 wasm + web_sys::WebSocket，这边是 cdylib + tokio + tungstenite）。
///
/// 需要 mock 时由测试自己注入（`ChatController(client: MockKernelClient())`），
/// 不在这里按编译期开关切 —— 生产路径与测试路径靠同一个 [KernelClient] 接口分开，
/// 而不是靠这个工厂。
KernelClient createKernelClient() => IoKernelClient();
