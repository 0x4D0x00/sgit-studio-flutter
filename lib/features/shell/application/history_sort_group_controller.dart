import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sgit_studio_flutter/domain/models/chat/thread_summary.dart';
import 'package:lpinyin/lpinyin.dart';

/// 历史会话排序方式
enum ChatSortBy {
  /// 最近活动
  lastActivity,
  /// 名称首字母
  name,
}

/// 历史会话分组方式
enum ChatGroupBy {
  /// 无分组
  none,
  /// 按日期分组
  date,
  /// 按助理分组
  assistant,
}

/// 历史会话排序和分组的状态
class HistorySortGroupState {
  const HistorySortGroupState({
    this.sortBy = ChatSortBy.lastActivity,
    this.groupBy = ChatGroupBy.none,
    this.collapsedGroups = const {},
  });

  final ChatSortBy sortBy;
  final ChatGroupBy groupBy;

  /// 折叠的分组 key 集合
  final Set<String> collapsedGroups;

  HistorySortGroupState copyWith({
    ChatSortBy? sortBy,
    ChatGroupBy? groupBy,
    Set<String>? collapsedGroups,
  }) {
    return HistorySortGroupState(
      sortBy: sortBy ?? this.sortBy,
      groupBy: groupBy ?? this.groupBy,
      collapsedGroups: collapsedGroups ?? this.collapsedGroups,
    );
  }
}

/// 历史会话排序和分组的控制器
class HistorySortGroupController extends StateNotifier<HistorySortGroupState> {
  HistorySortGroupController() : super(const HistorySortGroupState());

  void setSortBy(ChatSortBy sortBy) {
    state = state.copyWith(sortBy: sortBy);
  }

  void setGroupBy(ChatGroupBy groupBy) {
    state = state.copyWith(groupBy: groupBy, collapsedGroups: {});
  }

  void toggleGroupCollapse(String groupKey) {
    final collapsed = Set<String>.from(state.collapsedGroups);
    if (collapsed.contains(groupKey)) {
      collapsed.remove(groupKey);
    } else {
      collapsed.add(groupKey);
    }
    state = state.copyWith(collapsedGroups: collapsed);
  }
}

final historySortGroupControllerProvider =
    StateNotifierProvider<HistorySortGroupController, HistorySortGroupState>(
  (ref) => HistorySortGroupController(),
);

/// 分组后的历史会话项
class GroupedHistoryItem {
  const GroupedHistoryItem({
    required this.groupKey,
    required this.groupTitle,
    required this.items,
  });

  final String groupKey;
  final String groupTitle;
  final List<ThreadSummary> items;
}

/// 对历史会话进行排序和分组。
///
/// ## 分组：今天 / 昨天 / 更早
///
/// 就这三档。React studio 那边分了六档（本周、本月、再按年月年份细分成
/// 「3 月」「2025」这样的组），**不照抄** —— 会话列表一屏就 20 条，切成六组
/// 只会让每组剩两三条、标题比内容还多。三档足够回答"最近的在哪"。
///
/// ## 时间是强类型 `DateTime?`，不是字符串
///
/// ⚠️ 原先入参是 `ResourceItem`、时间取 `extra('updatedAt')` 再 `DateTime.parse`。
/// 而 sgcode 给的是 **Unix 秒的整数** —— `DateTime.parse("1758412800")` 抛异常，
/// 被 catch 成 epoch 0，于是所有会话都落进"更早"、排序全乱，**一行日志都没有**。
/// 现在类型上就杜绝了：转换只在 `ThreadSummary.fromJson` 一处发生。
///
/// 时间缺失（`updatedAt == null`）的排到最后，**不用 epoch 0 顶替** ——
/// 那会把"数据缺失"伪装成"很老的会话"。
List<GroupedHistoryItem> sortAndGroupHistory(
  List<ThreadSummary> items,
  ChatSortBy sortBy,
  ChatGroupBy groupBy,
  String Function(String) getGroupTitle,
) {
  // 1. 排序
  final sorted = List<ThreadSummary>.from(items);
  switch (sortBy) {
    case ChatSortBy.lastActivity:
      sorted.sort((a, b) {
        // null 排最后：缺时间戳是数据问题，不该被当成"最早"。
        if (a.updatedAt == null && b.updatedAt == null) return 0;
        if (a.updatedAt == null) return 1;
        if (b.updatedAt == null) return -1;
        return b.updatedAt!.compareTo(a.updatedAt!); // 降序
      });
    case ChatSortBy.name:
      sorted.sort((a, b) => _compareByFirstLetter(a.title, b.title));
  }

  // 2. 分组
  if (groupBy == ChatGroupBy.none) {
    return [
      GroupedHistoryItem(groupKey: 'all', groupTitle: '', items: sorted),
    ];
  }

  final groups = <String, List<ThreadSummary>>{};
  for (final item in sorted) {
    groups.putIfAbsent(_groupKey(item, groupBy), () => []).add(item);
  }

  // 3. 按固定顺序输出：今天 → 昨天 → 更早 → 时间未知。
  const ordered = ['today', 'yesterday', 'older', 'unknown'];
  return [
    for (final k in ordered)
      if (groups.containsKey(k))
        GroupedHistoryItem(
          groupKey: k,
          groupTitle: getGroupTitle(k),
          items: groups[k]!,
        ),
  ];
}

String _groupKey(ThreadSummary item, ChatGroupBy groupBy) {
  switch (groupBy) {
    case ChatGroupBy.none:
      return 'all';
    case ChatGroupBy.date:
      final t = item.updatedAt?.toLocal();
      // 没有时间戳的单独成组：既不算"今天"，也不该混进"更早"装成老会话。
      if (t == null) return 'unknown';

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day = DateTime(t.year, t.month, t.day);

      if (day == today) return 'today';
      if (day == today.subtract(const Duration(days: 1))) return 'yesterday';
      return 'older';
    case ChatGroupBy.assistant:
      // 按助理分组要先有 thread → agent 的归属映射（服务端的 `topic_owner`
      // 记着，但客户端目前拿不到）。接上之前这里保持未接，菜单项也标着未接。
      return 'assistant_unknown';
  }
}

/// 按首字母排序：中文取拼音首字母，英文取首字母
int _compareByFirstLetter(String a, String b) {
  final aFirst = _getFirstLetter(a);
  final bFirst = _getFirstLetter(b);

  if (aFirst != bFirst) {
    return aFirst.compareTo(bFirst);
  }

  // 首字母相同时，按完整名称排序
  return a.toLowerCase().compareTo(b.toLowerCase());
}

/// 获取字符串的首字母（中文转拼音，英文取首字母）
String _getFirstLetter(String text) {
  if (text.isEmpty) return '';

  final firstChar = text[0];

  // 判断是否为中文字符 (基本汉字范围 U+4E00 到 U+9FFF)
  if (firstChar.codeUnitAt(0) >= 0x4E00 && firstChar.codeUnitAt(0) <= 0x9FFF) {
    // 使用 lpinyin 获取拼音首字母
    final pinyin = PinyinHelper.getFirstWordPinyin(firstChar);
    return pinyin.isNotEmpty ? pinyin[0].toUpperCase() : firstChar;
  }

  // 英文或其他字符，直接返回首字母大写
  return firstChar.toUpperCase();
}
