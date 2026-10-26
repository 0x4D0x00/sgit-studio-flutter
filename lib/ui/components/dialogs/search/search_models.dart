import 'package:flutter/material.dart';

/// 搜索条目所属的类型。决定图标、落在哪个标签下，以及行尾「⁝」里有哪些动作。
enum SearchDialogCategory { artifact, chat, project }

/// 行尾「⁝」菜单里的一项动作。对话框只回传动作，**不自己执行** ——
/// 打开 / 改名 / 删除分别由调用方接（`ui/` 层不 import features）。
enum SearchDialogRowAction { open, pin, rename, editDetails, copyLink, delete }

/// 行动作执行完的结果。弹窗据此就地刷新列表（不关弹窗）。
@immutable
class SearchRowResult {
  const SearchRowResult.removed() : removed = true, newLabel = null;
  const SearchRowResult.renamed(String this.newLabel) : removed = false;

  final bool removed;
  final String? newLabel;
}

/// 「操作」里的一条命令。选中后先关弹窗再执行 [onRun]。
///
/// [featured] 的命令也会出现在「全部」标签的「操作」分组里；其余只在筛选「操作」后列出。
@immutable
class SearchDialogCommand {
  const SearchDialogCommand({
    required this.label,
    required this.icon,
    required this.onRun,
    this.featured = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onRun;
  final bool featured;
}

/// 搜索弹窗里的一行 —— 展示用，选中后回传 [id] 给调用方。
@immutable
class SearchDialogItem {
  const SearchDialogItem({
    required this.id,
    required this.label,
    required this.category,
    this.updatedAt,
  });

  final String id;
  final String label;
  final SearchDialogCategory category;

  /// 右侧相对时间列（今天 / 过去一周 / 过去一月 / 过去一年 / 更早）。
  /// null = 不显示 —— 内核偶有缺时间戳的旧数据，不拿 epoch 0 顶替。
  final DateTime? updatedAt;
}
