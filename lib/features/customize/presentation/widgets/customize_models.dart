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
