import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'workspace_metrics.dart';

/// 工作台外壳状态：左右栏的展开与宽度（对应 studio 的 global store
/// `showLeftPanel` / `leftPanelWidth` / 右栏 expand）。
@immutable
class WorkspaceState {
  const WorkspaceState({
    this.navExpanded = true,
    this.navWidth = WorkspaceMetrics.navDefaultWidth,
    this.outputExpanded = true,
    this.outputWidth = WorkspaceMetrics.outputDefaultWidth,
  });

  final bool navExpanded;
  final double navWidth;
  final bool outputExpanded;
  final double outputWidth;

  WorkspaceState copyWith({
    bool? navExpanded,
    double? navWidth,
    bool? outputExpanded,
    double? outputWidth,
  }) =>
      WorkspaceState(
        navExpanded: navExpanded ?? this.navExpanded,
        navWidth: navWidth ?? this.navWidth,
        outputExpanded: outputExpanded ?? this.outputExpanded,
        outputWidth: outputWidth ?? this.outputWidth,
      );
}

class WorkspaceController extends Notifier<WorkspaceState> {
  @override
  WorkspaceState build() => const WorkspaceState();

  void toggleNav() => state = state.copyWith(navExpanded: !state.navExpanded);
  void setNavWidth(double w) => state = state.copyWith(navWidth: w);

  void toggleOutput() =>
      state = state.copyWith(outputExpanded: !state.outputExpanded);
  void setOutputWidth(double w) => state = state.copyWith(outputWidth: w);
}

final workspaceControllerProvider =
    NotifierProvider<WorkspaceController, WorkspaceState>(
        WorkspaceController.new);
