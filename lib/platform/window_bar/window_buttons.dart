import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';

/// 桌面端窗口 bar 实现(window_manager)。透明、可拖拽、含窗口按钮。
class WindowBarView extends StatelessWidget {
  const WindowBarView({super.key, this.leading, this.center});

  final Widget? leading;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: AppWindow.titleBarHeight,
      child: Row(
        children: [
          const SizedBox(width: 2),
          if (leading != null) leading!,
          // 中间区域整体可拖拽移动窗口。
          Expanded(
            child: DragToMoveArea(
              child: Align(
                alignment: Alignment.center,
                child: center ?? const SizedBox.expand(),
              ),
            ),
          ),
          _WinButtons(color: theme.colorScheme.onSurface),
        ],
      ),
    );
  }
}

class _WinButtons extends StatelessWidget {
  const _WinButtons({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _WinButton(
          icon: Icons.minimize_rounded,
          color: color,
          onPressed: () => windowManager.minimize(),
        ),
        _WinButton(
          icon: Icons.crop_square_rounded,
          color: color,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
            }
          },
        ),
        _WinButton(
          icon: Icons.close_rounded,
          color: color,
          hoverColor: const Color(0xFFF43F5E),
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _WinButton extends StatefulWidget {
  const _WinButton({
    required this.icon,
    required this.color,
    required this.onPressed,
    this.hoverColor,
  });

  final IconData icon;
  final Color color;
  final Color? hoverColor;
  final VoidCallback onPressed;

  @override
  State<_WinButton> createState() => _WinButtonState();
}

class _WinButtonState extends State<_WinButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: AppWindow.titleBarHeight,
          color: _hover
              ? (widget.hoverColor ?? widget.color.withValues(alpha: 0.08))
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 18,
            color: _hover && widget.hoverColor != null
                ? Colors.white
                : widget.color.withValues(alpha: _hover ? 1.0 : 0.7),
          ),
        ),
      ),
    );
  }
}
