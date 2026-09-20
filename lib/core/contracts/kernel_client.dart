import 'package:flutter/foundation.dart';

import 'package:sgit_studio_flutter/core/contracts/kernel_ops.dart';
import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_frame.dart';

/// 内核通道契约 —— 上层**只认这个接口**，不认桌面 `.so` / Web wasm / mock 的差别。
///
/// 三个实现：
/// - `kernel_client_io.dart`   桌面：`dart:ffi` 调 `libsgit_ffi.so` / `sgit_ffi.dll`
/// - `kernel_client_web.dart`  Web：`js_interop` 调 `sgit_ffi_web`（wasm）
/// - `kernel_client_mock.dart` 开发/测试：自己产真帧，不连后端
///
/// 符号与帧格式见 `docs/KERNEL_FFI.md`。
abstract interface class KernelClient {
  /// 建连并完成能力协商。失败抛 [KernelException]。
  /// 建立连接并完成能力协商。
  ///
  /// [onProgress] 在握手期间**持续**回调（沙箱冷启动可能几十秒）。界面拿它显示
  /// "在做什么、等了多久" —— 全程静默的等待和卡死在用户看来没有区别。
  Future<KernelCapabilities> open({
    void Function(KernelConnectProgress)? onProgress,
    EngineMode engineMode = EngineMode.defaults,
  });

  /// 关闭连接、释放所有缓冲。幂等。
  void close();

  KernelCapabilities? get capabilities;

  /// 注册唤醒回调。native 有新帧时触发。
  ///
  /// ⚠️ 回调可能在**任意 native 线程**发生，实现侧必须用 `NativeCallable.listener`。
  /// 调用方在回调里**只许置脏 + `scheduleFrame()`**，不许直接 [drain]。
  void setWaker(void Function() waker);

  /// 取走当前批次的帧。无帧返回 `null`。
  ///
  /// ⚠️ 返回的 payload 是 native 内存的零拷贝视图，**只在本次同步调用栈内有效**。
  /// 要跨帧保留内容就自己 copy。实现负责在返回前调 `sgit_kernel_release`。
  KernelFrameBatch? drain();

  /// 投递一次内核请求（非阻塞）。应答以 `callResult` 帧回来，`itemId == reqId`。
  void call(KernelOp op, Map<String, Object?> params, int reqId);

  /// gateway HTTP 端点桥接（8 个 studio 子页用）。复用同一会话与加密。
  Future<Map<String, Object?>> gatewayCall(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
  });

  /// 切换当前会话。传 `null` 表示下次发消息时新建 thread。
  void setThread(String? threadId);

  void interrupt(String turnId);

  /// 中途插话改方向（对应 CLI 的 `turn/steer`）。
  void steer(String turnId, String text);

  /// 回应审批 / serverRequest。[reqId] 取自 `approval` 帧。
  void respond(int reqId, ApprovalDecision decision);
}

/// 能力协商结果。
///
/// ⚠️ **禁止硬编码方法名清单** —— app-server-protocol 里一堆 `#[experimental]`，
/// 内核升协议时靠这份清单显隐 UI，硬编码就碎。
/// 建连进度。来自 gateway 的 `kernelStatus` 事件。
@immutable
final class KernelConnectProgress {
  const KernelConnectProgress({
    required this.phase,
    this.elapsedSecs = 0,
    this.timeoutSecs = 0,
  });

  /// 机器可读的阶段。**文案不在这里** —— 展示语要本地化、要能随时增删，
  /// 归 UI 层（见 `connect_status_line.dart` 的轮播词表）。
  final KernelConnectPhase phase;

  final int elapsedSecs;
  final int timeoutSecs;

  /// 0..1 的进度，超时预算未知时返回 null。
  double? get ratio =>
      timeoutSecs <= 0 ? null : (elapsedSecs / timeoutSecs).clamp(0.0, 1.0);
}

enum KernelConnectPhase {
  /// 刚发起，还没收到任何服务端进度。
  connecting,

  /// 正在拉起/等待用户的沙箱容器与 app-server。这一步最慢。
  sandboxStarting,

  /// 沙箱就绪，等 hello。
  ready;

  static KernelConnectPhase fromWire(Object? v) => switch (v) {
        'sandboxStarting' => KernelConnectPhase.sandboxStarting,
        'ready' => KernelConnectPhase.ready,
        _ => KernelConnectPhase.connecting,
      };
}

final class KernelCapabilities {
  const KernelCapabilities({
    required this.frameVersion,
    required this.methods,
    required this.features,
  });

  final int frameVersion;
  final Set<String> methods;
  final Set<String> features;

  /// 是否支持某个中继动作。
  ///
  /// ⚠️ **只收 [KernelOp]，不收裸字符串** —— 裸字符串正是上次线上事故的成因：
  /// 检查的是 `turn/start`，而 gateway 报的是 `send`，永远不匹配。
  bool supports(KernelOp op) => methods.contains(op.wire);
  bool hasFeature(String feature) => features.contains(feature);

  /// 帧格式版本不匹配即不可用 —— 不降级、不兼容，直接提示升级客户端。
  bool get isCompatible => frameVersion == kKernelFrameVersion;

  static KernelCapabilities fromJson(Map<String, Object?> j) =>
      KernelCapabilities(
        frameVersion: (j['frame_version'] as num?)?.toInt() ?? 0,
        methods: _stringSet(j['methods']),
        features: _stringSet(j['features']),
      );

  static Set<String> _stringSet(Object? v) => switch (v) {
        final List<Object?> l =>
          l.whereType<String>().toSet(),
        _ => const <String>{},
      };
}

/// 审批决定。
///
/// ⚠️ 取值**直接用协议的**（`CommandExecutionApprovalDecision` 等，camelCase），
/// 不自己编一套再翻译 —— 中间多一层映射就多一处会漂移的地方。
/// 见 `sgcode-rs/app-server-protocol/src/protocol/v2/item.rs`。
enum ApprovalDecision {
  accept('accept'),
  acceptForSession('acceptForSession'),
  decline('decline');

  const ApprovalDecision(this.wire);
  final String wire;
}

final class KernelException implements Exception {
  const KernelException(this.message, {this.fatal = false});
  final String message;
  final bool fatal;

  @override
  String toString() => 'KernelException: $message';
}
