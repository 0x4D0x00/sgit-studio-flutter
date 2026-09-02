import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 系统提示条：压缩点、模型改道、错误、断线、丢帧。
///
/// [NoticeItem] 只带类型与数据（控制器没有 `BuildContext`，拼不出本地化文案），
/// 文案在这里 switch 出来 —— 新增 [NoticeKind] 时编译器会在这里报错，漏不掉。
class NoticeBar extends StatelessWidget {
  const NoticeBar({super.key, required this.item});

  final NoticeItem item;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final (icon, color, text) = switch (item.kind) {
      NoticeKind.compacted => (
          Icons.compress_rounded,
          skin.textTertiary,
          l10n.chatNoticeCompacted,
        ),
      NoticeKind.modelRerouted => (
          Icons.alt_route_rounded,
          skin.textTertiary,
          l10n.chatNoticeModelRerouted(item.detail),
        ),
      NoticeKind.dropped => (
          Icons.merge_type_rounded,
          scheme.tertiary,
          l10n.chatNoticeDropped(item.count),
        ),
      NoticeKind.disconnected => (
          Icons.link_off_rounded,
          scheme.error,
          l10n.chatNoticeDisconnected,
        ),
      // 后端错误消息直显原文 —— 错误码到本地文案的映射还没做（见 ARCHITECTURE.md C.23）。
      NoticeKind.error => (
          Icons.error_outline_rounded,
          scheme.error,
          item.detail.isEmpty ? l10n.commonError : item.detail,
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
