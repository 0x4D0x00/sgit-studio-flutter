import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/core/contracts/kernel_ops.dart';
import 'package:sgit_studio_flutter/data/repositories/session_sync_repository.dart';
import 'package:sgit_studio_flutter/data/mappers/kernel_frame_mapper.dart';
import 'package:sgit_studio_flutter/data/mappers/view_event_mapper.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_client_factory.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_frame.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_session.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/session_sync_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/thread_list_controller.dart';

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

  /// 会话代次。**每次换会话（打开历史 / 新对话）都 +1。**
  ///
  /// ⚠️ 用来丢弃**在途的旧载入**。点开历史是异步的，用户完全可能在它回来
  /// 之前就点了另一条、或者开了新对话：
  ///
  /// ```text
  /// 点 A（慢）─────────────────────┐
  ///        点 B（快）→ 显示 B      │
  ///                    A 回来 ──────┘→ 把 B 的内容换成 A
  /// ```
  ///
  /// 表现是"点了 B，屏幕上却是 A"，而列表里高亮的是 B —— 没有任何报错。
  /// 光比 [_threadId] 不够：那只能挡住"切到别的会话"，挡不住
  /// "同一条会话被连点两次"的乱序，也挡不住 newChat 之后旧内容灌回来。
  int _openGeneration = 0;
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
          connecting: false,
          capabilities: caps,
          clearProgress: true,
          // 引擎起来了但少了命令类工具 → 立刻说清楚。不是"坏了"，所以这条
          // fault 不给重连按钮（见 LocalExecUnavailable）。
          fault: caps.execUnavailable ? const LocalExecUnavailable() : null);
    } catch (e) {
      // ⚠️ 这里**必须**接住：以前是裸 await，异常直接进了未处理的 microtask，
      // 界面上一点提示都没有，用户只看到"发消息没反应"。
      // ⚠️ 也**必须留日志**：只把原因塞进 state 的话，排查时得有人正好盯着界面
      // 才看得见，日志里则完全无痕（踩过：服务端已经回了 hello，客户端这边
      // 却分不清是连上了还是悄悄失败了）。
      debugPrint('[kernel] 建连失败：${_stripException(e)}');
      state = state.copyWith(
          connecting: false,
          clearProgress: true,
          fault: KernelUnavailable(_stripException(e)));
    }
  }

  /// 发一轮对话。内核能力里没有 [KernelOp.send] 就直接拒绝，不瞎发。
  ///
  /// [model] 由调用方按「选的，否则列表第一个」定好；为空（没有可用模型）直接拒绝。
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
    // 模型由调用方按「用户选的，否则列表第一个」定好传进来；为空 = 中转站没有
    // 可用模型 → **拒绝发送**，不交给引擎去兜底。
    if (model == null || model.isEmpty) {
      state = state.copyWith(notice: ChatNotice.noModel);
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

  /// 气泡内联编辑保存：丢弃这条用户消息**之后**的所有本地条目，把编辑后的文本
  /// 当作新一轮重新发出。
  ///
  /// ⚠️ **这只是本地视图的截断**，不是内核层面的"回滚 thread"——协议里没有
  /// 这个操作（[KernelOp] 只有 send/interrupt/steer/approve/ping，没有
  /// truncate/fork）。所以内核那边的 thread 历史仍然完整保留着编辑前的原文
  /// 和它当时的回答，新一轮只是照常 append 上去；界面上只是不再显示那些
  /// 被丢弃的条目。
  ///
  /// 校验顺序**必须**在截断之前：先确认这次重发不会被拒（同 [send] 的检查），
  /// 再动手删旧条目 —— 反过来的话，一旦被拒，用户的原消息和回答已经被删掉，
  /// 却什么都没发出去，没有任何办法找回来。
  bool editAndResend(int itemId, String text, {String? model}) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (state.busy) {
      state = state.copyWith(notice: ChatNotice.busy);
      return false;
    }
    if (model == null || model.isEmpty) {
      state = state.copyWith(notice: ChatNotice.noModel);
      return false;
    }
    final caps = state.capabilities;
    if (caps == null || !caps.supports(KernelOp.send)) {
      if (state.fault == null) {
        state = state.copyWith(fault: const KernelNotConnected());
      }
      if (!state.connecting) unawaited(connect());
      return false;
    }

    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return false;

    final removed = _items.sublist(index);
    _items.removeRange(index, _items.length);
    for (final i in removed) {
      _byId.remove(i.id);
      i.dispose();
    }
    if (removed.contains(_streaming)) _streaming = null;

    return send(trimmed, model: model);
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
    // ⚠️ **切走之前先把本地会话推上去**。
    //
    // 两个引擎的历史是两份不相干的列表：本地聊的落在本机 `<cid_home>/sessions/`，
    // 云端的落在服务器。不推就切，用户到了云端会发现"刚才聊的那条不见了" ——
    // 而它其实好好地躺在本机，只是对面看不到。
    //
    // 等它完成再切（不是 fire-and-forget）：切换本身就要重建连接、有可感知的
    // 等待，把同步并进这段等待里，比切过去之后再让列表悄悄变化清楚。
    // 未启用时是 no-op，不会白等。
    await ref.read(sessionSyncProvider).syncNow();

    // 在途的历史载入作废：它是向**旧引擎**要的那条会话，而换引擎就是换了
    // 一份不相干的历史。让它落地的话，`openThread` 会把这个 id 交给新连接的
    // `setThread` —— 新引擎里没有这条 thread，下一次发送才在 turn/start 上
    // 报 "thread not found"，离起因已经很远了。
    //
    // （这个窗口是"点开会话改成异步"之后才有的：原先历史页会一直阻塞到
    // 内容回来，用户根本没机会在载入途中去切引擎。）
    _openGeneration++;

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
    // 开新对话同样是"换会话"：在途的历史载入回来时必须被丢掉，
    // 否则旧会话的内容会灌进这个空白的新对话里。
    _openGeneration++;
    _client.setThread(null);
    itemsRevision.value++;
    // ⚠️ **必须保留 capabilities**。能力属于**连接**，不属于会话 —— 换个话题
    // 内核的能力不会变。原先这里写 `const ChatSessionState(capabilities: null)`
    // 把它一起清了，于是"新建对话"之后第一次发送就因为 caps==null 被拒，
    // 还顺带触发重连（close+open，沙箱又要冷启动一遍）。
    state = ChatSessionState(capabilities: state.capabilities);
  }

  /// 用指定助理开新对话。调用方是助理切换器。
  ///
  /// ⚠️ **不再把 sceneId 交给 `setThread`。** 原先这里做
  /// `_client.setThread(sceneId)` —— 把**场景 id 当 thread id** 塞给内核，而
  /// thread id 是 UUIDv7、场景 id 形如 `blueteam~firewall`，两者根本不是一回事。
  /// 内核那边要么当成不存在的 thread（后续 turn/start 报 thread not found），
  /// 要么更糟。
  ///
  /// 归属由 gateway 的 `topic_owner` 映射记（thread 建出来之后打标），
  /// 不靠往 thread id 里塞前缀。所以这里只需清空会话内容 —— [sceneId] 现在
  /// 只是**调用意图的说明**，不参与内核交互；保留参数是为了让调用点仍能表达
  /// "我在为某个助理开新对话"，也便于将来接上归属打标。
  void newChatWithScene(String sceneId) {
    newChat();
  }

  /// 点开一条历史会话 —— **调用方不必等它**，进页面与载内容是分开的两拍。
  ///
  /// ## 为什么整条流程在控制器里，而不在页面里
  ///
  /// 原先在 `history_page._pick`：`await open()` 之后才 `context.go(home)`。
  /// 于是**内容回来之前页面一动不动** —— 用户反馈的「点历史会话要过很久才能
  /// 进 L2 页面」就是这个，而且期间没有任何反馈，看着像没点中。
  ///
  /// 改成先进页面就必然要把载入搬走：`context.go` 之后发起的那个页面已经卸载，
  /// 它的 `ref` 不能再读、`context` 不能再弹 SnackBar。控制器活得比页面长，
  /// 是唯一能把结果和错误都接住的地方。
  ///
  /// 流程：
  /// ```text
  /// 清空 + openingThread=true   ← 同步，调用方随即 context.go(home)
  ///        ↓ (thread/resume)
  /// 成功 → 装配回放 + 接上 thread
  /// 失败 → ThreadOpenFailed，工作台的故障条显示原文
  /// ```
  Future<void> openThreadById(String threadId) async {
    beginOpenThread(threadId);
    final gen = _openGeneration; // beginOpenThread 刚 +1，记下这次的代次
    try {
      final replay = await ref.read(threadRepositoryProvider).open(threadId);
      // 取数期间用户换了会话 → 这份内容已经过时，丢掉（见 _openGeneration）。
      if (_openGeneration != gen) {
        debugPrint('[threads] $threadId 载入期间用户已换会话，丢弃这份内容');
        return;
      }
      openThread(threadId, replay.events);
      unawaited(_refreshThreadFromServer(threadId, gen));
    } catch (e) {
      // ⚠️ **本地没有这条会话 —— 这是唯一该让用户等的情形。**
      //
      // 常见于"换台机器登录"：会话是在另一台设备上聊的，本机
      // `<cid_home>/sessions/` 里压根没有这个文件。此时直接报错是错的，
      // 那条会话明明在服务器上好好地躺着 —— 用户会以为历史丢了。
      //
      // 注意这跟上面那条后台刷新是**两种情形**，不能合并：
      //
      // ```text
      // 本地有 → 立刻展示，后台问服务器有没有更新（不让用户等）
      // 本地无 → 没东西可展示，只能等拉完（这一次必须等）
      // ```
      debugPrint('[threads] 本地打不开 $threadId（$e），试着从服务器拉一次');
      if (_openGeneration != gen) return;

      if (await _pullThreadFromServer(threadId)) {
        if (_openGeneration != gen) return;
        try {
          final replay = await ref.read(threadRepositoryProvider).open(threadId);
          if (_openGeneration != gen) return;
          openThread(threadId, replay.events);
          return; // 刚拉的就是最新，不必再刷一次
        } catch (e2) {
          // 拉回来了还是打不开 —— 落到下面按失败处理，但报**这一次**的原因：
          // 它比"本地没有"更接近真正的问题（文件损坏 / 版本不兼容）。
          debugPrint('[threads] 拉回后仍打不开 $threadId：$e2');
          if (_openGeneration != gen) return;
          _failOpen(e2);
          return;
        }
      }

      // 服务器上也没有（或同步没开 / 云端模式）—— 打不开必须说，
      // 静默停在空会话上，用户会以为历史丢了。
      //
      // **过时的失败不该报**：用户早换到别的会话了，弹一条"打不开 A"
      // 只会让人莫名其妙，还会把新会话的状态搅乱。
      if (_openGeneration != gen) return;
      _failOpen(e);
    }
  }

  /// 退出载入态并报错。
  void _failOpen(Object e) {
    state = state.copyWith(
      openingThread: false,
      fault: ThreadOpenFailed(
        e.toString().replaceFirst(RegExp(r'^\w*Exception(\([^)]*\))?:\s*'), ''),
      ),
    );
  }

  /// 从服务器拉这一条会话，返回"有没有拉到东西"。
  ///
  /// 抽出来是因为两条路都要用它，但**等不等它是两回事**：
  /// 本地有内容时后台拉（[_refreshThreadFromServer]），本地空时必须等着拉完。
  Future<bool> _pullThreadFromServer(String threadId) async {
    // ⚠️ **只在本地引擎下做**。云端模式的会话本来就在服务器上，
    // `thread/resume` 读到的**就是**最新那份 —— 打不开就是真打不开，
    // 把服务器文件下到本机既没用（引擎读的不是本机那份）又会误导。
    if (ref.read(composerSettingsProvider).settings.engineMode !=
        EngineMode.local) {
      return false;
    }
    return ref.read(sessionSyncRepositoryProvider).refreshThread(threadId);
  }

  /// 本地内容已经在屏幕上之后，问一下服务器这条会话有没有更新。
  ///
  /// ## 为什么是"之后"而不是"之前"
  ///
  /// 这条会话可能是在另一台设备上聊的，本机那份 rollout 停在某个旧偏移。
  /// 但**先等服务器再显示**就退回了原来的毛病 —— 网络慢一次，用户就又在
  /// 干等。所以顺序是：本地秒回 → 后台问 → 真有新内容才重装。
  ///
  /// ## 只在真的变了才重装
  ///
  /// 重装会重建所有气泡、把滚动位置顶回去。绝大多数情况下服务器没有新东西
  /// （就是本机自己聊的那条），无条件重装等于每次点开都白闪一下。
  ///
  /// ## 失败不管
  ///
  /// 仓储层已经把失败咽成 `false`（见 `refreshThread` 的注释）。用户手上那份
  /// 是完整的本地历史，没拉到更新不值得提示，更不能把它换成错误。
  Future<void> _refreshThreadFromServer(String threadId, int gen) async {
    // 引擎模式的判断在 [_pullThreadFromServer] 里（云端模式恒为 false，
    // 那边有原因）。
    if (!await _pullThreadFromServer(threadId)) return;
    // 用户可能已经切走了（开了新对话、点了另一条）。往一个已经换掉的会话里
    // 灌内容比不刷新糟得多。
    if (_openGeneration != gen) {
      debugPrint('[threads] $threadId 有更新，但用户已切走，不重装');
      return;
    }
    debugPrint('[threads] $threadId 从服务器拿到更新，重新装配');
    try {
      final replay = await ref.read(threadRepositoryProvider).open(threadId);
      if (_openGeneration != gen) return; // 再查一次：取数期间也可能切走
      openThread(threadId, replay.events);
    } catch (e) {
      // 已经显示着本地那份，重装失败就维持现状。
      debugPrint('[threads] $threadId 重装失败，保留本地内容：$e');
    }
  }

  /// 清空当前内容并进入"正在载入历史会话"。[openThreadById] 的前半拍。
  ///
  /// ⚠️ 它在 [openThreadById] 的**首个 await 之前**，因而是同步跑完的 ——
  /// 调用方 `unawaited(openThreadById(id))` 之后紧接着 `context.go` 时，
  /// 工作台已经是"正在载入"的干净状态，不会闪一下上一条会话的残留内容。
  /// 换句话说调用方**不需要**自己先调一次。
  ///
  /// [threadId] 立刻写进 [ChatSessionState.currentThreadId]，让左栏历史列表
  /// 在内容真正载入完成之前就先亮起来 —— 载入是异步的，用户点完到内容回来
  /// 之间那段空档如果不亮，看着就像"没点中"。
  void beginOpenThread(String threadId) {
    _openGeneration++;
    if (state.busy) interrupt();
    for (final i in _items) {
      i.dispose();
    }
    _items.clear();
    _byId.clear();
    _streaming = null;
    itemsRevision.value++;

    // 同 openThread：capabilities 属于连接不属于会话，清掉会让首次发送被拒。
    state = ChatSessionState(
      capabilities: state.capabilities,
      openingThread: true,
      currentThreadId: threadId,
    );
  }

  /// 装配一条历史会话的回放内容，并把后续发言接到这条 thread 上。
  ///
  /// [replayEvents] 是 `view::replay_thread` 产出的事件序列（由
  /// `ThreadRepository.open` 取回），**不含 turn 级事件** —— 所以这里不碰
  /// `busy` / `turnId` / `lastTiming` / `lastUsage`：回放是装配历史，不是
  /// "刚跑完一轮"。
  void openThread(String threadId, List<Map<String, Object?>> replayEvents) {
    if (state.busy) interrupt();
    for (final i in _items) {
      i.dispose();
    }
    _items.clear();
    _byId.clear();
    _streaming = null;

    for (final item in ViewEventMapper.toItems(replayEvents, () => _syntheticId--)) {
      _append(item);
    }
    itemsRevision.value++;

    // ⚠️ **必须保留 capabilities**。能力属于连接、不属于会话 —— 清掉的话
    // 打开历史后第一次发送就因 caps==null 被拒，还会顺带触发重连
    // （`newChat()` 那段注释记的是同一个坑）。
    state = ChatSessionState(
      capabilities: state.capabilities,
      currentThreadId: threadId,
    );

    // 让后续发言接在这条 thread 上。Rust 侧 `thread/resume` 已经把它装进了
    // 活动的 thread_manager，所以 turn/start 打得中。
    _client.setThread(threadId);
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
        // 这一轮的内容已经落进 rollout，排一次同步（内部去抖 30s，连续对话
        // 不会每轮都推）。本地引擎产生的会话靠它才能在云端列表里出现。
        // 未启用时（Web / 服务端进程）这是 no-op。
        ref.read(sessionSyncProvider).onTurnCompleted();
        // 列表里那条的 updatedAt 变了，顺手刷新 —— 否则"刚聊完的会话"在左栏
        // 仍排在旧位置，看着像没记上。
        unawaited(ref.read(threadListProvider.notifier).reload());
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
