import 'package:flutter/material.dart';

class SkillItem {
  final IconData icon;
  final String title;
  final String description;
  final String source;
  final String installs;

  SkillItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.source,
    required this.installs,
  });
}

class ConnectorItem {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  ConnectorItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
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
