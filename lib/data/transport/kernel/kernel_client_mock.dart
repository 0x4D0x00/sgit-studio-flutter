import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/core/contracts/kernel_ops.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_frame.dart';

/// Mock 内核通道 —— **产出真帧**，不连后端。
///
/// 为什么要它：P1a（Rust 侧 FFI）和 P1b（Dart 侧 UI）并行推进，Dart 这边不能等。
/// 但 mock 如果只是 `List<String>` 假数据，等真通道接上来时编解码、按帧 drain、
/// 背压丢帧这些真正容易错的地方一个都没被验证过。所以这里走完整链路：
/// **按契约 §2 编真字节 → 同一份 `KernelFrameReader` 解 → 同一套 UI 渲染**。
/// 换成真 FFI 时只换 [KernelClient] 的实现类，上面一行不动。
///
/// 另外它是性能基线的量具：[emitPerTick] 调大就能压出「1000 条 delta 该只重建几次」。
final class MockKernelClient implements KernelClient {
  MockKernelClient({
    this.tick = const Duration(milliseconds: 16),
    this.emitPerTick = 3,
  });

  /// 产帧节奏。16ms ≈ 60fps，模拟 delta 比帧还密的真实流式。
  final Duration tick;

  /// 每次 tick 产多少帧。调大用于压测批合并是否生效。
  final int emitPerTick;

  final _pending = <Uint8List>[];
  final _reader = KernelFrameReader();

  void Function()? _waker;
  Timer? _timer;
  int _seq = 0;
  int _itemId = 0;
  int _reqId = 0;
  _Script? _script;

  @override
  KernelCapabilities? capabilities;

  @override
  Future<KernelCapabilities> open(
      {void Function(KernelConnectProgress)? onProgress}) async {
    // 模拟真实的沙箱冷启动：先报进度再就绪。UI 的等待态靠它才测得到。
    onProgress?.call(const KernelConnectProgress(
        phase: KernelConnectPhase.sandboxStarting,
        elapsedSecs: 0,
        timeoutSecs: 30));
    capabilities = KernelCapabilities(
      frameVersion: kKernelFrameVersion,
      // ⚠️ **必须与真 gateway 的 hello 报同一套词汇**（`KernelOp` 的 wire 值）。
      // 曾经这里写的是 `turn/start` 那套 app-server 方法名，而 gateway 报的是
      // `send`/`steer`/… —— 结果单测全绿、线上每次发送都被判"不支持"，
      // 还触发无限重连。mock 与真后端词汇不一致 = 测试失去意义。
      methods: {for (final o in KernelOp.values) o.wire},
      features: {'mock'},
    );
    _push(KernelFrameKind.hello, json: {'mock': true});
    return capabilities!;
  }

  @override
  void close() {
    _timer?.cancel();
    _timer = null;
    _script = null;
    _pending.clear();
  }

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
  void call(KernelOp op, Map<String, Object?> params, int reqId) {
    switch (op) {
      case KernelOp.send:
        _startScriptedTurn(params['text']?.toString() ?? '');
      default:
        _push(KernelFrameKind.callResult,
            itemId: reqId, json: {'status': 'success', 'mock': op.wire});
    }
  }

  /// gateway 端点的假数据。
  ///
  /// **形状必须与真后端一致** —— 这是布局测试能发现"数据到达后才炸"那类问题的前提。
  /// 空 mock 只能测出空态，而白屏偏偏都发生在有数据的时候。
  @override
  Future<Map<String, Object?>> gatewayCall(
    String path, {
    String method = 'GET',
    Map<String, Object?>? body,
  }) async {
    if (path == '/sgcode-models/manage') return _relay(body ?? const {});
    return switch (path) {
      '/sgcode-scene/list' => {
          'scenes': [
            {'id': 'blueteam~firewall', 'name': '防护助理', 'model': 'glm4:latest'},
            {'id': 'ops~log', 'name': '日志分析助理', 'subagents': ['a', 'b']},
          ],
        },
      '/sgcode-subagent/list' => {
          'subagents': [
            {'id': 'sub-1', 'name': '子 Agent 一', 'model': 'glm4:latest'},
          ],
        },
      '/sgcode-skill/list' => {
          'skills': [
            {'id': 'sk-1', 'name': '技能一', 'description': '一段较长的技能描述文本用于验证换行与省略'},
          ],
        },
      '/sgcode-mcp/list' => {
          'servers': [
            {
              'name': 'playwright',
              'command': 'npx @playwright/mcp',
              'enabled': true,
              'transport': 'stdio',
              'toolCount': 21,
              'connected': true,
            },
          ],
        },
      '/sgcode-knowledge/list' => {
          'files': [
            {
              'id': 'f-1',
              'name': 'report.xlsx',
              'sceneName': '日志分析助理',
              'scope': 'project',
              'size': 20480,
              'updatedAt': '2026-09-02T00:00:00Z',
            },
          ],
        },
      _ => {'status': 'success'},
    };
  }

