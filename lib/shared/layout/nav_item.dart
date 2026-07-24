import 'package:flutter/material.dart';

/// 侧栏导航项数据。
class NavItemData {
  const NavItemData({required this.icon, required this.label, required this.route});
  final IconData icon;
  final String label;
  final String route;
}
