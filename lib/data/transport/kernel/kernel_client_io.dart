import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
// Uint8List 也从这里来（foundation 已导出 typed_data），不另 import。
import 'package:flutter/foundation.dart';

import 'package:sgit_studio_flutter/core/config/runtime_config.dart';
import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/core/contracts/kernel_ops.dart';
import 'package:sgit_studio_flutter/data/transport/ffi/sgit_request_ffi_io.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_frame.dart';
import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';

// ---- C 函数签名（对齐 sgcode-rs/sgit-ffi/src/kernel.rs）----
//
// 符号名与语义**与 Web 的 wasm 导出逐一相同**（契约 §1、§8 第一条验收项）。
// 差异只在 C ABI 的表达方式，见契约 §5 的映射表：
//   Web  drain() -> Uint8Array          桌面 drain(**out, *len) -> u32 + release
//   Web  setWaker(jsCallback)           桌面 set_waker(函数指针)
//   Web  其余 String                     桌面 char*（用 free_string 释放）

typedef _OpenC = Bool Function(Pointer<Utf8> url);
typedef _OpenDart = bool Function(Pointer<Utf8> url);

typedef _OpenLocalC = Bool Function();
typedef _OpenLocalDart = bool Function();

typedef _VoidC = Void Function();
typedef _VoidDart = void Function();

typedef _SetWakerC = Void Function(Pointer<NativeFunction<Void Function()>>);
typedef _SetWakerDart = void Function(Pointer<NativeFunction<Void Function()>>);

typedef _DrainC = Uint32 Function(Pointer<Pointer<Uint8>> out, Pointer<Uint32> outLen);
typedef _DrainDart = int Function(Pointer<Pointer<Uint8>> out, Pointer<Uint32> outLen);

typedef _ReleaseC = Void Function(Pointer<Uint8> buf);
typedef _ReleaseDart = void Function(Pointer<Uint8> buf);

typedef _StrRetC = Pointer<Utf8> Function();
typedef _StrRetDart = Pointer<Utf8> Function();

typedef _SendC = Void Function(Pointer<Utf8> text, Pointer<Utf8> model);
typedef _SendDart = void Function(Pointer<Utf8> text, Pointer<Utf8> model);

typedef _Str1C = Void Function(Pointer<Utf8> s);
typedef _Str1Dart = void Function(Pointer<Utf8> s);

typedef _RespondC = Bool Function(Uint64 reqId, Pointer<Utf8> decision);
typedef _RespondDart = bool Function(int reqId, Pointer<Utf8> decision);

typedef _GatewayC = Pointer<Utf8> Function(
    Pointer<Utf8> path, Pointer<Utf8> method, Pointer<Utf8> body);
typedef _GatewayDart = Pointer<Utf8> Function(
    Pointer<Utf8> path, Pointer<Utf8> method, Pointer<Utf8> body);

typedef _FreeC = Void Function(Pointer<Utf8> ptr);
typedef _FreeDart = void Function(Pointer<Utf8> ptr);

/// [KernelClient] 的 **桌面 / 移动实现** —— `dart:ffi` 调 `sgit_ffi.dll` / `libsgit_ffi.so`。
///
/// ## 这里刻意只有转发
/// 连接、协议收敛、帧编码、delta 合并、截断、背压，全在 Rust 侧
/// （`sgit-kernel` crate，与 Web 的 wasm 共用同一份）。本文件只做四件事：
/// 1. `dart:ffi` 转发；
/// 2. native 缓冲 → `Uint8List` 的搬运与归还；
/// 3. 把 native 唤醒回调接到 [KernelClient.setWaker] 上（`NativeCallable.listener`）；
/// 4. 从 [RuntimeConfig] 推出 gateway 的 ws 地址。
///
/// **不要把任何解析搬回 Dart** —— 流式对话的 CPU 大头是 JSON→对象，
/// 在 Dart 侧做整个 FFI 方案就白费了。
final class IoKernelClient implements KernelClient {
  IoKernelClient();

  final KernelFrameReader _reader = KernelFrameReader();
  KernelCapabilities? _caps;

  // ---- 动态库与符号 ----