  /// 中转站三表的假数据，形状照 `relay_providers` / `relay_models` / `relay_api_keys`。
  Map<String, Object?> _relay(Map<String, Object?> body) {
    final group = body['group'];
    final method = body['method'];
    if (group == 'model' && method == 'providers') {
      // ⚠️ **刻意同一个 model_code 出两行**（builtin + custom）—— 现网就是这样，
      // `DeepSeek` 管理版和个人版各一行。前端不按 tag 过滤就会同时拿到两行、
      // 改一行读另一行，表现为"开关点了不生效"（真踩过并误判成脏数据）。
      // mock 必须复现这个形状，否则 tag 过滤的回归永远测不出来。
      return {
        'status': 'success',
        'providers': [
          {
            'model_code': 'Qwen',
            'provider': 'Alibaba',
            'display_name': 'Alibaba',
            'status': 1,
            'tag': 'builtin',
            'base_url': 'http://10.100.0.66:11434/v1',
          },
          {
            'model_code': 'DeepSeek',
            'provider': 'DeepSeek',
            'display_name': 'DeepSeek',
            'status': 0,
            'tag': 'builtin',
            'base_url': '',
          },
          // 个人版的行（同 code 不同 tag）。
          {
            'model_code': 'Qwen',
            'provider': 'Alibaba',
            'display_name': 'Alibaba（个人）',
            'status': 1,
            'tag': 'custom',
            'base_url': 'http://127.0.0.1:11434/v1',
          },
          {
            'model_code': 'MyVendor',
            'provider': 'custom',
            'display_name': '自建厂商',
            'status': 1,
            'tag': 'custom',
            'base_url': 'http://127.0.0.1:8000/v1',
          },
        ],
      };
    }
    if (group == 'model' && method == 'list') {
      return {
        'status': 'success',
        'provider': body['provider'],
        'models': [
          {
            'model_name': 'glm4:latest',
            'model_display_name': 'GLM-4',
            'model_code': 'Qwen',
            'is_available': 1,
            'context_window': 128000,
            'tag': 'builtin',
          },
          {
            // 刻意放一个超长名字：截断/溢出的布局问题就靠它暴露。
            'model_name':
                'joe-speedboat/Qwen3.6-35B-A3B-Uncensored-HauhauCS-Aggressive:Q4_K_M',
            'model_display_name': '',
            'model_code': 'Qwen',
            'is_available': 1,
            'tag': 'builtin',
          },
          // 个人版的模型。**刻意 is_available=0** —— 验证 include_disabled：
          // 管理页必须能看见停用的模型，否则没法把它重新启用（单向操作）。
          {
            'model_name': 'glm4:personal',
            'model_display_name': 'GLM-4（个人·已停用）',
            'model_code': 'Qwen',
            'is_available': 0,
            'context_window': 32000,
            'tag': 'custom',
          },
        ],
      };
    }
    if (group == 'apikey') {
      return {
        'status': 'success',
        'data': {
          'list': [
            {'id': '1', 'api_key': '******123456', 'status': 1, 'model_code': 'Qwen'},
          ],
          'count': 1,
        },
      };
    }
    return {'status': 'success'};
  }

  @override
  void setThread(String? threadId) {
    // mock 没有真 thread 概念 —— 新对话由控制器清列表体现，这里无事可做。
  }

  @override
  void interrupt(String turnId) {
    _timer?.cancel();
    _timer = null;
    _script = null;
    _push(KernelFrameKind.turnCompleted,
        json: {'turn_id': turnId, 'interrupted': true});
    _waker?.call();
  }

  @override
  void steer(String turnId, String text) {
    // 真内核会把 steer 并进当前 turn；mock 里表现为插一条新 item。
    _script?.steer(text);
  }

  @override
  void respond(int reqId, ApprovalDecision decision) {
    _push(KernelFrameKind.callResult,
        itemId: reqId, json: {'decision': decision.wire});
    if (decision != ApprovalDecision.decline) _script?.resume();
    _waker?.call();
  }

  // ---- 脚本化的一个 turn：文本流 → 工具调用 → 审批 → 收尾 ----

  void _startScriptedTurn(String prompt) {
    _timer?.cancel();
    final turnId = 'mock-turn-${++_reqId}';
    _script = _Script(prompt: prompt, turnId: turnId);

    _push(KernelFrameKind.turnStarted, json: {'turn_id': turnId});
    _timer = Timer.periodic(tick, (_) => _step());
  }

