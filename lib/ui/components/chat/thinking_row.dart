import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/design/tokens/bubble_metrics.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 「正在思考」状态行 —— 出现在助手回复**之前**。
///
/// ## 它是什么、不是什么
///
/// 内核协议里没有 reasoning 帧（见 [ChatSessionState.thinking]），所以这一行
/// **不是**把模型的想法渲染出来，而是把"已发出、还没吐字"这段静默讲清楚：
/// 只轮播"我在干什么"级别的动词。
///
/// ## 三条互不重叠的收尾路径
///
/// | 情况 | 行怎么消失 | 兜底在哪 |
/// | --- | --- | --- |
/// | 正常出字 | 一起淡出，助手正文接上 | `itemStarted` 清 `thinking` |
/// | 直接调工具 | 工具卡现身，行让位 | `toolBegin` 清 `thinking` |
/// | interrupted→turnCompleted | 随 `busy` 一起收 | `copyWith` 把 `thinking` 绑在 `busy` 上 |
///
/// 第三条是关键：**每一处清 `busy` 的地方都自动清了它**，所以停用、
/// 断开、看门狗超时、中途打断都不用各自记得处理一遍。
class ThinkingRow extends StatefulWidget {
  const ThinkingRow({super.key, this.rotateEvery = const Duration(seconds: 3)});

  /// 每隔多久换一句。与 [ConnectStatusLine] 同值 —— 那是"活着"的语速，
  /// 用户已经在这一套节奏里了，这里换一个速度只会显得是两个不相干的机制。
  final Duration rotateEvery;

  @override
  State<ThinkingRow> createState() => _ThinkingRowState();
}

class _ThinkingRowState extends State<ThinkingRow> {
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
  void dispose() {
    // ⚠️ 必须停。这一行在每轮对话里都会被创建/销毁，漏掉就是每轮攒一个
    // 无限期的 Timer —— `flutter test` 会直接报"测试结束时仍有挂起的 Timer"。
    _timer?.cancel();
    super.dispose();
  }

  /// 轮播词表。**加词只改这里**，协议不动（照 [ConnectStatusLine] 的做法）。
  ///
  /// ⚠️ 全部是**进行时、不承诺结果**的动词。写"正在分析你的问题"这种＝替模型
  /// 说了它还没说的话：真答案可能根本不是"分析"，而是直接查一下文件。
  List<String> _phrases(AppLocalizations l10n) => [
        l10n.chatThinking1,
        l10n.chatThinking2,
        l10n.chatThinking3,
        l10n.chatThinking4,
        l10n.chatThinking5,
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final phrases = _phrases(l10n);
    final text = phrases[_tick % phrases.length];

    // 左内边距与助手正文对齐 —— 状态行在视觉上属于**助手这一侧**，
    // 缩进不一致会让它看着像一条系统通知，而不是"回答正在生成"。
    return Padding(
      padding: const EdgeInsets.only(
        left: ChatBubbleMetrics.thinkingInline,
        top: ChatBubbleMetrics.thinkingPaddingBlock,
        bottom: ChatBubbleMetrics.thinkingPaddingBlock,
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome,
              size: ChatBubbleMetrics.thinkingMarkSize,
              color: AppColors.thinkingAccent),
          const SizedBox(width: AppSpacing.xs), 
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              // 换句时淡入淡出，与建连状态条同一套节奏，比硬切自然。
              child: Text(
                text,
                key: ValueKey(text),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: ChatBubbleMetrics.thinkingFontSize,
                    color: skin.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}
