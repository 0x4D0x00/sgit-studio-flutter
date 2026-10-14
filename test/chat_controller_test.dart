import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/core/contracts/kernel_ops.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_frame.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_session.dart';
import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';

/// 会话控制器的**性能契约**测试。
///
/// 这里断言的不是"功能对不对"，而是 `docs/KERNEL_FFI.md` §8 的两条性能判据：
/// - 1000 条 delta 只触发一次 drain、一次列表通知；
/// - delta 只让**单条**气泡失效，不动整个列表。
///
/// 这两条一旦回退，长回答就会掉帧，而功能测试完全测不出来 —— 所以必须有守卫。
void main() {
  // 控制器的 waker 会碰 SchedulerBinding.instance（置脏 + scheduleFrame），
  // 所以这些纯单测也要先起 binding。这里刻意**不 pump 帧** —— 帧回调不跑，
  // 由测试自己调 drainNow()，才能精确断言"多少次唤醒合并成多少次 drain"。
  TestWidgetsFlutterBinding.ensureInitialized();

  late _StubKernel stub;
  late ProviderContainer container;
  late ChatController ctrl;

  setUp(() {
    stub = _StubKernel();
    container = ProviderContainer(overrides: [
      chatControllerProvider.overrideWith(() => ChatController(client: stub)),
    ]);
    ctrl = container.read(chatControllerProvider.notifier);
  });

  tearDown(() => container.dispose());

  // ---- 静默失败的回归防线 ----
  //
  // 对应用户实际报过的现象：**"发送出去没反应，不知道有没有发送出去，
  // 字还在输入框里"**。根因是几处 `return false` 什么提示都不给。
  // 这里全部走公开路径复现，不直接改 state。

  test('busy 时再发送：被拒 + 必须给提示，不能静默吞掉', () async {
    await ctrl.connect();
    // 第一次发送成功 → 乐观置 busy（turnStarted 还没到，这是真实中间态）。
    expect(ctrl.send('第一条'), isTrue);
    expect(container.read(chatControllerProvider).busy, isTrue);

    expect(ctrl.send('第二条'), isFalse, reason: 'busy 时不该再开一轮');
    expect(container.read(chatControllerProvider).notice, ChatNotice.busy,
        reason: '被拒必须说明原因，否则用户只看到"点了没反应"');
  });

  test('busy 但 turnStarted 未到时插话：被拒 + 必须给提示', () async {
    await ctrl.connect();
    ctrl.send('第一条');
    // 此刻 busy=true 而 turnId=null —— 正是会撞上静默 steer 的窗口。
    expect(container.read(chatControllerProvider).turnId, isNull);

    expect(ctrl.steer('改一下'), isFalse);
    expect(container.read(chatControllerProvider).notice,
        ChatNotice.noTurnToSteer);
  });

  test('turnStarted 到达后插话正常受理，并清掉上一条提示', () async {
    await ctrl.connect();
    ctrl.send('第一条');
    ctrl.steer('会被拒');
    expect(container.read(chatControllerProvider).notice, isNotNull);

    stub.emit(KernelFrameKind.turnStarted, json: {'turn_id': 't1'});
    stub.wake();
    ctrl.drainNow();

    expect(ctrl.steer('这次可以'), isTrue);
    expect(container.read(chatControllerProvider).notice, isNull,
        reason: '提示是一次性的，粘住比没提示更糟');
  });

  test('未连接就发送：不进 busy 态，并自动发起重连', () async {
    // 不 connect，直接发。
    expect(ctrl.send('你好'), isFalse);
    final st = container.read(chatControllerProvider);
    expect(st.busy, isFalse, reason: '发不出去还进 busy 会让按钮永远停在"停止"');
    // 自动重连会接管：显示建连进度比停在"未连接"更有用，所以 fault 被让位给
    // progress 是**预期行为**，不是丢提示。
    expect(st.progress, isNotNull, reason: '必须有东西在动，不能静默');
  });

  test('1000 条 delta → 一次 drain、一次列表通知、文本完整', () async {
    await ctrl.connect();

    stub.emit(KernelFrameKind.turnStarted, json: {'turn_id': 't1'});
    stub.emit(KernelFrameKind.itemStarted, itemId: 1, json: {'role': 'assistant'});
    for (var i = 0; i < 1000; i++) {
      stub.emit(KernelFrameKind.itemDelta, itemId: 1, raw: 'x');
    }
    stub.emit(KernelFrameKind.itemCompleted, itemId: 1);

    var listNotifications = 0;
    ctrl.itemsRevision.addListener(() => listNotifications++);

    stub.wake();
    ctrl.drainNow();

    expect(ctrl.drainCount, 1, reason: '一批帧只该 drain 一次');
    expect(listNotifications, 1, reason: '1000 条 delta 只该让列表通知一次');

    final text = ctrl.items.whereType<TextItem>().single;
    expect(text.text.length, 1000, reason: 'delta 一条都不能丢');
    expect(text.done, isTrue);
  });

  test('delta 只让单条气泡失效，不动其他条目', () async {
    await ctrl.connect();

    stub.emit(KernelFrameKind.itemStarted, itemId: 1, json: {'role': 'assistant'});
    stub.emit(KernelFrameKind.itemDelta, itemId: 1, raw: '第一条');
    stub.emit(KernelFrameKind.itemCompleted, itemId: 1);
    stub.emit(KernelFrameKind.itemStarted, itemId: 2, json: {'role': 'assistant'});
    stub.wake();
    ctrl.drainNow();

    final texts = ctrl.items.whereType<TextItem>().toList();
    expect(texts, hasLength(2));

    var first = 0, second = 0;
    texts[0].revision.addListener(() => first++);
    texts[1].revision.addListener(() => second++);

    // 只给第二条推 delta。
    for (var i = 0; i < 5; i++) {
      stub.emit(KernelFrameKind.itemDelta, itemId: 2, raw: 'y');
    }
    stub.wake();
    ctrl.drainNow();

    expect(second, 5, reason: '目标气泡每条 delta 失效一次');
    expect(first, 0, reason: '无关气泡不该被惊动');
  });

  test('waker 连打多次，一帧内只安排一次 drain', () async {
    await ctrl.connect();
    stub.emit(KernelFrameKind.itemStarted, itemId: 1, json: {'role': 'x'});

    // native 线程连续唤醒 200 次（真实流式就是这样）。
    for (var i = 0; i < 200; i++) {
      stub.wake();
    }
    // 帧回调还没跑，所以此刻一次都没 drain。
    expect(ctrl.drainCount, 0);

    ctrl.drainNow();
    expect(ctrl.drainCount, 1, reason: '200 次唤醒该被合并成 1 次 drain');
  });

  test('native 丢帧要显形：打 truncated + 插提示，不装没事', () async {
    await ctrl.connect();

    stub.emit(KernelFrameKind.itemStarted, itemId: 1, json: {'role': 'x'});
    stub.emit(KernelFrameKind.itemDelta, itemId: 1, raw: 'a');
    stub.skipSeq(7); // 模拟 native 队列满丢了 7 条
    stub.emit(KernelFrameKind.itemDelta, itemId: 1, raw: 'b');
    stub.wake();
    ctrl.drainNow();

    final text = ctrl.items.whereType<TextItem>().single;
    expect(text.truncated, isTrue, reason: '受影响条目必须打标');
    expect(
      ctrl.items.whereType<NoticeItem>().map((n) => n.kind),
      contains(NoticeKind.dropped),
      reason: '必须插一条提示让用户看得见',
    );
  });

  test('工具卡：begin → 流式输出 → end 带截断标记', () async {
    await ctrl.connect();

    stub.emit(KernelFrameKind.toolBegin,
        itemId: 9, json: {'name': 'shell', 'args': 'rg --files'});
    stub.emit(KernelFrameKind.processOutput, itemId: 9, raw: 'lib/main.dart\n');
    stub.emit(KernelFrameKind.toolEnd,
        itemId: 9,
        flags: KernelFrameFlags.truncated,
        json: {'duration_ms': 412, 'output': '（完整输出）', 'status': 'completed'});
    stub.wake();
    ctrl.drainNow();

    final tool = ctrl.items.whereType<ToolItem>().single;
    expect(tool.name, 'shell');
    expect(tool.elapsedMs, 412);
    expect(tool.done, isTrue);
    expect(tool.outputTruncated, isTrue,
        reason: 'flags.truncated 必须传到 UI，否则用户以为看到的是全部');
  });

  test('审批：内核等回话，respond 后落决定；重复 respond 无效', () async {
    await ctrl.connect();

    // 审批帧的 item_id 指向被审批的那条工具卡（契约 §2.1.0）。
    stub.emit(KernelFrameKind.toolBegin,
        itemId: 5, json: {'name': 'commandExecution', 'args': 'rm -rf /tmp/x'});
    stub.emit(KernelFrameKind.approval,
        itemId: 5,
        json: {'req_id': 5, 'kind': 'commandExecution', 'reason': '要删文件'});
    stub.wake();
    ctrl.drainNow();

    final approval = ctrl.items.whereType<ApprovalItem>().single;
    expect(approval.decision, isNull);
    // 内容取自被审批的工具卡，不是自己编一份。
    expect(approval.target?.argsSummary, 'rm -rf /tmp/x');
    expect(approval.detail, 'rm -rf /tmp/x');

    ctrl.respond(approval, ApprovalDecision.decline);
    expect(approval.decision, 'decline');
    expect(stub.responses, [ApprovalDecision.decline]);

    ctrl.respond(approval, ApprovalDecision.accept);
    expect(stub.responses, hasLength(1), reason: '已回应过的审批不许再发');
  });

  test('帧格式版本不匹配 → 拒绝连接并报错，不降级', () async {
    stub.frameVersion = kKernelFrameVersion + 1;
    await ctrl.connect();
    expect(container.read(chatControllerProvider).fault, isA<FrameVersionMismatch>());
    expect(container.read(chatControllerProvider).capabilities, isNull);
  });

  test('内核不支持 turn/start 时不瞎发', () async {
    stub.methods = const {'thread/list'};
    await ctrl.connect();
    ctrl.send('你好');
    expect(stub.calls, isEmpty, reason: '能力协商说不支持，就不该发出去');
  });

  // ---- 思考状态 ----
  //
  // 它管的是"发出去了、还没吐字"那段静默。三种收尾路径各钉一条 ——
  // 任何一条回退，用户就会看到一行永远转下去的"正在思考"。

  test('发出 → thinking 开；第一段内容落地 → 关', () async {
    await ctrl.connect();
    expect(container.read(chatControllerProvider).thinking, isFalse);

    // 模型必须显式给：没有可用模型时 send 直接拒（同上面两条用例的约束）。
    expect(ctrl.send('在吗', model: 'test-model'), isTrue);
    expect(container.read(chatControllerProvider).thinking, isTrue,
        reason: '刚发出去、内核还没回，这段静默必须显形');

    stub.emit(KernelFrameKind.itemStarted,
        itemId: 1, json: {'role': 'assistant'});
    stub.wake();
    ctrl.drainNow();
    expect(container.read(chatControllerProvider).thinking, isFalse,
        reason: '有东西可看了，状态行该让位');

    // 第二条 item（工具后的续写）不该把它重新打开。
    stub.emit(KernelFrameKind.itemStarted,
        itemId: 2, json: {'role': 'assistant'});
    stub.wake();
    ctrl.drainNow();
    expect(container.read(chatControllerProvider).thinking, isFalse,
        reason: '一轮里只思考一次，中途新建条目不算重新开始思考');
  });

  test('纯工具轮：toolBegin 也收思考行，不必等正文', () async {
    await ctrl.connect();
    ctrl.send('列一下文件', model: 'test-model');
    expect(container.read(chatControllerProvider).thinking, isTrue);

    // 模型直接决定调工具，一个字正文都没吐。
    stub.emit(KernelFrameKind.toolBegin,
        itemId: 9, json: {'name': 'shell', 'args': 'rg --files'});
    stub.wake();
    ctrl.drainNow();
    expect(container.read(chatControllerProvider).thinking, isFalse,
        reason: '工具卡本身就是"在干活"的证据，状态行不该陪着转到 turn 结束');
  });

  test('thinking 绑在 busy 上：任何把 busy 置假的路径都顺手收掉它', () async {
    await ctrl.connect();
    ctrl.send('在吗', model: 'test-model');
    expect(container.read(chatControllerProvider).thinking, isTrue);

    // 走"断开"这条清 busy 的路径 —— 中途被打断时状态行不能留在屏上。
    stub.emit(KernelFrameKind.disconnected);
    stub.wake();
    ctrl.drainNow();

    final st = container.read(chatControllerProvider);
    expect(st.busy, isFalse);
    expect(st.thinking, isFalse,
        reason: 'busy 没了还在"思考"是自相矛盾的画面');
  });

  test('被拒的发送不点亮 thinking', () async {
    await ctrl.connect();
    ctrl.send('第一条', model: 'test-model');
    // busy 时再发被拒 —— 不该把 thinking 重新点起来。
    stub.emit(KernelFrameKind.itemStarted,
        itemId: 1, json: {'role': 'assistant'});
    stub.wake();
    ctrl.drainNow();
    expect(container.read(chatControllerProvider).thinking, isFalse);

    expect(ctrl.send('第二条'), isFalse);
    expect(container.read(chatControllerProvider).thinking, isFalse,
        reason: '发都没发出去，谈不上在思考');
  });
}