  static DynamicLibrary _openLib() {
    if (Platform.isWindows) return DynamicLibrary.open('sgit_ffi.dll');
    if (Platform.isMacOS) return DynamicLibrary.open('libsgit_ffi.dylib');
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('libsgit_ffi.so');
    }
    // iOS 走静态链接进 Runner，符号在主可执行文件里。
    if (Platform.isIOS) return DynamicLibrary.process();
    throw UnsupportedError('当前平台不支持 sgit_ffi');
  }

  late final DynamicLibrary _lib = _openLib();

  late final _OpenDart _kOpen =
      _lib.lookupFunction<_OpenC, _OpenDart>('sgit_kernel_open');
  late final _OpenLocalDart _kOpenLocal =
      _lib.lookupFunction<_OpenLocalC, _OpenLocalDart>('sgit_kernel_open_local');
  late final _VoidDart _kClose =
      _lib.lookupFunction<_VoidC, _VoidDart>('sgit_kernel_close');
  late final _SetWakerDart _kSetWaker =
      _lib.lookupFunction<_SetWakerC, _SetWakerDart>('sgit_kernel_set_waker');
  late final _DrainDart _kDrain =
      _lib.lookupFunction<_DrainC, _DrainDart>('sgit_kernel_drain');
  late final _ReleaseDart _kRelease =
      _lib.lookupFunction<_ReleaseC, _ReleaseDart>('sgit_kernel_release');
  late final _StrRetDart _kCaps =
      _lib.lookupFunction<_StrRetC, _StrRetDart>('sgit_kernel_caps');
  late final _StrRetDart _kConnectStatus = _lib
      .lookupFunction<_StrRetC, _StrRetDart>('sgit_kernel_connect_status');
  late final _SendDart _kSend =
      _lib.lookupFunction<_SendC, _SendDart>('sgit_kernel_send');
  late final _VoidDart _kInterrupt =
      _lib.lookupFunction<_VoidC, _VoidDart>('sgit_kernel_interrupt');
  late final _Str1Dart _kSteer =
      _lib.lookupFunction<_Str1C, _Str1Dart>('sgit_kernel_steer');
  late final _RespondDart _kRespond =
      _lib.lookupFunction<_RespondC, _RespondDart>('sgit_kernel_respond');
  late final _Str1Dart _kSetThread =
      _lib.lookupFunction<_Str1C, _Str1Dart>('sgit_kernel_set_thread');
  late final _GatewayDart _kGatewayCall =
      _lib.lookupFunction<_GatewayC, _GatewayDart>('sgit_gateway_call');
  late final _FreeDart _free =
      _lib.lookupFunction<_FreeC, _FreeDart>('free_string');

  /// drain 的出参。**只分配一次** —— 每帧都 malloc/free 两个字长是白烧 CPU，
  /// 而 drain 是热路径上唯一按帧调用的入口。
  late final Pointer<Pointer<Uint8>> _outBuf = calloc<Pointer<Uint8>>();
  late final Pointer<Uint32> _outLen = calloc<Uint32>();

  // ---- 建连 ----

  @override
  KernelCapabilities? get capabilities => _caps;

  /// gateway 的内核 ws 地址。
  ///
  /// ⚠️ 桌面**没有「同源」可推导**（那是 Web 的路子：nginx 已把 `/sgcode-kernel/ws`
  /// 反代到 gateway，所以 Web 传空串即可）。桌面必须显式给地址，且
  /// **禁止在此写死任何域名** —— 见 [RuntimeConfig] 开头那段：sgcode 内置端点池
  /// 默认指向我方域名，客户私有化部署后登录/验证码全打回我方，既泄露又打不通。
  static String _kernelWsUrl() {
    // ⚠️ 用 **gateway** 基址，不是后端 API 基址 —— 两者可能是不同入口：
    // gateway 只绑 127.0.0.1:8788 不对外，经 nginx 反代出来（如 :18088），
    // 而 Go 后端 API 在另一个端口（如 :32717）。用错了就是
    // 「云端对话 404」或「本地推理打到 SPA 首页」。
    // 同机部署时 gatewayBaseUrl 自动回落到 apiBaseUrl，不用额外配。
    //
    // ⚠️ 用户不会去设环境变量。没有显式配置时，**跟随 Rust `ApiConfig` 选中的端点**
    // —— 登录、模型同步、本地引擎用的就是它（代码内置端点池 + 探测，
    // `SGIT_API_BASE_URL` 可覆盖）。默认值只有 Rust 那一处，Dart 不另写死地址；
    // 以前这里只读环境变量，没设就报「后端地址未配置」，而登录明明是通的。
    //
    // gateway 同理：它和后端 API **不在同一个端口**（后端 32717、gateway 经 nginx 在
    // 18088），只跟随后端地址会连到没有 `/sgcode-kernel/ws` 的端口 → 404。
    if (!RuntimeConfig.isConfigured || !RuntimeConfig.isGatewayConfigured) {
      final probed = SgitRequestFfi.instance.probeEndpoint();
      if (!RuntimeConfig.isConfigured) {
        RuntimeConfig.applyOverride(probed.baseUrl);
      }
      if (!RuntimeConfig.isGatewayConfigured) {
        RuntimeConfig.applyGatewayOverride(probed.gatewayUrl);
      }
      debugPrint('[kernel] 未显式配置地址，跟随 sgcode 端点: '
          'api=${probed.baseUrl} gateway=${probed.gatewayUrl}');
    }
    final base = RuntimeConfig.gatewayBaseUrl; // Rust 也给不出地址时才抛 StateError
    final ws = base.startsWith('https://')
        ? base.replaceFirst('https://', 'wss://')
        : base.replaceFirst('http://', 'ws://');
    return '$ws/sgcode-kernel/ws';
  }

  @override
  Future<KernelCapabilities> open({
    void Function(KernelConnectProgress)? onProgress,
    EngineMode engineMode = EngineMode.defaults,
  }) async {
    // ⚠️ **建连后重新注册 waker**。控制器在 `build()` 里就注册了，那时 native 侧
    // 还没有连接对象。native 现在把 waker 存在独立槽位、不再依赖注册顺序
    // （见 kernel.rs 的 waker_slot 注释），这里再灌一次是第二道保险 ——
    // 少了它，帧会堆在 native 里没人取，表现为"服务端一切正常，但界面永远收不到回复"。
    _pushWakerToNative();

    final bool started;

    // 根据 engineMode 决定调用本地还是云上路径
    if (engineMode == EngineMode.local) {
      // ① 本地路：进程内 LocalEngine（无需后端地址）
      // ⚠️ 这条日志**别删**：两条路的行为高度相似（同一套帧、同一套动作），
      // 出问题时光看界面分不清"这次回答到底谁给的"。native 侧的 log 又被
      // cdylib 吞掉（没装 logger），Dart 这行是唯一能一眼确认走哪条路的地方。
      debugPrint('[kernel] 建连模式=本地引擎（进程内 app-server，不经 gateway）');
      started = _kOpenLocal();
    } else {
      // ② 云上路：经 gateway 连 docker 沙箱
      final String url;
      try {
        url = _kernelWsUrl();
      } on StateError catch (e) {
        throw KernelException('后端地址未配置：${e.message}', fatal: true);
      }

      debugPrint('[kernel] 建连模式=云端引擎 → $url');
      final urlPtr = url.toNativeUtf8();
      try {
        started = _kOpen(urlPtr);
      } finally {
        malloc.free(urlPtr);
      }
    }

    if (!started) {
      // native 侧拒绝的两种情形：
      // - 云上路：地址空、或没有进程内会话（未登录 / 进程重启后未恢复）
      // - 本地路：引擎初始化失败
      throw KernelException(engineMode == EngineMode.local
          ? '本地引擎初始化失败（会话已失效，请重新登录）'
          : '内核连接建立失败（地址无效或会话已失效，请重新登录）');
    }

    final caps = await _awaitCaps(onProgress, engineMode);
    _caps = caps;
    // ⚠️ **成功也要留一行**。失败路径各有各的日志，成功路径原先一个字都不打 ——
    // 于是"连上了"和"卡在 45s 轮询里"在日志上长得**一模一样**（都是建连那行之后
    // 一片空白），排查时只能靠界面猜。踩过：服务端探针已经能收到 hello，却分不清
    // 客户端到底成了没成。
    debugPrint('[kernel] 建连成功，动作=${caps.methods.toList()..sort()}');
    return caps;
  }

  /// 等 `hello`（gateway 的能力协商）。与 Web 侧同一套超时与轮询节奏。
  /// [engineMode] 只用来**说对话** —— 两条路共用这个循环，但错误里提到的东西
  /// 必须分开。
  ///
  /// ⚠️ 实测踩过：同事选**本地引擎**，收到的是「内核连接超时（gateway 未响应）」
  /// —— 本地模式压根不碰 gateway。他和我们都被这句话带偏，真正的原因
  /// （他机器上没有 sgcode 可执行文件）在 native 侧被吞掉了。
  Future<KernelCapabilities> _awaitCaps(
    void Function(KernelConnectProgress)? onProgress,
    EngineMode engineMode,
  ) async {
    final isLocal = engineMode == EngineMode.local;
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
      final status = _takeJson(_kConnectStatus());
      if (status != null) {
        // ⚠️ **握手期就失败要立刻报，别等满 45 秒。**
        //
        // 断开是通过帧推的，而这里只轮询 caps/status、不读帧（帧归会话控制器）。
        // 所以握手阶段的硬失败——比如 nginx 没给 `/sgcode-kernel/ws` 配 WS 升级头、
        // 直接回 400——对这个循环原本完全不可见，界面会一直停在"正在校验身份"
        // 直到超时，而真实原因第一秒就知道了（实测踩过）。
        if (status['phase'] == 'failed') {
          final reason = status['reason']?.toString() ?? '未知原因';
          throw KernelException(
              isLocal ? '本地引擎启动失败：$reason' : '云端引擎连接失败：$reason');
        }
        onProgress?.call(KernelConnectProgress(
          phase: KernelConnectPhase.fromWire(status['phase']),
          elapsedSecs: _int(status['elapsedSecs']),
          timeoutSecs: _int(status['timeoutSecs']),
        ));
      }

      final caps = _takeJson(_kCaps());
      if (caps != null) {
        return KernelCapabilities(
          // 中继模式下客户端与 gateway 谈的是**中继协议版本**；帧格式版本由
          // native 与 Dart 共用一份常量保证，不用协商（同一次构建产出）。
          frameVersion: kKernelFrameVersion,
          methods: _ops(caps['ops']),
          features: const {'relay'},
          // 本地引擎可能"起来了但少了东西"（没找到 sgcode 可执行文件 →
          // 命令类工具不可用）。云端路不会有这个字段，解出来就是空集。
          degraded: _strSet(caps['degraded']),
        );
      }
      await Future<void>.delayed(poll);
    }
    throw KernelException(isLocal
        ? '本地引擎启动超时（引擎未就绪）'
        : '内核连接超时（gateway 未响应）');
  }

  /// 取一个 native 返回的 JSON 字符串并释放它。`"null"` / 空 / 非对象都返回 null。
  Map<String, Object?>? _takeJson(Pointer<Utf8> ptr) {
    if (ptr == nullptr) return null;
    final String raw;
    try {
      raw = ptr.toDartString();
    } finally {
      _free(ptr);
    }
    if (raw.isEmpty || raw == 'null') return null;
    final decoded = jsonDecode(raw);
    return decoded is Map<String, Object?> ? decoded : null;
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

  /// 同 [_ops]，但语义是"降级项"。字段缺失（云端路）解成空集 —— **不是**错误。
  static Set<String> _strSet(Object? v) => _ops(v);

  @override
  void close() {
    _kClose();
    _caps = null;
    // ⚠️ 刻意**不** close `_wakerCallable`：native 侧的 waker 是客户端级的、
    // 跨连接存活（见 kernel.rs），close 掉函数指针后它下一次调用就是野指针。
    // 通道对象与进程同寿，随进程退出一起回收。
  }

  // ---- 唤醒 ----

  void Function()? _waker;
  NativeCallable<Void Function()>? _wakerCallable;

  @override
  void setWaker(void Function() waker) {
    _waker = waker;
    _pushWakerToNative();
  }

  void _pushWakerToNative() {
    final w = _waker;
    if (w == null) return;

    // ⚠️ native 可能在**任意线程**触发唤醒，所以必须是 `listener`（回调经 Dart
    // 事件循环投递）而不是 `isolateLocal` —— 后者从非 Dart 线程调用直接是未定义行为。
    // 回调里只许置脏 + `scheduleFrame()`，绝不在这里 drain（契约 §4）。
    _wakerCallable ??= () {
      final cb = NativeCallable<Void Function()>.listener(() {
        _waker?.call();
      });
      // 别让这个长期回调把 isolate 钉住不退出。
      cb.keepIsolateAlive = false;
      return cb;
    }();

    _kSetWaker(_wakerCallable!.nativeFunction);
  }

  // ---- 热路径 ----

  @override
  KernelFrameBatch? drain() {
    final count = _kDrain(_outBuf, _outLen);
    final buf = _outBuf.value;
    final len = _outLen.value;
    if (buf == nullptr || len == 0) return null;

    // 一次拷贝，然后立刻把 native 缓冲还回去。
    //
    // 为什么拷贝而不是直接用 `asTypedList` 的视图：`KernelFrameReader` 产出的
    // payload 是**对入参缓冲的零拷贝视图**，release 之后那些视图就指向已释放内存。
    // Web 侧不存在这个问题 —— wasm_bindgen 返回 `Vec<u8>` 时已经拷进 JS 堆、由 GC
    // 持有，所以帧的生命周期与 batch 一致。这里拷一次是为了**让两端语义相同**，
    // 也让 mock（Dart 内存）与真通道行为一致 —— 否则就会出现"mock 全绿、真机崩"
    // 这类最难查的偏差（`kernel_ops.dart` 记着一次同类事故）。
    //
    // 代价可接受：拷贝是**每批一次**，不是每帧一次。native 已把 delta 合并成
    // ≤64KB 的帧、并对整批做背压，契约 §8 的基线是「1000 条 delta → drain < 60 次」。
    final bytes = Uint8List.fromList(buf.asTypedList(len));
    _kRelease(buf);
    // 出参用完就清零，免得下次 drain 若提前返回时读到上一批的陈值。
    _outBuf.value = nullptr;
    _outLen.value = 0;

    return _reader.read(bytes, count);
  }

  // ---- 上行动作 ----

  @override
  void call(KernelOp op, Map<String, Object?> params, int reqId) {
    // ⚠️ 中继是**受限动作集**，不是通用 JSON-RPC 转发 —— 网关是多租户边界，
    // 放开任意方法等于把沙箱 app-server 的全部能力暴露给客户端。
    switch (op) {
      case KernelOp.send:
        _send(
          (params['text'] ?? '').toString(),
          params['model'] as String?,
        );
      // 这几个有各自的专用入口（interrupt/steer/respond），不走 call。
      case KernelOp.interrupt:
      case KernelOp.steer:
      case KernelOp.approve:
      case KernelOp.ping:
        debugPrint('[kernel] ${op.wire} 应走专用入口，不该经 call');
    }
  }

  void _send(String text, String? model) {
    final pText = text.toNativeUtf8();
    final pModel = model?.toNativeUtf8() ?? nullptr;
    try {
      _kSend(pText, pModel);
    } finally {
      malloc.free(pText);
      if (pModel != nullptr) malloc.free(pModel);
    }
  }

  /// turnId 由 native 侧的 relay 自己记着（它从 `turnStarted` 事件里拿），
  /// 所以这里不传 —— 与 Web 一致。
  @override
  void interrupt(String turnId) => _kInterrupt();

  @override
  void steer(String turnId, String text) => _withStr(_kSteer, text);

  @override
  void setThread(String? threadId) => _withStr(_kSetThread, threadId ?? '');

  void _withStr(_Str1Dart fn, String s) {
    final p = s.toNativeUtf8();
    try {
      fn(p);
    } finally {
      malloc.free(p);
    }
  }

  @override
  void respond(int reqId, ApprovalDecision decision) {
    final p = decision.wire.toNativeUtf8();
    try {
      if (!_kRespond(reqId, p)) {
        // 不是错误：内核只等一次回应，重复回应或陈旧 req_id 会走到这。
        debugPrint('[kernel] 审批 req_id=$reqId 已失效，回应被忽略');
      }
    } finally {
      malloc.free(p);
    }
  }

  // ---- gateway HTTP 桥接 ----

  /// ⚠️ 身份头由 **native** 拼：会话 token 只在那边（Dart 有意拿不到，见
  /// `auth_controller.dart` 的注释）。Dart 直接发请求就得把 token 交出来，破坏这个模型。
  ///
  /// FFI 调用本身是阻塞的，签名声明成 `Future` 是为了**与 Web 实现同签名**
  /// （Web 走 fetch，天然异步），调用方两端零分叉。
  @override
  Future<Map<String, Object?>> gatewayCall(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
  }) async {
    final pPath = path.toNativeUtf8();
    final pMethod = method.toNativeUtf8();
    final pBody = body == null ? nullptr : jsonEncode(body).toNativeUtf8();
    final Map<String, Object?>? decoded;
    try {
      decoded = _takeJson(_kGatewayCall(pPath, pMethod, pBody));
    } finally {
      malloc.free(pPath);
      malloc.free(pMethod);
      if (pBody != nullptr) malloc.free(pBody);
    }

    if (decoded == null) throw const KernelException('网关响应格式异常');
    // 失败信封统一在这里抛，各仓储不用各自判一遍。
    if (decoded['status'] == 'fail' || decoded['status'] == 'error') {
      throw KernelException(decoded['message']?.toString() ?? '请求失败');
    }
    return decoded;
  }
}
