import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/services/brand/brand_assets.dart';
import 'package:sgit_studio_flutter/services/brand/brand_config.dart';

/// 空态的 Hero 行：96 圆头像 + 欢迎语（studio HeroAvatar + Welcome）。
class WorkspaceHero extends StatelessWidget {
  const WorkspaceHero({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 96×96 圆形头像 + 4px 白边 + 柔和投影。
        Container(
          width: WorkspaceMetrics.heroAvatarSize,
          height: WorkspaceMetrics.heroAvatarSize,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 15,
                  offset: Offset(0, 10)),
              BoxShadow(
                  color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 4)),
            ],
          ),
          child: ClipOval(
            child: Image(
              image: BrandAssets.image(BrandAssets.loginMark),
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            // 产品名取自 brand.json，文案模板走 l10n，两者都不写死。
            l10n.workspaceWelcome(BrandConfig.instance.name),
            style: TextStyle(
              fontSize: WorkspaceMetrics.welcomeFontSize,
              fontWeight: FontWeight.w600,
              height: 1.6,
              color: skin.text,
            ),
          ),
        ),
      ],
    );
  }
}

/// 技能标签：高 40、圆角 pill（studio SkillChips）。
///
/// ⚠️ [_placeholder] 是**占位业务数据**，不是界面文案，所以不进 arb
/// （进了就等于把客户的技能名钉在我们的翻译文件里）。
/// TODO(P2) 换成 scene 的真实 skill 清单，经 FFI 取。
class WorkspaceSkillChips extends StatelessWidget {
  const WorkspaceSkillChips({super.key, required this.accent});

  final Color accent;

  static const List<String> _placeholder = [
    '防火墙策略下发',
    '日志分析',
    '资产梳理',
    '漏洞研判',
  ];

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final s in _placeholder)
            Container(
              height: WorkspaceMetrics.skillChipHeight,
              padding: const EdgeInsets.symmetric(horizontal: 17),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: accent.withValues(alpha: 0.15)),
              ),
              // 用 Row(min) 而非 Container.alignment —— 后者在无界约束下会撑满整行。
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
}
