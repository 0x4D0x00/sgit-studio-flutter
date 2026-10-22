import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';

/// 给卡片套一层：鼠标悬停时在右上角浮出圆形 × 按钮。
///
/// [onRemove] 为 null 时原样返回 [child]（不可移除的场景）。
class HoverRemoveButton extends StatefulWidget {
  const HoverRemoveButton({
    super.key,
    required this.child,
    required this.onRemove,
    this.semanticLabel = '',
  });

  final Widget child;
  final VoidCallback? onRemove;
  final String semanticLabel;

  @override
  State<HoverRemoveButton> createState() => _HoverRemoveButtonState();
}

class _HoverRemoveButtonState extends State<HoverRemoveButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final onRemove = widget.onRemove;
    if (onRemove == null) return widget.child;
    final skin = AppSkin.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 4,
            right: 4,
            child: IgnorePointer(
              ignoring: !_hovered,
              child: AnimatedOpacity(
                opacity: _hovered ? 1 : 0,
                duration: const Duration(milliseconds: 100),
                child: Semantics(
                  label: widget.semanticLabel,
                  button: true,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: skin.containerBgSecondary,
                        border: Border.all(color: skin.borderSecondary),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: skin.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
