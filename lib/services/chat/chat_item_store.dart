import 'package:flutter/foundation.dart';

import 'package:sgit_studio_flutter/data/mappers/kernel_frame_mapper.dart';
import 'package:sgit_studio_flutter/data/transport/kernel/kernel_frame.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';
import 'package:sgit_studio_flutter/services/chat/chat_ports.dart';

/// 会话条目列表 + 条目级的帧处理。
///
/// 从 `ChatController` 里拆出来的**纯数据部分**：不碰 Riverpod、不碰 [ChatSessionState]，
/// 只管「条目怎么增删、一帧落到哪个条目上」。会话级状态（busy / turnId / 用量 / 故障…）
/// 仍由控制器写 —— 这样条目逻辑可以脱离 provider 单测，控制器也只剩状态机。
///
/// ## 性能约定（原样保留）
/// - **条目身份稳定**：`ListView.builder` 靠它避免整表重建。
/// - [revision] 只在增删条目时 +1；纯文本追加只动条目自己的 `ChatItem.revision`。
/// - [KernelFrameKind.itemDelta] 是热路径：一次 UTF-8 解码，不 jsonDecode，不动列表。
class ChatItemStore {
  /// [onContentStarted]：本轮第一段内容落地（`itemStarted` / `toolBegin`）时调用，
  /// 控制器据此收起「思考中」状态行。
  ChatItemStore({required void Function() onContentStarted})
    : _onContentStarted = onContentStarted;

  final void Function() _onContentStarted;

  /// 条目按到达顺序排列。
  final List<ChatItem> _items = [];
  final Map<int, ChatItem> _byId = {};

  /// 当前正在流式追加的文本条目（`itemStarted` 开、`itemCompleted` 关）。
  TextItem? _streaming;
  int _syntheticId = -1;

  /// 结构版本：只在增删条目时 +1。
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<ChatItem> get items => List.unmodifiable(_items);

  /// 供内部遍历用（不拷贝）。调用方**不许改**。
  Iterable<ChatItem> get raw => _items;

  /// 本地合成条目用的 id（内核的 id 都是正数，合成的取负数避免撞车）。
  int nextSyntheticId() => _syntheticId--;

  void notifyStructure() => revision.value++;

  void append(ChatItem item) {
    _items.add(item);
    _byId[item.id] = item;
  }

  /// 本地发出的用户消息。**自己通知列表** —— [revision] 的另一处 ++ 在帧 drain 里，
  /// 那条路径只覆盖内核推来的帧；漏了这句用户气泡就不显示。
  void appendUserText(String text) {
    append(
      TextItem(
        id: nextSyntheticId(),
        role: ChatRole.user,
        initial: text,
        createdAt: DateTime.now(),
      ),
    );
    notifyStructure();
  }

  /// 清空并释放全部条目。**不通知** —— 调用方通常紧接着还要装配新内容，自己决定何时通知。
  void clear() {
    for (final i in _items) {
      i.dispose();
    }
    _items.clear();
    _byId.clear();
    _streaming = null;
  }

  /// 丢掉 [itemId] 及其之后的所有条目（编辑重发用）。找不到返回 false，不改任何东西。
  ///
  /// ⚠️ 只是本地视图的截断，不是内核层面的回滚。
  bool truncateFrom(int itemId) {
    final index = _items.indexWhere((i) => i.id == itemId);
    if (index == -1) return false;
    final removed = _items.sublist(index);
    _items.removeRange(index, _items.length);
    for (final i in removed) {
      _byId.remove(i.id);
      i.dispose();
    }
    if (removed.contains(_streaming)) _streaming = null;
    return true;
  }

  /// 当前流式条目收尾（`turnCompleted` 用）。
  void finishStreaming() {
    _streaming?.markDone();
    _streaming = null;
  }

  /// native 因背压丢过 delta。**必须显形**：给当前条目打标 + 插一条提示。
  /// 契约 §3 要求「不许假装没发生」。返回 true（插了条目 = 结构变化）。
  bool onDropped(int count) {
    final streaming = _streaming;
    if (streaming != null) {
      streaming.truncated = true;
      streaming.revision.value++;
    }
    return notice(NoticeKind.dropped, count: count);
  }

