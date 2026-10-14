import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';

/// 工作台外壳状态：左右栏的展开与宽度（对应 studio 的 global store
/// `showLeftPanel` / `leftPanelWidth` / 右栏 expand）。
///
/// 放在 `services/` 而不是 `layout/`：布局是**全 app 都要读的 5 个横切状态之一**
/// （主题 / 语言 / 特效 / 布局 / 会话），而 `layout/` 一层按约定不许 import 状态管理库。
/// 换 Riverpod → Signals 时，只有本文件这类 controller 需要重写。
@immutable
class LayoutState {
  const LayoutState({
    this.navExpanded = true,
    this.navWidth = WorkspaceMetrics.navDefaultWidth,
    this.outputExpanded = false,
    this.outputWidth = WorkspaceMetrics.outputDefaultWidth,
    this.activeArtifact,
  });

  final bool navExpanded;
  final double navWidth;
  final bool outputExpanded;
  final double outputWidth;

  /// 当前在右侧面板显示的产物。
  final ChatArtifact? activeArtifact;

  LayoutState
  copyWith({
    bool? navExpanded,
    double? navWidth,
    bool? outputExpanded,
    double? outputWidth,
    ChatArtifact? activeArtifact,
    bool clearArtifact = false,
  }) => LayoutState(
    navExpanded:
        navExpanded ??
        this.navExpanded,
    navWidth:
        navWidth ??
        this.navWidth,
    outputExpanded:
        outputExpanded ??
        this.outputExpanded,
    outputWidth:
        outputWidth ??
        this.outputWidth,
    activeArtifact: clearArtifact
        ? null
        : (activeArtifact ??
              this.activeArtifact),
  );
}

class LayoutController
    extends
        Notifier<
          LayoutState
        > {
  @override
  LayoutState build() => const LayoutState();

  void toggleNav() => state = state.copyWith(
    navExpanded: !state.navExpanded,
  );
  void
  setNavWidth(
    double w,
  ) => state = state.copyWith(
    navWidth: w,
  );

  void toggleOutput() => state = state.copyWith(
    outputExpanded: !state.outputExpanded,
  );
  void
  setOutputWidth(
    double w,
  ) => state = state.copyWith(
    outputWidth: w,
  );

  /// 显示产物到右侧面板。
  void showArtifact(
    ChatArtifact artifact,
  ) {
    state = state.copyWith(
      activeArtifact: artifact,
      outputExpanded: true,
    );
  }

  /// 关闭右侧面板。
  void closeOutput() {
    state = state.copyWith(
      outputExpanded: false,
      clearArtifact: true,
    );
  }
}

final layoutControllerProvider =
    NotifierProvider<
      LayoutController,
      LayoutState
    >(
      LayoutController.new,
    );
