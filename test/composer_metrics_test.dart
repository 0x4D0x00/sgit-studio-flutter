import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/design/tokens/composer_metrics.dart';

/// 钉住输入框尺寸与 sgit-studio（React）一致。
///
/// ## 这份测试为什么存在
///
/// 尺寸对不上**不会报错、不会崩、CI 全绿**，只会让两端长得不一样，而且通常要等
/// 到有人把两个界面并排摆在一起才发现。这里把每个数值连同它的 React 出处写死：
/// 谁改了，测试红给他看，红的信息里就写着该去哪个文件核对。
///
/// 改动流程：**先去 React 那边确认新值 → 再同时改令牌和本测试**。
/// 只改令牌不改测试，或者反过来，都说明这次改动没有经过核对。
///
/// 出处根目录：`D:/Projects/sgit-studio/src`
void main() {
  group('玻璃外壳 · features/ChatInput/glassInputStyle.ts:7-17', () {
    test('圆角 24 / 四边 padding 16 / 描边 1', () {
      expect(ComposerMetrics.shellRadius, 24);
      // ⚠️ React 是 `padding: 16` 一个值 —— **四边相同**。
      // 老版 Flutter 写成 symmetric(h:16, v:8)，上下少了一半。
      expect(ComposerMetrics.shellPadding, 16);
      expect(ComposerMetrics.shellBorderWidth, 1);
    });

    test('模糊 12（不是玻璃卡片那份 16）', () {
      expect(ComposerMetrics.shellBlurSigma, 12);
    });
  });

  group('编辑区 · Desktop/index.tsx:181-188、home/InputArea/index.tsx:144-153', () {
    test('会话态 min 36、空态 min 60、上限 320', () {
      expect(ComposerMetrics.editorMinHeightConversation, 36);
      expect(ComposerMetrics.editorMinHeightEmpty, 60);
      expect(ComposerMetrics.editorMaxHeight, 320);
    });

    test('空态比会话态高 —— 空态时输入框是页面主角', () {
      expect(
        ComposerMetrics.editorMinHeightEmpty,
        greaterThan(ComposerMetrics.editorMinHeightConversation),
      );
    });
  });

  group('动作栏 · ActionBar/components/Action.tsx:76-81、Plus/index.tsx:706', () {
    test('按钮 32 / 图标 18 / 圆角 8', () {
      expect(ComposerMetrics.actionButtonSize, 32);
      expect(ComposerMetrics.actionIconSize, 18);
      expect(ComposerMetrics.actionButtonRadius, 8);
    });

    test('左 6 右 8（ActionBar/index.tsx:90、Desktop/index.tsx:192）', () {
      expect(ComposerMetrics.actionBarPaddingStart, 6);
      expect(ComposerMetrics.actionBarPaddingEnd, 8);
    });

    test('发送区间距 12（SendArea/index.tsx:30）', () {
      expect(ComposerMetrics.sendAreaGap, 12);
    });

    test('发送键与动作图标同高 —— 不同高会让整排基线歪掉', () {
      expect(ComposerMetrics.sendButtonSize, ComposerMetrics.actionButtonSize);
    });
  });

  group('模型名标签 · ActionBar/ModelLabel/index.tsx:17-49,88-100', () {
    test('高 28 / 左右 6 / 圆角 4 / 字 12 / 最宽 160 / chevron 12', () {
      expect(ComposerMetrics.modelLabelHeight, 28);
      expect(ComposerMetrics.modelLabelPaddingInline, 6);
      expect(ComposerMetrics.modelLabelRadius, 4);
      expect(ComposerMetrics.modelLabelFontSize, 12);
      expect(ComposerMetrics.modelLabelMaxWidth, 160);
      expect(ComposerMetrics.modelLabelChevronSize, 12);
    });
  });

  group('动作栏项间距', () {
    test('项间 4 / chip 的 × 是 12', () {
      expect(ComposerMetrics.actionItemGap, 4);
      expect(ComposerMetrics.chipCloseIconSize, 12);
    });
  });

  group('上下文窗口标签 · ActionBar/Token/TokenTag.tsx:158,244-247', () {
    test('高 28 / 图标 18', () {
      expect(ComposerMetrics.tokenTagHeight, 28);
      expect(ComposerMetrics.tokenTagIconSize, 18);
    });

    test('阈值 0.5 —— 占用不到一半时整个不画', () {
      expect(ComposerMetrics.tokenTagVisibleThreshold, 0.5);
    });
  });

  group('控制条 · ControlBar/index.tsx:16-40、ModeSelector.tsx:45-67', () {
    test('条：高 28 / 左右 4 / 项间 4', () {
      expect(ComposerMetrics.controlBarHeight, 28);
      expect(ComposerMetrics.controlBarPaddingInline, 4);
      expect(ComposerMetrics.controlBarGap, 4);
    });

    test('按钮：高 28 / 左右 8 / 圆角 6 / 字 12 / icon 14 / chevron 12 / gap 6', () {
      expect(ComposerMetrics.controlButtonHeight, 28);
      expect(ComposerMetrics.controlButtonPaddingInline, 8);
      expect(ComposerMetrics.controlButtonRadius, 6);
      expect(ComposerMetrics.controlButtonFontSize, 12);
      expect(ComposerMetrics.controlButtonIconSize, 14);
      expect(ComposerMetrics.controlButtonChevronSize, 12);
      expect(ComposerMetrics.controlButtonGap, 6);
    });

    test('控制条按钮与 token 标签等高 —— 一条 28 高的行里不能有高矮不齐的项', () {
      expect(
        ComposerMetrics.controlButtonHeight,
        ComposerMetrics.tokenTagHeight,
      );
      expect(
        ComposerMetrics.controlBarHeight,
        ComposerMetrics.controlButtonHeight,
      );
    });
  });

  group('弹出面板 · ApprovalPolicy/index.tsx:130、ModeSelector.tsx:187,199-206', () {
    test('最小 260 / 最大 320 / 图标方块 32 内 16', () {
      expect(ComposerMetrics.popoverMinWidth, 260);
      expect(ComposerMetrics.popoverMaxWidth, 320);
      expect(ComposerMetrics.richItemIconBoxSize, 32);
      expect(ComposerMetrics.richItemIconSize, 16);
    });

    test('最小宽不超过最大宽', () {
      expect(
        ComposerMetrics.popoverMinWidth,
        lessThanOrEqualTo(ComposerMetrics.popoverMaxWidth),
      );
    });
  });
}