  bool notice(NoticeKind kind, {String detail = '', int count = 0}) {
    append(
      NoticeItem(
        id: nextSyntheticId(),
        kind: kind,
        detail: detail,
        count: count,
      ),
    );
    return true;
  }

  /// 处理只影响条目的帧。返回 true 表示列表**结构**变了（增删条目）。
  ///
  /// 会话级状态的帧（turn 起止、用量、断线）不在这里，由控制器处理；
  /// 传进来会抛 [StateError]，以免有人在两边都漏了某个 kind。
  bool apply(KernelFrame f) {
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
        _onContentStarted();
        final item = TextItem(
          id: f.itemId,
          role: ChatRole.assistant,
          createdAt: DateTime.now(),
        );
        _streaming = item;
        append(item);
        return true;

      case KernelFrameKind.itemCompleted:
        _streaming?.markDone();
        _streaming = null;
        return false;

      case KernelFrameKind.toolBegin:
        // 模型直接决定调工具、一个字正文都没吐 —— 工具卡本身就是"在干活"的证据，
        // 思考行该让位。少这一步的话，一条纯工具轮的思考行会一直转到 turn 结束。
        _onContentStarted();
        final j = KernelFrameMapper.json(f);
        append(
          ToolItem(
            id: f.itemId,
            name: KernelFrameMapper.str(j, 'name', 'tool'),
            argsSummary: KernelFrameMapper.str(j, 'args'),
          ),
        );
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
        append(
          ApprovalItem(
            // 用合成 id：这条卡片和工具卡是两个条目，不能共用 id。
            id: nextSyntheticId(),
            reqId: KernelFrameMapper.intOrNull(j, 'req_id') ?? 0,
            kind: KernelFrameMapper.str(j, 'kind'),
            reason: KernelFrameMapper.str(j, 'reason'),
            // 命令/补丁全文取自那条工具卡，没有就退回空（不编内容）。
            target: tool is ToolItem ? tool : null,
          ),
        );
        return true;

      case KernelFrameKind.compacted:
        return notice(NoticeKind.compacted);

      case KernelFrameKind.modelRerouted:
        return notice(
          NoticeKind.modelRerouted,
          detail: KernelFrameMapper.str(KernelFrameMapper.json(f), 'to'),
        );

      case KernelFrameKind.error:
        return notice(
          NoticeKind.error,
          detail: KernelFrameMapper.str(KernelFrameMapper.json(f), 'message'),
        );

      case KernelFrameKind.turnStarted:
      case KernelFrameKind.turnCompleted:
      case KernelFrameKind.tokenUsage:
      case KernelFrameKind.disconnected:
      case KernelFrameKind.hello:
      case KernelFrameKind.callResult:
        throw StateError('${f.kind} 是会话级帧，应由 ChatController 处理');
    }
  }

  /// 扫当前会话里**助手回复的长围栏**，产出要登记到「输出物」的文件卡。
  ///
  /// 规则与聊天里画文件卡的一致（同样走 [ChatArtifact.fromBlocks]）——
  /// 输出物页里有的，聊天里一定有卡。解析整条会话有成本，调用方负责挪出热路径。
  List<FoundArtifact> collectArtifacts() {
    final found = <FoundArtifact>[];
    for (final it in _items) {
      if (it is! TextItem || it.role != ChatRole.assistant || it.isEmpty) {
        continue;
      }
      // ⚠️ 与聊天里画文件卡用的是**同一份文本**（[TextItem.displayText]，
      //    已去掉开头的调用抬头）—— 否则输出物页里的 sourceStart 会和
      //    聊天里那张卡对不上，点卡片定位不到。
      final text = it.displayText;
      final blocks = MarkdownParser.parse(text);
      for (final a in ChatArtifact.fromBlocks(blocks, text)) {
        found.add((artifact: a, at: it.createdAt));
      }
    }
    return found;
  }

  void dispose() {
    for (final i in _items) {
      i.dispose();
    }
    revision.dispose();
  }
}
