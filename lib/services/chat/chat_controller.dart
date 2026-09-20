import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/core/contracts/kernel_ops.dart';
import 'package:sgit_studio_flutter/data/mappers/kernel_frame_mapper.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_factory.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_frame.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_session.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';

/// 会话控制器 —— 内核帧流的唯一消费者。
///
/// ## 性能设计（这是 FFI 方案的兑现处，改之前先读 `docs/KERNEL_FFI.md` §4）
///
/// 1. **每帧最多 drain 一次**。waker 只置脏 + `scheduleFrame()`，真正的取帧发生在
///    `addPostFrameCallback` 里。native 一秒推 1000 个 delta，这里也只醒 60 次。
/// 2. **一次 drain 只发一次通知**。列表结构变化才动 [itemsRevision]；纯文本追加只动
///    对应条目自己的 `ChatItem.revision` —— 一个 delta 重建一个气泡，不重建列表。
/// 3. **不在热路径 jsonDecode**。delta 是裸 UTF-8。
/// 4. **丢帧不装没事**。`seq` 跳跃时给受影响条目打 `truncated`，并插一条提示。
class ChatController extends Notifier<ChatSessionState> {
  ChatController({KernelClient? client}) : _injected = client;

  final KernelClient? _injected;

  /// 未注入时按平台选：Web 走 wasm→gateway，桌面暂为 mock。测试注入替身。
  late final KernelClient _client = _injected ?? createKernelClient();

  /// 条目按到达顺序排列。**身份稳定** —— `ListView.builder` 靠它避免整表重建。
  final List<ChatItem> _items = [];

  /// 结构版本：只在增删条目时 +1。
  final ValueNotifier<int> itemsRevision = ValueNotifier<int>(0);

  /// 当前正在流式追加的文本条目（`itemStarted` 开、`itemCompleted` 关）。
  TextItem? _streaming;
  final Map<int, ChatItem> _byId = {};

  /// 两次建连之间的最小间隔。纯粹的防呆闸门（见 [connect] 注释）。
  static const _reconnectFloor = Duration(seconds: 2);
  DateTime _lastConnectAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// 乐观置 busy 后等 turnStarted 的上限。超了就放开输入，别把用户锁死。
  ///
  /// ⚠️ **1 分钟**，不是十几秒。这段等待里 gateway 要串着做完：确保沙箱可用 →
  /// `thread/start` → `turn/start` 受理。沙箱冷启动本身就有 30s 预算，
  /// 再加上首轮建 thread，20s 根本不够 —— 会在内核明明正常工作时误报
  /// "长时间无响应"，比不报更误导。
  ///
  /// 这条守卫的目的**只是兜底**（内核真挂了别把用户锁死在 busy 态），
  /// 不该用它来判断"快不快"。
  static const _stallTimeout = Duration(seconds: 60);
  Timer? _stallTimer;

  bool _dirty = false;
  bool _drainScheduled = false;
  int _reqSeq = 0;
  int _syntheticId = -1;

  /// 本次会话里 drain 被执行的次数。性能基线用（契约 §8：1000 delta → < 60 次）。
  int drainCount = 0;

  List<ChatItem> get items => List.unmodifiable(_items);

  @override
  ChatSessionState build() {
    _client.setWaker(_onWake);
    ref.onDispose(_disposeAll);
    return const ChatSessionState();
  }

  Future<void> connect() async {
    // ⚠️ **重入防护 + 幂等**。以前两者都没有，导致过一次真实的重连风暴：
    // 每次发送被拒都调 connect()，而 connect() 无条件 close+open —— 好端端的连接
    // 被拆掉重建，每秒好几条，gateway 日志里同一个 cid 刷屏。
    if (state.connecting) return;
    // 已经连上了就什么都不做。connect() 必须幂等，否则任何"顺手重连一下"的
    // 调用点都可能变成风暴源。
    if (state.capabilities != null && state.fault == null) return;

    // 防线：重连之间强制最小间隔。就算将来又有谁在循环里调 connect()，
    // 最坏也只是每 2 秒一次，不会打死 gateway。
    final since = DateTime.now().difference(_lastConnectAt);
    if (since < _reconnectFloor) {
      await Future<void>.delayed(_reconnectFloor - since);
    }
    _lastConnectAt = DateTime.now();
    state = state.copyWith(
        connecting: true,
        fault: null,
        progress: const KernelConnectProgress(
            phase: KernelConnectPhase.connecting));
    try {
      // 重连前先关旧连接，别留悬空的。
      _client.close();

      // 读取当前的引擎模式设置。
      // `read` 不配 `select`（后者是给 `watch` 决定重建时机用的，对 read 无意义）。
      final engineMode =
          ref.read(composerSettingsProvider).settings.engineMode;

      final caps = await _client.open(
        engineMode: engineMode,
        onProgress: (p) {
          // 建连中途才更新；已经结束就别再改（回调可能晚到）。
          if (state.connecting) state = state.copyWith(progress: p);
        },
      );
      if (!caps.isCompatible) {
        state = state.copyWith(
          connecting: false,
          fault: FrameVersionMismatch(
              kernel: caps.frameVersion, client: kKernelFrameVersion),
        );
        return;
      }
      state = state.copyWith(
          connecting: false, capabilities: caps, clearProgress: true);
    } catch (e) {
      // ⚠️ 这里**必须**接住：以前是裸 await，异常直接进了未处理的 microtask，
      // 界面上一点提示都没有，用户只看到"发消息没反应"。
      state = state.copyWith(
          connecting: false,
          clearProgress: true,
          fault: KernelUnavailable(_stripException(e)));
    }
  }