/// 测试替身：直接按契约编真帧，不起 timer。
final class _StubKernel implements KernelClient {
  final _pending = <Uint8List>[];
  final _reader = KernelFrameReader();
  final calls = <String>[];
  final responses = <ApprovalDecision>[];

  void Function()? _waker;
  int _seq = 0;
  int frameVersion = kKernelFrameVersion;
  // 与真 gateway 同词汇；测"不支持"时由用例自己改。
  Set<String> methods = {for (final o in KernelOp.values) o.wire};

  @override
  KernelCapabilities? capabilities;

  @override
  Future<KernelCapabilities> open({
    void Function(KernelConnectProgress)? onProgress,
    EngineMode engineMode = EngineMode.defaults,
  }) async => capabilities = KernelCapabilities(
        frameVersion: frameVersion,
        methods: methods,
        features: const {'stub'},
      );

  @override
  void close() => _pending.clear();

  @override
  void setWaker(void Function() waker) => _waker = waker;

  @override
  KernelFrameBatch? drain() {
    if (_pending.isEmpty) return null;
    final buf = KernelFrameWriter.batch(_pending);
    final n = _pending.length;
    _pending.clear();
    return _reader.read(buf, n);
  }

  @override
  void call(KernelOp op, Map<String, Object?> params, int reqId) =>
      calls.add(op.wire);

