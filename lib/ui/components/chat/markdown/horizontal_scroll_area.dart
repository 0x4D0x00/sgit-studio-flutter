import 'package:flutter/foundation.dart' show precisionErrorTolerance;
import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/bubble_metrics.dart';

/// 回复正文里的**横向滚动区** —— 代码块、表格共用的一条"可以右滑"指示条。
///
/// ## 为什么要有这个东西
///
/// 代码块和表格都是**不换行、超出就裁掉**的内容：一行长代码在窄列里只露出前
/// 半截，右边那一截既看不见、也没有任何提示告诉用户它存在。读者会默认"这行就
/// 到这儿为止"，把半截命令当完整命令读 —— 这是会出错的。
///
/// 所以这里补两件事：**正文下方一道常驻滑块** + 一条专供它落脚的底部空带。
///
/// ## 为什么不用 `Scrollbar` 而用 `RawScrollbar`
///
/// 1. `Scrollbar` 在 iOS 上会**换成 `CupertinoScrollbar`**，那个实现的滑块颜色
///    写死（`_kScrollbarColor`），不吃外部传色 —— 明暗/透明三套皮肤在 iOS 上会
///    直接失效。`RawScrollbar` 没有这个分叉。
/// 2. `Scrollbar` 不暴露 `thumbColor`，想上色只能先套一层 `ScrollbarTheme`，
///    为了一个颜色多铺一层 InheritedWidget 不划算。
///
/// 代价是 `RawScrollbar` 的 `fadeDuration` / `timeToFade` 等要自己给 —— 都有
/// 默认值，且我们开了 `thumbVisibility`(常驻)，淡出那套根本用不上。
///
/// ## 为什么底部空带要"按需"留
///
/// `RawScrollbar` 的绘制区域**就是那个滚动视图的盒子**（内部是
/// `CustomPaint(foregroundPainter: ...)` 包住 child）。滑块画在
/// `y = 盒子高 - 粗细 - 间距`，也就是**盒子底边内侧**。想让滑块落在正文**下方**
/// 而不是压在最后一行上，唯一的办法是让盒子比正文高一点 —— 即底边垫一条空带。
///
/// 但空带一旦常驻，每个短代码块底下都会白多出一道缝。所以用
/// [ScrollMetricsNotification] 感知"内容到底溢出了没有"，只在溢出时才垫。
///
/// ⚠️ 垫空带**不会**反过来触发滚动指标变化：空带加在横滚的**交叉轴**（高）上，
/// 而 `maxScrollExtent` 走主轴（宽）—— 不存在"垫了空带 → 又通知 → 再垫"的循环。
class HorizontalScrollArea extends StatefulWidget {
  const HorizontalScrollArea({super.key, required this.child});

  /// 要横向滚动的内容。宽度按自身内在宽度铺开（外层给的横向约束无界），
  /// 所以**不会换行** —— 这正是代码块和表格需要的行为。
  final Widget child;

  @override
  State<HorizontalScrollArea> createState() => _HorizontalScrollAreaState();
}

class _HorizontalScrollAreaState extends State<HorizontalScrollArea> {
  /// ⚠️ 必须自己持有 controller。`RawScrollbar` 开了 `thumbVisibility` 之后
  /// 会在 post-frame 断言里要求它绑定到**恰好一个** [ScrollPosition]；
  /// 靠 `PrimaryScrollController` 的话，会话流里前后都是滚动视图，拿到的
  /// 未必是这一个。
  final _controller = ScrollController();

  /// 内容是否比视口宽 —— 决定要不要垫出滑条那道空带。
  ///
  /// ⚠️ 不能拿"有没有滚动条"代替：`RawScrollbar` 在内容装得下时**自己不画**
  /// （`paint` 里 `maxScrollExtent <= minScrollExtent` 直接 return），但空带是
  /// 我们额外垫的，不看这个标志的话短内容底下会常年多出一道白。
  bool _overflows = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    // 指标通知是**帧结束后由 microtask 发出**的，理论上可能晚于本组件被
    // dispose（比如流式回答中途整条消息被换掉）。这里兜一下。
    if (!mounted) return false;

    // ⚠️ 只认自己这一个滚动视图。`depth` 是沿途经过的 Viewport 层数 ——
    // 嵌套滚动视图(将来正文里再嵌一个能滚的东西)发出来的通知也会冒到这儿，
    // 拿它的 `maxScrollExtent` 去判"我溢出了没"会得到错的答案。
    // 0 这个门槛与 SDK 的 `defaultScrollNotificationPredicate` 一致。
    if (notification.depth != 0) return false;

    // 阈值取 SDK 自己的 [precisionErrorTolerance] —— `RawScrollbar._needPaint`
    // 判"要不要画"用的是同一个值。这里用别的容差，会出现"空带垫了但条没画"
    // 或反过来的那一帧。
    final overflows = notification.metrics.maxScrollExtent > precisionErrorTolerance;
    if (overflows != _overflows) {
      setState(() => _overflows = overflows);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: RawScrollbar(
        controller: _controller,
        // 常驻：它是"这里能滑"的提示，不是滚动时的瞬时反馈。
        // 内容装不下时 SDK 自己会不画，不需要我们再判一次。
        thumbVisibility: true,
        scrollbarOrientation: ScrollbarOrientation.bottom,
        thickness: ChatBubbleMetrics.hScrollThickness,
        radius: const Radius.circular(ChatBubbleMetrics.hScrollRadius),
        // 底色走皮肤（明暗/透明自动跟随），这里只压一层透明度。
        thumbColor: skin.textTertiary.withValues(
          alpha: ChatBubbleMetrics.hScrollThumbAlpha,
        ),
        // ⚠️ **必须显式清零**：`RawScrollbar` 默认吃
        // `MediaQuery.paddingOf(context)`，那套是给贴屏幕边缘的滚动视图留安全区的。
        // 这段文字在会话流中间，离屏幕边十万八千里 —— 不清零的话滑块会被
        // 莫名顶开一截。
        padding: EdgeInsets.zero,
        crossAxisMargin: ChatBubbleMetrics.hScrollCrossAxisMargin,
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          // 空带只在真溢出时垫。见类文档里那段推算：这 8px 恰好是滑条
          // (6) + 间距 (1) 再加 1px 余量。
          padding: EdgeInsets.only(
            bottom: _overflows ? ChatBubbleMetrics.hScrollGutter : 0,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