  /// 发一轮对话。内核能力里没有 [KernelOp.send] 就直接拒绝，不瞎发。
  ///
  /// [model] 为空时用内核默认模型。
  ///
  /// **返回是否受理** —— 调用方据此决定要不要清空输入框。无条件清空会让用户
  /// 辛苦打的一大段话在发送被拒时凭空消失（真踩过，用户当场就问"我的内容呢"）。
  bool send(String text, {String? model}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    // ⚠️ busy 时**必须说话**。以前这里直接 return false，用户看到的是
    // "点了没反应、字还在输入框里"，完全不知道发生了什么。
    if (state.busy) {
      state = state.copyWith(notice: ChatNotice.busy);
      return false;
    }

    // ⚠️ 没连上就**不能**进 busy 态。以前这里不判连接，结果消息发不出去、
    // 按钮却永远停在"停止"，用户完全不知道发生了什么（真踩过）。
    final caps = state.capabilities;
    if (caps == null || !caps.supports(KernelOp.send)) {
      // ⚠️ 只在**没有**更具体的故障时才报"未连接" —— connect() 失败时留下的
      // 原因（认证失败/超时/版本不匹配）比这句笼统提示有用得多，别覆盖掉。
      if (state.fault == null) {
        state = state.copyWith(fault: const KernelNotConnected());
      }
      // 顺手自动重连一次：多数情况是首屏建连还没完成或网络抖了一下，
      // 让用户去找"重连"按钮不如自己试一次。
      if (!state.connecting) unawaited(connect());
      return false;
    }

    _append(TextItem(
        id: _syntheticId--, role: ChatRole.user, initial: trimmed));
    // ⚠️ 本地插入的条目要自己通知列表 —— `itemsRevision` 的另一处 ++ 在 [_drainOnce]
    // 里，那条路径只覆盖内核推来的帧。漏了这句用户气泡就不显示（被 UI 集成测试抓到过）。
    itemsRevision.value++;
    state = state.copyWith(busy: true, turnId: null, clearNotice: true);
    _client.call(KernelOp.send, {'text': trimmed, 'model': model}, ++_reqSeq);
    _armStallWatchdog();
    return true;
  }

  /// busy 看门狗。
  ///
  /// [send] 是**乐观**置 busy 的（turnStarted 还没到）。如果内核那边挂了、
  /// turnStarted 永远不来，busy 就永久卡住 —— 之后每次提交都被当成 steer，
  /// 而 steer 又因为没有 turnId 静默失败：用户彻底没有出路，只能刷页面。
  /// 这条守卫保证界面一定能回到可输入状态。
  void _armStallWatchdog() {
    _stallTimer?.cancel();
    _stallTimer = Timer(_stallTimeout, () {
      // turnStarted 已到就不管了，真在跑。
      if (!state.busy || state.turnId != null) return;
      state = state.copyWith(busy: false, notice: ChatNotice.stalled);
    });
  }

  /// 切换引擎模式（本地 ↔ 云端）后重新建连。
  ///
  /// ⚠️ **必须走这个入口，不能只调 `connect()`** —— 它是幂等的
  /// （`capabilities != null && fault == null` 时直接返回），而页面初始化时
  /// 早已用默认模式连上了。只改设置不断连的话，用户切到云端仍在用本地引擎，
  /// 而两条路的帧、动作、界面完全一样，**从表现上根本看不出来**。
  ///
  /// 这里先把旧连接拆干净（`close()` + 清 capabilities），再让 `connect()`
  /// 以新模式重建。跑动中的 turn 会被一起掐掉 —— 换引擎本来就意味着换执行环境，
  /// 让它在旧引擎上跑完再切反而更让人困惑。
  Future<void> reconnectWithMode() async {
    _client.close();
    // 清掉 capabilities，否则 connect() 的幂等判断会直接 return。
    state = const ChatSessionState();
    // 绕开重连最小间隔：这是用户显式操作，不是风暴。
    _lastConnectAt = DateTime.fromMillisecondsSinceEpoch(0);
    await connect();
  }

