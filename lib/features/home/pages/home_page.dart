import 'package:flutter/material.dart';

import '../../../core/brand/brand_assets.dart';
import '../../../core/brand/brand_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/layout/workspace_metrics.dart';

/// 工作台中栏 —— 对齐 sgit-studio 首页空态（`home/features/index.tsx`）。
///
/// 纵向：`paddingBlock: 44px 10vh` 居中；内容列宽 `min(960, 100%)`、内左右 16。
/// 内容自上而下：Hero 头像(96 圆) → 欢迎语(24/600) → 输入框(固定 768 宽, 圆角 24) → 技能标签。
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final vh = MediaQuery.sizeOf(context).height;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        top: WorkspaceMetrics.centerPaddingTop,
        bottom: vh * 0.10, // studio 的 10vh
      ),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: WorkspaceMetrics.contentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: WorkspaceMetrics.contentPaddingInline),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _heroAvatar(),
                    const SizedBox(width: 16),
                    Flexible(child: _welcome(isDark)),
                  ],
                ),
                const SizedBox(height: 24),
                _inputArea(isDark),
                const SizedBox(height: 12),
                _skillChips(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 96×96 圆形头像 + 4px 白边 + 柔和投影（studio HeroAvatar）。
  Widget _heroAvatar() => Container(
        width: WorkspaceMetrics.heroAvatarSize,
        height: WorkspaceMetrics.heroAvatarSize,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [
            BoxShadow(
                color: Color(0x1A000000), blurRadius: 15, offset: Offset(0, 10)),
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
      );

  Widget _welcome(bool isDark) => Text(
        // 产品名取自 brand.json，不写死。
        '${BrandConfig.instance.name}，为你待命',
        style: TextStyle(
          fontSize: WorkspaceMetrics.welcomeFontSize,
          fontWeight: FontWeight.w600,
          height: 1.6,
          color: isDark ? AppColors.textDark : AppColors.textLight,
        ),
      );

  /// 玻璃输入框：768 宽居中、圆角 24、padding 16（studio glassInputStyle）。
  Widget _inputArea(bool isDark) => Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: WorkspaceMetrics.inputAreaWidth),
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF18181B).withValues(alpha: 0.55)
                  : Colors.white.withValues(alpha: 0.6),
              borderRadius:
                  BorderRadius.circular(WorkspaceMetrics.inputAreaRadius),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : const Color(0xFFDCEBF8).withValues(alpha: 0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      isDark ? const Color(0x59000000) : const Color(0x24788AAA),
                  blurRadius: isDark ? 24 : 20,
                  offset: Offset(0, isDark ? 8 : 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    maxLines: 4,
                    minLines: 1,
                    // ⚠️ 不能用 InputDecoration.collapsed:它不设 filled,会继承全局
                    // inputDecorationTheme 的 filled+fillColor+border,在玻璃框里
                    // 又套出一个灰底输入框。这里逐项显式关掉。
                    decoration: InputDecoration(
                      isCollapsed: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: '有什么可以帮你的？',
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const IconButton(
                  icon: Icon(Icons.arrow_upward_rounded, size: 18),
                  // 对话链路未接:FFI 目前没有 thread/message 能力(见 sgit-ffi 只有 5 个符号)。
                  onPressed: null,
                ),
              ],
            ),
          ),
        ),
      );

  /// 技能标签：高 40、圆角 pill、青绿 #009688 系（studio SkillChips）。
  Widget _skillChips() => Wrap(
        alignment: WrapAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final s in const ['防火墙策略下发', '日志分析', '资产梳理', '漏洞研判'])
            Container(
              height: WorkspaceMetrics.skillChipHeight,
              padding: const EdgeInsets.symmetric(horizontal: 17),
              decoration: BoxDecoration(
                color: AppColors.skillChip.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                    color: AppColors.skillChip.withValues(alpha: 0.15)),
              ),
              // 用 Row(min) 而非 Container.alignment —— 后者在无界约束下会撑满整行。
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.skillChip,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
}
