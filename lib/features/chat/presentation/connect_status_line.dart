import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/core/contracts/kernel_client.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 建连等待条 —— **轮播状态语**。
///
/// 沙箱冷启动要几十秒。这段时间里一个固定的"连接中…"和界面卡死在用户看来
/// 没有区别（真踩过：用户以为消息压根没发出去）。所以：
///
/// 1. 文案按 [rotateEvery] 轮换，让用户看得出"它还活着"；
/// 2. 带上已等待秒数与进度条，给出**可预期的终点**；
/// 3. 词表按阶段分组，随时可以加词，不影响协议 —— 后端只发机器可读的阶段。
class ConnectStatusLine extends StatefulWidget {
  const ConnectStatusLine({
    super.key,
    required this.progress,
    this.rotateEvery = const Duration(seconds: 3),
  });

  final KernelConnectProgress progress;

  /// 每隔多久换一句。太快像乱跳，太慢又显得卡住，3s 是个舒服的值。
  final Duration rotateEvery;

  @override
  State<ConnectStatusLine> createState() => _ConnectStatusLineState();
}

class _ConnectStatusLineState extends State<ConnectStatusLine> {
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.rotateEvery, (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void didUpdateWidget(ConnectStatusLine old) {
    super.didUpdateWidget(old);
    // 换阶段就从头开始念，别把上一阶段的句子接着轮下去。
    if (old.progress.phase != widget.progress.phase) _tick = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 各阶段的轮播词表。**加词只改这里**，协议不动。
  List<String> _phrases(AppLocalizations l10n) =>
      switch (widget.progress.phase) {
        KernelConnectPhase.connecting => [
            l10n.kernelPhaseConnecting1,
            l10n.kernelPhaseConnecting2,
          ],
        KernelConnectPhase.sandboxStarting => [
            l10n.kernelPhaseSandbox1,
            l10n.kernelPhaseSandbox2,
            l10n.kernelPhaseSandbox3,
            l10n.kernelPhaseSandbox4,
            l10n.kernelPhaseSandbox5,
            l10n.kernelPhaseSandbox6,
          ],
        KernelConnectPhase.ready => [l10n.kernelPhaseReady],
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final p = widget.progress;
    final phrases = _phrases(l10n);
    final text = phrases[_tick % phrases.length];

    return Container(
      width: double.infinity,
      color: skin.containerBgSecondary,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xxs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                    strokeWidth: 1.6, color: skin.textSecondary),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                // 换句时淡入淡出，比硬切自然。
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Text(
                    text,
                    key: ValueKey(text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: skin.textSecondary),
                  ),
                ),
              ),
              // 有终点的等待才不焦虑。
              if (p.timeoutSecs > 0)
                Text('${p.elapsedSecs}s / ${p.timeoutSecs}s',
                    style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: skin.textTertiary)),
            ],
          ),
          const SizedBox(height: 3),
          // 拿不到预算时退回不确定进度条，别显示一条假的百分比。
          LinearProgressIndicator(minHeight: 2, value: p.ratio),
        ],
      ),
    );
  }
}
