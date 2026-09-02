import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/core/contracts/kernel_ops.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_frame.dart';

/// [KernelClient] 的 **Web 实现** —— 转发给 `sgit-ffi-web` 的 WASM。
///
/// ## 这里刻意只有转发
/// 连接、重连、协议收敛、帧编码、delta 合并、截断、背压，全在 Rust 侧
/// （`sgit-kernel` crate，与桌面 `.so` 共用同一份）。本文件只做三件事：
/// 1. `js_interop` 转发；
/// 2. `Uint8Array` → `Uint8List` 的零拷贝转换；
/// 3. 把 JS 唤醒回调接到 Dart 的 `KernelClient.setWaker` 上。
///
/// **Web 上 Dart 没有真多线程**（`compute` 是同步执行），所以重活只能压给 wasm ——
/// 这就是整个 FFI 方案在 Web 上的全部意义，别把任何解析搬回 Dart。
final class WebKernelClient implements KernelClient {
  WebKernelClient();

  final KernelFrameReader _reader = KernelFrameReader();
  KernelCapabilities? _caps;

  @override
  KernelCapabilities? get capabilities => _caps;

  @override
  Future<KernelCapabilities> open(
      {void Function(KernelConnectProgress)? onProgress}) async {
    final k = _kernel;
    if (k == null) {
      throw const KernelException('内核 WASM 未引导（web/index.html 的 glue 丢了？）');
    }

    // ⚠️ **建连后重新注册 waker**。控制器在 `build()` 里就注册了，那时 wasm 侧
    // 还没有连接对象。wasm 现在把 waker 存在独立位置、不再依赖注册顺序，
    // 这里再灌一次是第二道保险 —— 少了它，帧会堆在 wasm 里没人取，
    // 表现为"服务端一切正常，但界面永远收不到回复"（真踩过，查了很久）。
    final w = _waker;
    if (w != null) k.setWaker((() => w()).toJS);

    // 传空串 = 按当前页面同源推导 ws 地址。生产就该走这条：nginx 已把
    // /sgcode-kernel/ws 反代到 gateway，前端不需要配置任何 IP。
    if (!k.open('')) {
      throw const KernelException('内核连接建立失败');
    }

    // 等 hello（gateway 的能力协商）。连不上时不能无限等 —— 给个上限，
    // 超时明确报错，比转圈到天荒地老好。
    final caps = await _awaitCaps(k, onProgress);
    _caps = caps;
    return caps;
  }

  Future<KernelCapabilities> _awaitCaps(
    _SgitKernelJs k,
    void Function(KernelConnectProgress)? onProgress,
  ) async {
    // ⚠️ **必须大于 gateway 的沙箱等待上限**（那边是 30s）。客户端先超时的话，
    // 我们会判连接失败并重连，而每次重连 gateway 又拉一次沙箱 —— 连接越堆越多
    // （现网见过同一 cid 同时 6 条）。这里留足余量。
    const timeout = Duration(seconds: 45);
    const poll = Duration(milliseconds: 50);
    final deadline = DateTime.now().add(timeout);

    onProgress?.call(
        const KernelConnectProgress(phase: KernelConnectPhase.connecting));

    while (DateTime.now().isBefore(deadline)) {
      // 先看进度：沙箱冷启动期间只有它在动，界面靠它才有东西显示。
      if (onProgress != null) {
        final rawStatus = k.connectStatus().toDart;
        if (rawStatus != 'null' && rawStatus.isNotEmpty) {
          final j = jsonDecode(rawStatus);
          if (j is Map<String, Object?>) {
            onProgress(KernelConnectProgress(
              phase: KernelConnectPhase.fromWire(j['phase']),
              elapsedSecs: _int(j['elapsedSecs']),
              timeoutSecs: _int(j['timeoutSecs']),
            ));
          }
        }
      }

      final raw = k.caps().toDart;
      if (raw != 'null' && raw.isNotEmpty) {
        final j = jsonDecode(raw);
        if (j is Map<String, Object?>) {
          return KernelCapabilities(
            // 中继模式下客户端与 gateway 谈的是**中继协议版本**；帧格式版本由
            // wasm 与 Dart 共用一份常量保证，不用协商（同一次构建产出）。
            frameVersion: kKernelFrameVersion,
            methods: _ops(j['ops']),
            features: const {'relay'},
          );
        }
      }
      await Future<void>.delayed(poll);
    }
    throw const KernelException('内核连接超时（gateway 未响应）');
  }

