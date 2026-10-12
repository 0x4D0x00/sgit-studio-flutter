import 'package:flutter_test/flutter_test.dart';
import 'package:sgit_studio_flutter/data/mappers/view_event_mapper.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';

/// 钉住「会话工具行日期」的语义：
/// 回放出来的气泡显示的是**会话自身的创建时间**，不是"打开它的那一刻"。
///
/// 原先 `ChatItem.createdAt` 缺省为 `DateTime.now()`，回放 mapper 又不传，
/// 于是打开任何历史会话，每个气泡都显示今天。
void main() {
  final events = <Map<String, Object?>>[
    {'t': 'userMessage', 'text': 'hi'},
    {'t': 'textStarted', 'itemId': 'a'},
    {'t': 'textDelta', 'itemId': 'a', 'chunk': 'hello'},
    {'t': 'textCompleted', 'itemId': 'a'},
  ];

  test('回放的文本条目带 thread 创建时间，而不是当前时间', () {
    final threadCreated = DateTime(2024, 1, 2, 3, 4);
    var id = -1;
    final items = ViewEventMapper.toItems(events, () => id--,
        createdAt: threadCreated);

    final texts = items.whereType<TextItem>().toList();
    expect(texts, hasLength(2));
    for (final t in texts) {
      expect(t.createdAt, threadCreated);
    }
  });

  test('没有 thread 时间时为 null（不显示），不编造 now()', () {
    var id = -1;
    final items = ViewEventMapper.toItems(events, () => id--);

    for (final t in items.whereType<TextItem>()) {
      expect(t.createdAt, isNull);
    }
  });
}
