import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sgit_studio_flutter/domain/models/studio/resource_item.dart';
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
  final List<ResourceItem> items;
}

/// 对历史会话进行排序和分组
List<GroupedHistoryItem> sortAndGroupHistory(
  List<ResourceItem> items,
  ChatSortBy sortBy,
  ChatGroupBy groupBy,
  String Function(String) getGroupTitle,
) {
  // 1. 排序
  final sorted = List<ResourceItem>.from(items);
  switch (sortBy) {
    case ChatSortBy.lastActivity:
      sorted.sort((a, b) {
        final aTime = _parseTime(a.extra('updatedAt'));
        final bTime = _parseTime(b.extra('updatedAt'));
        return bTime.compareTo(aTime); // 降序
      });
    case ChatSortBy.name:
      sorted.sort((a, b) {
        final aName = a.name.isEmpty ? a.id : a.name;
        final bName = b.name.isEmpty ? b.id : b.name;
        return _compareByFirstLetter(aName, bName);
      });
  }

  // 2. 分组
  if (groupBy == ChatGroupBy.none) {
    return [
      GroupedHistoryItem(
        groupKey: 'all',
        groupTitle: '',
        items: sorted,
      ),
    ];
  }

  final Map<String, List<ResourceItem>> groups = {};
  for (final item in sorted) {
    final key = _getGroupKey(item, groupBy);
    groups.putIfAbsent(key, () => []).add(item);
  }

  // 3. 按固定顺序返回分组列表（今天→昨天→更早）
  final result = <GroupedHistoryItem>[];

  // 按日期分组时，确保顺序固定
  if (groupBy == ChatGroupBy.date) {
    const orderedKeys = ['today', 'yesterday', 'older'];
    for (final key in orderedKeys) {
      if (groups.containsKey(key)) {
        result.add(GroupedHistoryItem(
          groupKey: key,
          groupTitle: getGroupTitle(key),
          items: groups[key]!,
        ));
      }
    }
  } else {
    // 其他分组方式，保持插入顺序
    result.addAll(groups.entries.map((e) {
      return GroupedHistoryItem(
        groupKey: e.key,
        groupTitle: getGroupTitle(e.key),
        items: e.value,
      );
    }));
  }

  return result;
}

String _getGroupKey(ResourceItem item, ChatGroupBy groupBy) {
  switch (groupBy) {
    case ChatGroupBy.none:
      return 'all';
    case ChatGroupBy.date:
      final time = _parseTime(item.extra('updatedAt')).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final itemDate = DateTime(time.year, time.month, time.day);

      if (itemDate == today) {
        return 'today';
      } else if (itemDate == yesterday) {
        return 'yesterday';
      } else {
        return 'older';
      }
    case ChatGroupBy.assistant:
      // TODO: 待实现 - 需要助理信息
      return 'assistant_${item.id}';
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

DateTime _parseTime(String timeStr) {
  try {
    return DateTime.parse(timeStr);
  } catch (_) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