  @override
  Future<Map<String, Object?>> gatewayCall(String path,
          {String method = 'GET', Map<String, Object?>? body}) async =>
      const {};

  @override
  void setThread(String? threadId) => calls.add('setThread');

  @override
  void interrupt(String turnId) => calls.add('turn/interrupt');

  @override
  void steer(String turnId, String text) => calls.add('turn/steer');

  @override
  void respond(int reqId, ApprovalDecision decision) =>
      responses.add(decision);

  // ---- 测试辅助 ----

  void emit(
    KernelFrameKind kind, {
    int itemId = 0,
    int flags = 0,
    Map<String, Object?>? json,
    String? raw,
  }) {
    final payload = switch ((json, raw)) {
      (final Map<String, Object?> j, _) =>
        Uint8List.fromList(utf8.encode(jsonEncode(j))),
      (_, final String r) => Uint8List.fromList(utf8.encode(r)),
      _ => null,
    };
    _pending.add(KernelFrameWriter.encode(
      kind: kind,
      seq: ++_seq,
      itemId: itemId,
      flags: flags,
      payload: payload,
    ));
  }

  /// 模拟 native 背压丢帧：seq 直接跳过 [n] 个。
  void skipSeq(int n) => _seq += n;

  void wake() => _waker?.call();
}