  static int _int(Object? v) => switch (v) {
        final num n => n.toInt(),
        final String s => int.tryParse(s) ?? 0,
        _ => 0,
      };

  static Set<String> _ops(Object? v) => switch (v) {
        final List<Object?> l => l.whereType<String>().toSet(),
        _ => const <String>{},
      };

  @override
  void close() => _kernel?.close();

  /// 最近注册的 waker。`open()` 之后要重新灌一次（见下）。
  void Function()? _waker;

  @override
  void setWaker(void Function() waker) {
    // JS 侧的唤醒可能在任意时机来，Dart 侧只该置脏 + scheduleFrame（见控制器）。
    _waker = waker;
    _kernel?.setWaker((() => waker()).toJS);
  }

  @override
  KernelFrameBatch? drain() {
    final k = _kernel;
    if (k == null) return null;
    // `.toDart` 给的是同一块内存的视图，不复制。
    final Uint8List bytes = k.drain().toDart;
    if (bytes.isEmpty) return null;
    // count 传 0：Web 侧拿不到帧数，读取器按缓冲长度自己走完。
    return _reader.read(bytes, 0);
  }

  @override
  void call(KernelOp op, Map<String, Object?> params, int reqId) {
    // ⚠️ 中继是**受限动作集**，不是通用 JSON-RPC 转发 —— 网关是多租户边界，
    // 放开任意方法等于把沙箱 app-server 的全部能力暴露给浏览器。
    switch (op) {
      case KernelOp.send:
        _kernel?.send(
          (params['text'] ?? '').toString().toJS,
          (params['model'] as String?)?.toJS,
        );
      // 这几个有各自的专用入口（interrupt/steer/respond），不走 call。
      case KernelOp.interrupt:
      case KernelOp.steer:
      case KernelOp.approve:
      case KernelOp.ping:
        debugPrint('[kernel] ${op.wire} 应走专用入口，不该经 call');
    }
  }

  @override
  Future<Map<String, Object?>> gatewayCall(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
  }) async {
    final k = _kernel;
    if (k == null) throw const KernelException('内核 WASM 未引导');

    // ⚠️ 身份头由 **wasm** 拼：会话 token 只在那边（Dart 有意拿不到，见
    // auth_controller 的注释）。Dart 直接 fetch 就得把 token 交出来，破坏这个模型。
    final raw = await k
        .gatewayCall(path.toJS, method.toJS, body == null ? null : jsonEncode(body).toJS)
        .toDart;
    final decoded = jsonDecode(raw.toDart);
    if (decoded is! Map<String, Object?>) {
      throw const KernelException('网关响应格式异常');
    }
    // 失败信封统一在这里抛，各仓储不用each自己判一遍。
    if (decoded['status'] == 'fail' || decoded['status'] == 'error') {
      throw KernelException(decoded['message']?.toString() ?? '请求失败');
    }
    return decoded;
  }

  @override
  void setThread(String? threadId) =>
      _kernel?.setThread((threadId ?? '').toJS);

  @override
  void interrupt(String turnId) => _kernel?.interrupt();

  @override
  void steer(String turnId, String text) => _kernel?.steer(text.toJS);

  @override
  void respond(int reqId, ApprovalDecision decision) =>
      _kernel?.respond(reqId.toJS, decision.wire.toJS);
}

@JS('__sgitKernel')
external _SgitKernelJs? get _kernel;

extension type _SgitKernelJs._(JSObject _) implements JSObject {
  external bool open(String url);
  external void close();
  external void setWaker(JSFunction waker);
  external JSUint8Array drain();
  external JSString caps();

  /// 建连进度（`kernelStatus`）。握手期间唯一在动的东西。
  external JSString connectStatus();
  external void send(JSString text, JSString? model);
  external void interrupt();
  external void steer(JSString text);
  external bool respond(JSNumber reqId, JSString decision);
  external void setThread(JSString threadId);
  external JSPromise<JSString> gatewayCall(
      JSString path, JSString method, JSString? body);
}
