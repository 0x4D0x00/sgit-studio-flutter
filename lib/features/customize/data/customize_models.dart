import 'package:flutter/material.dart';

class SkillItem {
  final IconData icon;
  final String title;
  final String description;
  final String source;
  final String installs;

  /// 标题旁的小 chip，例如全量列表里的 "Legal" + "+2"。
  /// 卡片（Discover）不展示，只有行列表用。
  final List<String> tags;

  SkillItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.source,
    required this.installs,
    this.tags = const [],
  });
}

class ConnectorItem {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  /// 卡片底部 "by Google" 里的作者方。Discover 的紧凑卡片不展示。
  final String source;

  ConnectorItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.source,
  });
}

/// Yours 页连接器表格的一行。原先定义在 `yours_connector_table.dart` 里，
/// 挪到模型文件 —— 组件文件里不该藏数据类型。
class YoursConnectorRow {
  final IconData icon;
  final String name;
  final String type;
  final String status;

  YoursConnectorRow({
    required this.icon,
    required this.name,
    required this.type,
    required this.status,
  });
}
