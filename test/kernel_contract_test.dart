import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/features/chat/application/chat_ports_impl.dart';
import 'package:sgit_studio_flutter/core/contracts/gateway_endpoints.dart';
import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_frame.dart';
import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/core/contracts/kernel_ops.dart';
import 'package:sgit_studio_flutter/features/studio/studio_page_specs.dart';

/// 两端词汇的契约测试。
///
/// 背景：gateway 的 hello 报 `["send","interrupt","steer","approve","ping"]`，
/// 而 Dart 一度在检查 `turn/start`（app-server 的内层方法名）—— 永远匹配不上，
/// 每次发送都被判"内核不支持"并触发无限重连。当时 mock 声明的又是 `turn/start`
/// 那一套，所以单测全绿、线上全坏。
///
/// 这条测试把 gateway 侧的字面值**抄死在这里**：Rust 那边改了 ops 而没改这里，
/// 测试就会红，而不是等到用户报"发消息没反应"。
///
/// 对应源码：`sgcode-rs/sgit-services/src/bin/gateway_kernel_ws.rs` 里
/// hello 的 `"ops"` 数组，以及 `ClientFrame` 的 serde tag。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _wakerOrderTests();

  _endpointVerbTests();

  test('中继动作词汇与 gateway 的 hello ops 完全一致', () {
    // ⚠️ 改这个列表前，先确认 gateway_kernel_ws.rs 也改了。
    const gatewayOps = <String>{
      'send',
      'interrupt',
      'steer',
      'approve',
      'ping',
    };

    final dartOps = {for (final o in KernelOp.values) o.wire};

    expect(dartOps, gatewayOps,
        reason: '两端动作词汇必须逐字相同，否则能力检查永远为假');
  });

  test('动作名不能是 app-server 的内层方法名', () {
    // 这些是沙箱 app-server 的方法名，**不是**中继动作名。混用就是上次的事故。
    const innerMethodNames = {
      'turn/start',
      'turn/steer',
      'turn/interrupt',
      'thread/start',
      'thread/list',
    };
    for (final o in KernelOp.values) {
      expect(innerMethodNames.contains(o.wire), isFalse,
          reason: '${o.wire} 是 app-server 内层方法名，中继层不该用它');
    }
  });
}

/// 端点动词的契约测试。见 `gateway_endpoints.dart` 的说明（MCP 的 405 事故）。
void _endpointVerbTests() {
  test('页面 spec 里用到的每个端点都登记了动词', () {
    final specs = [
      StudioPageSpecs.scenes,
      StudioPageSpecs.subagent,
      StudioPageSpecs.skill,
      StudioPageSpecs.mcp,
      StudioPageSpecs.knowledge,
    ];
    for (final s in specs) {
      for (final p in [s.listPath, s.removePath, s.refreshPath]) {
        if (p == null) continue;
        // 未登记会抛 —— 那正是我们要在测试里而不是在用户面前发现的。
        expect(() => verbFor(p), returnsNormally,
            reason: '$p 未登记动词，运行时会 405 或抛异常');
      }
    }
  });

  test('MCP 的 list 是 POST（与其它页不同，曾造成 405）', () {
    expect(verbFor('/sgcode-mcp/list'), HttpVerb.post);
    expect(verbFor('/sgcode-scene/list'), HttpVerb.get);
  });

  test('未登记的端点必须抛，不许静默猜一个动词', () {
    expect(() => verbFor('/sgcode-nonexistent/list'), throwsArgumentError);
  });
}

/// waker 注册顺序的回归防线。
///
/// 背景：控制器在 `build()` 里注册 waker，而那时传输层还没 `open()`。
/// wasm 侧原先把 waker 存在「连接对象」里，于是这次注册被静默丢弃 ——
/// 服务端一路正常（收到动作、建了 thread、模型也采样完成），帧却堆在 wasm 里
/// 没人来取，界面上就是"发出去了，永远没有回复"。
void _wakerOrderTests() {
  test('open() 之前注册的 waker 必须仍然有效', () async {
    final stub = _WakerProbe();
    final c = ChatController(client: stub);
    final container = ProviderContainer(overrides: [
 chatPortsOverride,
      chatControllerProvider.overrideWith(() => c),
    ]);
    addTearDown(container.dispose);

    // 读一次触发 build() —— 这里就注册 waker，且**先于** connect()。
    container.read(chatControllerProvider);
    expect(stub.wakerSetBeforeOpen, isTrue,
        reason: '控制器就是在 open() 之前注册的，这个前提不能变');

    await container.read(chatControllerProvider.notifier).connect();

    // 连上之后 waker 必须仍在（不能因为 open 重建连接而丢）。
    expect(stub.waker, isNotNull, reason: 'open() 不许把 waker 弄丢');
    stub.waker!();
    expect(stub.wakeCount, 1);
  });
}

/// 只关心 waker 何时被注册、注册后还在不在。
final class _WakerProbe implements KernelClient {
  void Function()? waker;
  bool opened = false;
  bool wakerSetBeforeOpen = false;
  int wakeCount = 0;

  @override
  KernelCapabilities? capabilities;

  @override
  void setWaker(void Function() w) {
    if (!opened) wakerSetBeforeOpen = true;
    waker = () {
      wakeCount++;
      w();
    };
  }

  @override
  Future<KernelCapabilities> open({
    void Function(KernelConnectProgress)? onProgress,
    EngineMode engineMode = EngineMode.defaults,
  }) async {
    opened = true;
    return capabilities = KernelCapabilities(
      frameVersion: kKernelFrameVersion,
      methods: {for (final o in KernelOp.values) o.wire},
      features: const {'probe'},
    );
  }

  @override
  void close() {}
  @override
  KernelFrameBatch? drain() => null;
  @override
  void call(KernelOp op, Map<String, Object?> params, int reqId) {}
  @override
  Future<Map<String, Object?>> gatewayCall(String path,
          {String method = 'GET', Map<String, Object?>? body}) async =>
      const {};
  @override
  void interrupt(String turnId) {}
  @override
  void steer(String turnId, String text) {}
  @override
  void respond(int reqId, ApprovalDecision decision) {}
  @override
  void setThread(String? threadId) {}
}