  void _step() {
    final s = _script;
    if (s == null) return;

    var finished = false;
    for (var i = 0; i < emitPerTick; i++) {
      if (!_emitOne(s)) {
        finished = true;
        break;
      }
    }
    if (finished) {
      _timer?.cancel();
      _timer = null;
      _script = null;
    }
    // ⚠️ 收尾也要唤醒。早期版本在 turnEnd 那一步直接 return，结果 turnCompleted 帧
    // 进了队列却没人来取 —— 用量条永远不出现（被 UI 测试抓到）。
    // Rust 侧同理：**最后一帧之后必须再唤醒一次**，否则消费者永远差最后一批。
    _waker?.call();
  }

  /// 返回 false 表示脚本跑完。
  bool _emitOne(_Script s) {
    if (s.awaitingApproval) return true; // 卡在审批上，什么都不产
    final step = s.next();
    switch (step) {
      case _Step.openItem:
        _itemId++;
        _push(KernelFrameKind.itemStarted,
            itemId: _itemId, json: {'role': 'assistant', 'type': 'text'});
      case _Step.delta:
        _push(KernelFrameKind.itemDelta,
            itemId: _itemId, raw: s.takeChunk());
      case _Step.closeItem:
        _push(KernelFrameKind.itemCompleted,
            itemId: _itemId,
            flags: KernelFrameFlags.isFinal,
            json: {'role': 'assistant'});
      case _Step.toolBegin:
        _itemId++;
        _push(KernelFrameKind.toolBegin,
            itemId: _itemId,
            json: {'name': 'commandExecution', 'args': 'rg --files | head'});
      case _Step.approval:
        s.awaitingApproval = true;
        // item_id 指向上面那条 toolBegin 的工具卡（契约 §2.1.0：审批不带内容）。
        _push(KernelFrameKind.approval, itemId: _itemId, json: {
          'req_id': ++_reqId,
          'kind': 'commandExecution',
          'reason': '要在 /tmp 下删文件',
        });
      case _Step.toolEnd:
        _push(KernelFrameKind.toolEnd,
            itemId: _itemId,
            flags: KernelFrameFlags.truncated,
            json: {
              'duration_ms': 412,
              'status': 'completed',
              'output': 'lib/main.dart\nlib/app/app.dart',
            });
      case _Step.turnEnd:
        // 用量是独立帧，turn 跑动期间就会推（契约 §2.1）。
        _push(KernelFrameKind.tokenUsage, json: {
          'turn_id': s.turnId,
          'input_tokens': 1234,
          'cached_input_tokens': 100,
          'output_tokens': 567,
          'total_tokens': 1901,
        });
        _push(KernelFrameKind.turnCompleted, json: {
          'turn_id': s.turnId,
          'duration_ms': 3820,
          'llm_ms': 2900,
          'tool_ms': 412,
        });
        return false;
    }
    return true;
  }

  void _push(
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
}

enum _Step { openItem, delta, closeItem, toolBegin, approval, toolEnd, turnEnd }

/// 一个 turn 的剧本。刻意把「文本流 → 工具 → 审批 → 收尾」都走一遍，
/// 保证 UI 的四类卡片在真通道接上前就都被渲染过。
final class _Script {
  _Script({required this.prompt, required this.turnId});

  final String prompt;
  final String turnId;

  bool awaitingApproval = false;

  final _steps = <_Step>[
    _Step.openItem,
    ...List.filled(40, _Step.delta),
    _Step.closeItem,
    _Step.toolBegin,
    _Step.approval,
    _Step.toolEnd,
    _Step.openItem,
    ...List.filled(25, _Step.delta),
    _Step.closeItem,
    _Step.turnEnd,
  ];
  int _at = 0;
  int _chunk = 0;

  _Step next() {
    final s = _steps[_at.clamp(0, _steps.length - 1)];
    _at++;
    return s;
  }

  void resume() => awaitingApproval = false;

  /// 插一段新文本流，模拟内核吸收了插话（真内核是把 steer 并进当前 turn）。
  /// 插话越长，模拟出的补充回答就越长。
  void steer(String text) {
    _steps.insertAll(_at, [
      _Step.closeItem,
      _Step.openItem,
      ...List.filled((text.length).clamp(5, 40), _Step.delta),
    ]);
  }

  String takeChunk() {
    const words = [
      '正在', '读取', '仓库', '结构', '，', '共', '发现', '若干', '模块', '。',
      '接下来', '按', '分层', '约定', '检查', '依赖', '方向', '是否', '有', '反向', '引用', '。',
    ];
    return words[_chunk++ % words.length];
  }
}
