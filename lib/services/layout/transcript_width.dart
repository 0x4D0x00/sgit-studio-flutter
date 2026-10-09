import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/core/storage/local_storage.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';

/// 中栏转录列宽档位。设置页「转录宽度」三选一（Narrow / Medium / Wide）。
///
/// ## 为什么不是裸 double
///
/// 用户选的是**档**，不是像素。存一个 731.5 进本地，下一版设计调了基准值就会
/// 出现「用户卡在旧宽度上」的幽灵 bug。档位名落盘，像素值留在
/// [WorkspaceMetrics] —— 与 `AppThemeMode` 存 `mode.name` 同一条思路。
///
/// ## 为什么住 `services/` 而不是 `layout/`
///
/// 布局是**全 app 都要读的 5 个横切状态之一**（主题 / 语言 / 特效 / 布局 / 会话），
/// 而 `layout/` 那一层按 `ARCHITECTURE.md` 第三节不许 import 状态管理库。
/// 与 [LayoutController] 同理，换 Riverpod → Signals 时只有本文件要重写。
enum TranscriptWidth {
  narrow,
  medium,
  wide;

  /// 中栏内容列（空态 / 转录）的最大宽度。
  double get contentMaxWidth => switch (this) {
        TranscriptWidth.narrow => WorkspaceMetrics.transcriptNarrowWidth,
        TranscriptWidth.medium => WorkspaceMetrics.transcriptMediumWidth,
        TranscriptWidth.wide => WorkspaceMetrics.transcriptWideWidth,
      };

  /// 输入框外壳宽度。
  ///
  /// ⚠️ **不是常量** —— 外壳自己有一层 `Center`，如果让它保持 768 而正文列变窄，
  /// 窄档下输入框会比正文宽出去；变宽时又够不到右边缘。两者必须同源。
  double get composerWidth =>
      contentMaxWidth - WorkspaceMetrics.contentPaddingInline * 2;

  /// 宽度值本身与语言无关，所以三个档的**显示名**由 l10n 按 enum 索引取
  /// （`l10n.settingsTranscriptNarrow` 等），不放这里 —— 见 `settings_page.dart`。
  static TranscriptWidth parse(String? v) => switch (v) {
        'narrow' => TranscriptWidth.narrow,
        'wide' => TranscriptWidth.wide,
        _ => TranscriptWidth.medium,
      };
}

/// 转录宽度控制器。默认 [TranscriptWidth.medium] —— 与改动前的中栏宽度**逐像素相同**，
/// 所以这个开关上线时不会改变任何现存用户的界面。
class TranscriptWidthController extends Notifier<TranscriptWidth> {
  @override
  TranscriptWidth build() =>
      TranscriptWidth.parse(LocalStorage.instance.transcriptWidth);

  void set(TranscriptWidth width) {
    state = width;
    LocalStorage.instance.setTranscriptWidth(width.name);
  }
}

final transcriptWidthProvider =
    NotifierProvider<TranscriptWidthController, TranscriptWidth>(
        TranscriptWidthController.new);
