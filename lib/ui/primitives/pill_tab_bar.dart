import 'package:flutter/material.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

/// 单个标签描述。[dividerBefore] 为 true 时在它前面画一条竖线分隔（用于把
/// 「内容类型」标签和「视图」标签分成两组，参见 Customize 页面的 Skills/
/// Connectors/Plugins | Yours/Discover）。
class PillTab {
  const PillTab({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dividerBefore = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dividerBefore;
}

/// 一行 pill 风格标签：悬停/选中态背景高亮，可选竖线分组分隔。
class PillTabBar extends StatefulWidget {
  const PillTabBar({super.key, required this.tabs});

  final List<PillTab> tabs;

  @override
  State<PillTabBar> createState() => _PillTabBarState();
}

class _PillTabBarState extends State<PillTabBar> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.tabs.length; i++)
            Padding(
              padding: EdgeInsets.only(
                right: i < widget.tabs.length - 1 ? AppSpacing.xs : 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.tabs[i].dividerBefore)
                    Container(
                      width: 1,
                      height: 20,
                      margin: const EdgeInsets.only(right: AppSpacing.xs),
                      color: skin.border,
                    ),
                  _buildTabItem(widget.tabs[i], i, skin),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabItem(PillTab tab, int index, AppSkin skin) {
    final isHovered = _hoveredIndex == index;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredIndex = index),
      onExit: (_) => setState(() => _hoveredIndex = null),
      child: InkWell(
        onTap: tab.onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: tab.selected || isHovered
                ? skin.textSecondary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Text(
            tab.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: tab.selected ? FontWeight.w600 : FontWeight.w400,
              color: tab.selected ? skin.text : skin.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
