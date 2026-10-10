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

class YourSkillItem {
  final String name;
  final String badge;
  final String description;
  final String source;
  final String time;

  YourSkillItem({
    required this.name,
    required this.badge,
    required this.description,
    required this.source,
    required this.time,
  });
}

class YourConnectorItem {
  final IconData icon;
  final Color color;
  final String name;
  final String type;
  final String status;

  YourConnectorItem({
    required this.icon,
    required this.color,
    required this.name,
    required this.type,
    required this.status,
  });
}