  /// 开始新对话：清空当前会话内容，并让下次发消息**新建 thread**。
  ///
  /// 不重连 —— 连接是按用户建的，换会话不需要重握手。
  void newChat() {
    if (state.busy) interrupt();
    for (final i in _items) {
      i.dispose();
    }
    _items.clear();
    _byId.clear();
    _streaming = null;
    _client.setThread(null);
    itemsRevision.value++;
    // ⚠️ **必须保留 capabilities**。能力属于**连接**，不属于会话 —— 换个话题
    // 内核的能力不会变。原先这里写 `const ChatSessionState(capabilities: null)`
    // 把它一起清了，于是"新建对话"之后第一次发送就因为 caps==null 被拒，
    // 还顺带触发重连（close+open，沙箱又要冷启动一遍）。
    state = ChatSessionState(capabilities: state.capabilities);
  }

  /// 用指定场景（助理）开新对话。
  ///
  /// 场景在内核里就是 thread 的归属（`~` 分隔的队伍段，见 gateway 的
  /// `sgcode_scene_commands` 注释），所以直接把它当 thread 前缀交给内核。
  void newChatWithScene(String sceneId) {
    newChat();
    _client.setThread(sceneId);
  }

  /// 停止当前 turn。
  void interrupt() {
    final id = state.turnId;
    if (id == null) return;
    _client.interrupt(id);
  }

  /// 中途插话改方向。不打断，内核把它并进当前 turn。
  ///
  /// 同 [send]：**返回是否受理**，没受理就别清输入框。
  bool steer(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final id = state.turnId;
    // ⚠️ 同 [send]：**不能静默失败**。busy=true 但 turnId=null 是真实存在的中间态
    // （乐观置 busy 之后、turnStarted 之前），撞上就什么提示都没有。
    if (id == null) {
      state = state.copyWith(notice: ChatNotice.noTurnToSteer);
      return false;
    }
    _client.steer(id, trimmed);
    state = state.copyWith(clearNotice: true);
    return true;
  }

  void respond(ApprovalItem item, ApprovalDecision decision) {
    if (item.decision != null) return;
    _client.respond(item.reqId, decision);
    item.resolve(decision.wire);
  }

  // ---- 帧流 ----

