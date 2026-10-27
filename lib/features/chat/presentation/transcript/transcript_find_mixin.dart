import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_find.dart';
import 'package:sgit_studio_flutter/domain/models/find/find_matcher.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/transcript/transcript_reveal_mixin.dart';
import 'package:sgit_studio_flutter/features/find/application/find_controller.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/ui/components/find/find_highlight.dart';

/// 对话流的页内查找：给每条消息编匹配序号、把匹配数报给 [FindController]、
/// 切换「当前匹配」时把它滚进视野。
///
/// 匹配只数**正文**（用户文本 + 助手回复的 markdown 叶子文本，口径见
/// `MarkdownFind`），工具卡 / 审批卡 / 代码块里的字不算。
mixin TranscriptFindMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, TranscriptRevealMixin<T> {
  /// 条目 id → 它的第一个匹配在转录里的全局序号。
  final findStarts = <int, int>{};

  final _counts = <int, int>{};
  final _countCache = <int, _CountEntry>{};
  int _reported = 0;
  bool _reportScheduled = false;
  bool _findRevealScheduled = false;

  /// 序号对不上时还能重试几次。
  ///
  /// 左栏的匹配数是它自己 build 之后在**帧末**才报上来的，而定位也排在帧末 ——
  /// 刚改完关键词的那一帧里读到的左栏匹配数还是上一个词的旧值，换算出来的
  /// 「转录内序号」会是负数或越界。等下一帧数就对了。
  int _findRetries = 0;

  /// dispose 阶段 `ref` 不再可靠，提前留一份。
  FindController? _findNotifier;

  /// 在列表 builder 里调用：按 [query] 重排序号并上报总数。[query] 空表示没在查找。
  void syncFind(List<ChatItem> items, String query) {
    _findNotifier ??= ref.read(findControllerProvider.notifier);
    findStarts.clear();
    _counts.clear();
    var total = 0;
    if (query.isNotEmpty) {
      for (final it in items) {
        if (it is! TextItem) continue;
        final n = _countOf(it, query);
        if (n == 0) continue;
        findStarts[it.id] = total;
        _counts[it.id] = n;
        total += n;
      }
    } else {
      _countCache.clear();
    }
    _report(total);
  }

  int _countOf(TextItem it, String query) {
    final text = it.displayText;
    final hit = _countCache[it.id];
    // displayText 在内容没变时是同一个 String 对象，用 identical 省掉重复解析。
    if (hit != null && identical(hit.text, text) && hit.query == query) {
      return hit.count;
    }
    final count = it.role == ChatRole.user
        ? FindMatcher.count(text, query)
        : MarkdownFind.countBlocks(MarkdownParser.parse(text), query);
    _countCache[it.id] = _CountEntry(text, query, count);
    return count;
  }

  /// 总数只在变了才报，且挪到帧末 —— builder 里不能改 provider。
  void _report(int total) {
    if (total == _reported && !_reportScheduled) return;
    _reported = total;
    if (_reportScheduled) return;
    _reportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportScheduled = false;
      if (!mounted) return;
      ref.read(findControllerProvider.notifier).setTranscriptCount(_reported);
    });
  }

  /// 离开会话页时把本区域的匹配数清零（不然另一页的 N/M 还带着转录的数）。
  void clearFindReport() {
    final notifier = _findNotifier;
    if (notifier == null) return;
    // 微任务而不是 Future：dispose 阶段不能改 provider，但也不该留 Timer。
    scheduleMicrotask(() {
      try {
        notifier.setTranscriptCount(0);
      } catch (_) {
        // 容器已随应用一起销毁，没有可清的了。
      }
    });
  }

  void scheduleFindReveal() {
    if (_findRevealScheduled) return;
    _findRevealScheduled = true;
    _findRetries = 0;
    resetRevealSteps();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _findRevealScheduled = false;
      if (!mounted) return;
      _findReveal();
    });
  }

  void _scheduleFindRetry() {
    if (_findRevealScheduled) return;
    _findRevealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _findRevealScheduled = false;
      if (mounted) _findReveal();
    });
  }

  void _findReveal() {
    final s = ref.read(findControllerProvider);
    if (!s.active) return;
    final local = s.current - s.navCount;
    if (local < 0 || local >= _reported) {
      if (++_findRetries <= 3) _scheduleFindRetry();
      return;
    }

    final items = ref.read(chatControllerProvider.notifier).items;
    var idx = -1;
    for (var i = 0; i < items.length; i++) {
      final start = findStarts[items[i].id];
      if (start == null) continue;
      if (local >= start && local < start + _counts[items[i].id]!) {
        idx = i;
        break;
      }
    }
    if (idx < 0) {
      if (++_findRetries <= 3) _scheduleFindRetry();
      return;
    }

    final ctx = itemKeys[items[idx].id]?.currentContext;
    if (ctx != null) {
      // 先尝试精确定位到高亮文字。
      final render = ctx.findRenderObject();
      if (render != null &&
          scrollToCurrentFindMatch(render, scroll, FindColors.of(context))) {
        return;
      }
      // 找不到高亮文字（还没重绘 / 在横向滚动的表格里），至少滚到这条消息。
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.3,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    // 条目还没建出来，要逐步跳转 —— 定位期间不能让「跟随最新」把视口钉回底部。
    follow = false;
    if (stepToward(items, idx)) {
      _findRevealScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _findRevealScheduled = false;
        if (mounted) _findReveal();
      });
    }
  }
}

class _CountEntry {
  const _CountEntry(this.text, this.query, this.count);
  final String text;
  final String query;
  final int count;
}
