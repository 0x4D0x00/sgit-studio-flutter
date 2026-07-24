import 'package:flutter/material.dart';

/// Web/移动占位:不引入 bitsdojo_window，不渲染任何窗口按钮。
class WindowBarView extends StatelessWidget {
  const WindowBarView({super.key, this.leading, this.center});

  final Widget? leading;
  final Widget? center;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
