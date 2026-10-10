import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';

/// 标题旁的小 chip，例如 "Legal" 后面的 "+2"。
///
/// Skills / Plugins 的行列表和卡片共用一份，避免两处各写一遍圆角和字号。
class CustomizeTagChip extends StatelessWidget {
  const CustomizeTagChip({
    super.key,
    required this.label,
    required this.skin,
  });

  final String label;
  final AppSkin skin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: skin.textSecondary,
        ),
      ),
    );
  }
}
