import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/data/transport/kernel/kernel_frame.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/services/chat/chat_item_store.dart';

KernelFrame _frame(KernelFrameKind kind, int itemId, [String payload = '']) =>
    KernelFrame(
      kind: kind,
      flags: 0,
      seq: 0,
      itemId: itemId,
      payload: Uint8List.fromList(utf8.encode(payload)),
    );

void main() {
  late int contentStarted;
  late ChatItemStore store;

  setUp(() {
    contentStarted = 0;
    store = ChatItemStore(onContentStarted: () => contentStarted++);
  });
  tearDown(() => store.dispose());

  test('itemStarted 新增条目（结构变化）并通知收起思考行；delta 只追加文本', () {
    expect(store.apply(_frame(KernelFrameKind.itemStarted, 7)), isTrue);
    expect(contentStarted, 1);
    expect(store.items, hasLength(1));

    expect(store.apply(_frame(KernelFrameKind.itemDelta, 7, 'ab')), isFalse);
    expect(store.apply(_frame(KernelFrameKind.itemDelta, 7, 'cd')), isFalse);
    expect((store.items.single as TextItem).text, 'abcd');
    expect(store.items, hasLength(1), reason: 'delta 不增删条目');
  });

  test('toolBegin 同样收起思考行；会话级帧交给控制器，传进来必须抛', () {
    store.apply(
      _frame(KernelFrameKind.toolBegin, 3, '{"name":"bash","args":"ls"}'),
    );
    expect(contentStarted, 1);
    expect(store.items.single, isA<ToolItem>());

    expect(
      () => store.apply(_frame(KernelFrameKind.turnCompleted, 0)),
      throwsStateError,
    );
  });

  test('onDropped：给正在流的条目打 truncated，并插一条提示', () {
    store.apply(_frame(KernelFrameKind.itemStarted, 1));
    expect(store.onDropped(5), isTrue);
    expect((store.items.first as TextItem).truncated, isTrue);
    expect(store.items.last, isA<NoticeItem>());
  });

  test('truncateFrom：丢掉该条及之后；找不到 id 时什么都不改', () {
    store.appendUserText('a');
    store.appendUserText('b');
    store.appendUserText('c');
    final second = store.items[1].id;

    expect(store.truncateFrom(9999), isFalse);
    expect(store.items, hasLength(3));

    expect(store.truncateFrom(second), isTrue);
    expect(store.items, hasLength(1));
  });

  test('appendUserText 自己通知列表；clear 不通知', () {
    final before = store.revision.value;
    store.appendUserText('hi');
    expect(store.revision.value, before + 1);

    store.clear();
    expect(store.items, isEmpty);
    expect(store.revision.value, before + 1);
  });

  test('合成 id 递减且互不相同（避免和内核的正数 id 撞车）', () {
    final a = store.nextSyntheticId();
    final b = store.nextSyntheticId();
    expect(a, lessThan(0));
    expect(b, lessThan(a));
  });
}
