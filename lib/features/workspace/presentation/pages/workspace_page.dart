import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_session.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/assistant_switcher_container.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/chat_composer.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/chat_transcript.dart';
import 'package:sgit_studio_flutter/features/workspace/presentation/widgets/workspace_hero.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/connect_status_line.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';

/// 工作台中栏 —— 对齐 sgit-studio 首页（`home/features/index.tsx`）的**就地对话**。
///
/// 两态，同一个页面：
/// - **空态**：Hero 头像 + 欢迎语 + 技能标签 + 助理切换区（居中），下方输入区；
/// - **有对话**：上方 [ChatTranscript] 撑满，下方输入区固定。
///
/// 输入区两态共用 [ChatComposer]，所以从空态发第一条消息时输入框不会跳位。
///
/// 助理切换区与技能标签**同一套逻辑**：只在空态出现。开聊之后 scene 已经定了，
/// 再摆一排切换按钮等于邀请用户点掉自己刚才的对话（切助理会清列表重开一轮）。
class WorkspacePage extends ConsumerStatefulWidget {
  const WorkspacePage({super.key});

  @override
  ConsumerState<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends ConsumerState<WorkspacePage> {
  @override
  void initState() {
    super.initState();
    // 建连 + 能力协商。失败不抛到界面外，由 fault 渲染成提示条。
    Future.microtask(
        () => ref.read(chatControllerProvider.notifier).connect());
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.read(chatControllerProvider.notifier);
    final fault = ref.watch(chatControllerProvider.select((s) => s.fault));

    final progress =
        ref.watch(chatControllerProvider.select((s) => s.progress));
    final notice = ref.watch(chatControllerProvider.select((s) => s.notice));
    final openingThread =
        ref.watch(chatControllerProvider.select((s) => s.openingThread));

    return Column(
      children: [
        // 建连中：轮播状态语 + 已等待秒数。沙箱冷启动要几十秒，
        // 全程静默的等待和卡死在用户看来没有区别。
        if (progress != null) ConnectStatusLine(progress: progress),
        if (fault != null) _faultBar(context, fault),
        if (notice != null) _noticeBar(context, notice),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: ctrl.itemsRevision,
            builder: (context, _, __) {
              final isEmpty = ctrl.items.isEmpty;
              // ⚠️ 载入历史会话时**不能落到空态**。空态是"开始新对话"的欢迎页
              // （Hero + 技能标签），而用户刚点的是一条有内容的旧会话 ——
              // 先给他看一眼欢迎页再弹出内容，比等着更让人困惑。
              if (isEmpty && openingThread) return const _OpeningThread();
              return isEmpty
                  ? const _EmptyState(
                      composer: ChatComposer(variant: ComposerVariant.empty),
                    )
                  : Column(
                      children: [
                        const Expanded(child: ChatTranscript()),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            WorkspaceMetrics.contentPaddingInline,
                            0,
                            WorkspaceMetrics.contentPaddingInline,
                            WorkspaceMetrics.framePadding * 2,
                          ),
                          child: const ChatComposer(
                            variant: ComposerVariant.conversation,
                          ),
                        ),
                      ],
                    );
            },
          ),
        ),
      ],
    );
  }

  /// 一次性轻提示条。**动作被拒时必须有东西出现** —— 之前 busy 时发送、
  /// 无 turn 时插话都是静默返回，用户只看到"点了没反应、字还在输入框里"。
  Widget _noticeBar(BuildContext context, ChatNotice notice) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final text = switch (notice) {
      ChatNotice.busy => l10n.chatSendWhileBusy,
      ChatNotice.noTurnToSteer => l10n.chatNoTurnToSteer,
      ChatNotice.stalled => l10n.chatKernelStalled,
      ChatNotice.noModel => l10n.chatNoModelAvailable,
    };
    return Container(
      width: double.infinity,
      color: skin.containerBgSecondary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: skin.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: skin.textSecondary)),
          ),
        ],
      ),
    );
  }

  /// 会话级故障条。[ChatFault] 只带类型，文案在这里 switch 出来。
  ///
  /// ⚠️ 除版本不匹配外都给「重连」按钮 —— 没有出口的错误提示等于没提示，
  /// 用户只能刷页面。版本不匹配重连也没用，那个只能升级客户端。
  Widget _faultBar(BuildContext context, ChatFault fault) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (text, retryable) = switch (fault) {
      FrameVersionMismatch(:final kernel, :final client) => (
          l10n.chatFaultVersionMismatch(kernel, client),
          false,
        ),
      KernelNotConnected() => (l10n.chatFaultNotConnected, true),
      KernelUnavailable(:final message) => (message, true),
      // 不给重连按钮：坏的是这一条会话，不是连接。见 ThreadOpenFailed 的注释。
      ThreadOpenFailed(:final message) => (
          l10n.chatThreadOpenFailed(message),
          false,
        ),
      // 同样不给重连：重连变不出一个不存在的可执行文件。
      LocalExecUnavailable() => (l10n.chatLocalExecUnavailable, false),
    };

    return Container(
      width: double.infinity,
      color: scheme.error.withValues(alpha: 0.12),
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 16, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: scheme.error)),
          ),
          if (retryable)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: scheme.error,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () =>
                  ref.read(chatControllerProvider.notifier).connect(),
              child: Text(l10n.chatReconnect),
            ),
        ],
      ),
    );
  }
}

/// 空态：Hero + 欢迎语 + 技能标签 + 输入框（在标签下方）。
/// 「正在载入这条会话」。覆盖点开历史到内容装配之间那段空窗。
///
/// 刻意**不带输入框**：`thread/resume` 落地前 `turn/start` 找不到这条 thread，
/// 此刻能发送只会得到一个 "thread not found"。没有输入框比有一个发不出去的
/// 输入框诚实。
class _OpeningThread extends StatelessWidget {
  const _OpeningThread();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: skin.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.chatOpeningThread,
            style: TextStyle(fontSize: 12, color: skin.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.composer});

  final Widget composer;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        top: WorkspaceMetrics.centerPaddingTop,
        left: WorkspaceMetrics.contentPaddingInline,
        right: WorkspaceMetrics.contentPaddingInline,
        bottom: WorkspaceMetrics.framePadding * 2,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
              maxWidth: WorkspaceMetrics.contentMaxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const WorkspaceHero(),
              const SizedBox(height: 24),
              WorkspaceSkillChips(accent: skin.accentChip),
              const SizedBox(height: AppSpacing.lg),
              const AssistantSwitcherContainer(),
              const SizedBox(height: AppSpacing.lg),
              composer,
            ],
          ),
        ),
      ),
    );
  }
}