  /// waker。**可能在任意线程触发** —— 这里只允许置脏 + 请一帧，不许干活。
  void _onWake() {
    _dirty = true;
    if (_drainScheduled) return;
    _drainScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _drainScheduled = false;
        _drainOnce();
      })
      ..scheduleFrame();
  }

  /// 单测入口：绕过帧调度直接取一批。生产代码**不许调**，走 [_onWake]。
  @visibleForTesting
  void drainNow() => _drainOnce();

  void _drainOnce() {
    if (!_dirty) return;
    _dirty = false;
    drainCount++;

    final batch = _client.drain();
    if (batch == null) return;

    // 结构是否变化 —— 只有变了才通知列表，纯文本追加不惊动它。
    var structural = false;
    for (final f in batch.frames) {
      // 丢帧按帧归属：算在**此刻正在流的那条**身上，不是整批算一次。
      if (f.droppedBefore > 0) structural |= _onDropped(f.droppedBefore);
      structural |= _apply(f);
    }
    if (structural) itemsRevision.value++;
  }

  /// 返回 true 表示列表结构变了（增删条目）。
  bool _apply(KernelFrame f) {
    switch (f.kind) {
      case KernelFrameKind.itemDelta:
        // 热路径：一次 UTF-8 解码，不 jsonDecode，不动列表。
        _streaming?.append(KernelFrameMapper.text(f));
        return false;

      case KernelFrameKind.processOutput:
        final tool = _byId[f.itemId];
        if (tool is ToolItem) {
          tool.output = (tool.output ?? '') + KernelFrameMapper.text(f);
          tool.revision.value++;
        }
        return false;

      case KernelFrameKind.itemStarted:
        final item = TextItem(id: f.itemId, role: ChatRole.assistant);
        _streaming = item;
        _append(item);
        return true;

      case KernelFrameKind.itemCompleted:
        _streaming?.markDone();
        _streaming = null;
        return false;

      case KernelFrameKind.toolBegin:
        final j = KernelFrameMapper.json(f);
        _append(ToolItem(
          id: f.itemId,
          name: KernelFrameMapper.str(j, 'name', 'tool'),
          argsSummary: KernelFrameMapper.str(j, 'args'),
        ));
        return true;

      case KernelFrameKind.toolEnd:
        final j = KernelFrameMapper.json(f);
        final tool = _byId[f.itemId];
        if (tool is ToolItem) {
          tool.complete(
            output: KernelFrameMapper.str(j, 'output'),
            elapsedMs: KernelFrameMapper.intOrNull(j, 'duration_ms'),
            status: KernelFrameMapper.str(j, 'status'),
            truncated: f.truncated,
          );
        }
        return false;

      case KernelFrameKind.approval:
        // ⚠️ 审批帧的 item_id 指向**被审批的那条工具 item**，内核不重复带命令内容
        // （契约 §2.1.0）。所以挂到已有的工具卡上，别自己再显示一份。
        final j = KernelFrameMapper.json(f);
        final tool = _byId[f.itemId];
        final approval = ApprovalItem(
          // 用合成 id：这条卡片和工具卡是两个条目，不能共用 id。
          id: _syntheticId--,
          reqId: KernelFrameMapper.intOrNull(j, 'req_id') ?? 0,
          kind: KernelFrameMapper.str(j, 'kind'),
          reason: KernelFrameMapper.str(j, 'reason'),
          // 命令/补丁全文取自那条工具卡，没有就退回空（不编内容）。
          target: tool is ToolItem ? tool : null,
        );
        _append(approval);
        return true;

      case KernelFrameKind.turnStarted:
        // 真开跑了，撤看门狗。
        _stallTimer?.cancel();
        state = state.copyWith(
          busy: true,
          turnId: KernelFrameMapper.str(KernelFrameMapper.json(f), 'turn_id'),
        );
        return false;

      case KernelFrameKind.turnCompleted:
        final j = KernelFrameMapper.json(f);
        _streaming?.markDone();
        _streaming = null;
        state = state.copyWith(
          busy: false,
          turnId: null,
          lastTiming: TurnTiming(
            durationMs: KernelFrameMapper.intOrNull(j, 'duration_ms') ?? 0,
            llmMs: KernelFrameMapper.intOrNull(j, 'llm_ms') ?? 0,
            toolMs: KernelFrameMapper.intOrNull(j, 'tool_ms') ?? 0,
          ),
        );
        return false;

      // ⚠️ 用量是**独立帧**，turn 跑动期间就在更新 —— 不能当作 turn 结束的信号。
      case KernelFrameKind.tokenUsage:
        final j = KernelFrameMapper.json(f);
        state = state.copyWith(
          lastUsage: TokenUsage(
            inputTokens: KernelFrameMapper.intOrNull(j, 'input_tokens') ?? 0,
            cachedInputTokens:
                KernelFrameMapper.intOrNull(j, 'cached_input_tokens') ?? 0,
            outputTokens: KernelFrameMapper.intOrNull(j, 'output_tokens') ?? 0,
            totalTokens: KernelFrameMapper.intOrNull(j, 'total_tokens') ?? 0,
          ),
        );
        return false;

      case KernelFrameKind.compacted:
        return _notice(NoticeKind.compacted);

      case KernelFrameKind.modelRerouted:
        return _notice(NoticeKind.modelRerouted,
            detail: KernelFrameMapper.str(KernelFrameMapper.json(f), 'to'));

      case KernelFrameKind.error:
        return _notice(NoticeKind.error,
            detail: KernelFrameMapper.str(KernelFrameMapper.json(f), 'message'));

      case KernelFrameKind.disconnected:
        state = state.copyWith(busy: false, turnId: null);
        return _notice(NoticeKind.disconnected);

      case KernelFrameKind.hello:
      case KernelFrameKind.callResult:
        // hello 的内容已在 open() 的 caps 里；callResult 由发起方自己认领。
        return false;
    }
  }

  /// native 因背压丢过 delta。**必须显形**：给当前条目打标 + 插一条提示。
  /// 契约 §3 要求「不许假装没发生」。返回 true（插了条目 = 结构变化）。
  bool _onDropped(int count) {
    final streaming = _streaming;
    if (streaming != null) {
      streaming.truncated = true;
      streaming.revision.value++;
    }
    return _notice(NoticeKind.dropped, count: count);
  }

  bool _notice(NoticeKind kind, {String detail = '', int count = 0}) {
    _append(NoticeItem(
        id: _syntheticId--, kind: kind, detail: detail, count: count));
    return true;
  }

  void _append(ChatItem item) {
    _items.add(item);
    _byId[item.id] = item;
  }

  void _disposeAll() {
    _stallTimer?.cancel();
    _client.close();
    for (final i in _items) {
      i.dispose();
    }
    itemsRevision.dispose();
  }
}

final chatControllerProvider =
    NotifierProvider<ChatController, ChatSessionState>(ChatController.new);

/// 剥掉 `XxxException:` 前缀，只留给用户看的那句。
String _stripException(Object e) =>
    e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
