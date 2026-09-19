import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/settings_repository.dart';
import 'package:sgit_studio_flutter/domain/models/studio/tool_catalog.dart';
import 'package:sgit_studio_flutter/features/studio/application/settings_repository_provider.dart';

/// 目录里的一项 + 它当前的启用状态。
@immutable
class ToolRow {
  const ToolRow({required this.def, required this.enabled});

  final ToolDef def;
  final bool enabled;
}

@immutable
class ToolGroup {
  const ToolGroup({required this.name, required this.rows});

  final String name;
  final List<ToolRow> rows;
}

@immutable
class ToolsState {
  const ToolsState({
    this.groups = const [],
    this.loading = true,
    this.stale = false,
    this.error,
    this.busyId,
  });

  final List<ToolGroup> groups;
  final bool loading;
  final bool stale;
  final String? error;

  /// 正在提交的那个工具 id（开关转圈用）。
  final String? busyId;

  int get total => groups.fold(0, (n, g) => n + g.rows.length);

  ToolsState copyWith({
    List<ToolGroup>? groups,
    bool? loading,
    bool? stale,
    String? error,
    bool clearError = false,
    String? busyId,
    bool clearBusy = false,
  }) =>
      ToolsState(
        groups: groups ?? this.groups,
        loading: loading ?? this.loading,
        stale: stale ?? this.stale,
        error: clearError ? null : (error ?? this.error),
        busyId: clearBusy ? null : (busyId ?? this.busyId),
      );
}

/// 工具页控制器 —— 展示 sgcode 引擎的**内置工具**，按类别分组。
///
/// ## 数据从哪来
///
/// 清单来自 [toolCatalog]（对着引擎的 `spec_plan.rs` 写死），**启用状态**来自
/// `config.toml` 的三处开关。两者合成一行行 [ToolRow]。
///
/// 为什么不是把 `[features]` 摊平：见 [toolCatalog] 的注释 —— 那是引擎能力
/// 开关，不是工具清单，多数核心工具压根没有对应键。
///
/// ## 写：先服务器后本地
///
/// 改开关走 `sgit_studio_set_tool`，Rust 那边复用 settings 的 config 类别
/// （先服务器、后本地、失败入脏队列）。只写本地不行 —— 工具页刷新会拉服务器的
/// config.toml 按段合并，`[features]` 是服务器赢的段，本地改完下次进页面就弹回去。
class ToolsController extends Notifier<ToolsState> {
  late final SettingsRepository _settings =
      ref.read(settingsRepositoryProvider);

  /// 最近一次读到的原始配置，供乐观更新后重算用。
  Map<String, Object?> _raw = const {};

  @override
  ToolsState build() {
    Future.microtask(reload);
    return const ToolsState();
  }

  /// SWR：先本地秒回，再后台打 Go 刷新。与其余各页同一条路。
  Future<void> reload({bool force = false}) async {
    state = state.copyWith(loading: true, clearError: true);

    try {
      _raw = await _settings.readPage('tools');
      state = ToolsState(groups: _build(_raw));
    } catch (e) {
      state = state.copyWith(loading: false, error: _msg(e));
      return;
    }

    final out = await _settings.refreshPage('tools', force: force);
    if (!out.ok || !out.changed) return;
    try {
      _raw = await _settings.readPage('tools');
      state = state.copyWith(groups: _build(_raw));
    } catch (_) {
      // 重读失败留着第一次的数据，不退化成错误态。
    }
  }

  /// 切换一个工具。核心工具没有开关，调用方不会走到这里。
  ///
  /// **乐观更新**：先把界面翻过去，失败再翻回来并报错 —— 写要过一次网络，
  /// 等它返回再动开关，手感像卡住了。
  Future<void> toggle(ToolDef def, bool next) async {
    final write = toolWritePath(def, next);
    if (write == null) return; // core，关不掉

    state = state.copyWith(
        groups: _patch(def.id, next), busyId: def.id, clearError: true);

    try {
      await _settings.setToolConfig(write.$1, write.$2);
      // 以服务器/本地落盘后的实际内容为准重算一次 —— 别让界面停在乐观值上。
      _raw = await _settings.readPage('tools');
      state = state.copyWith(groups: _build(_raw), clearBusy: true);
    } catch (e) {
      state = state.copyWith(
        groups: _patch(def.id, !next), // 回滚
        clearBusy: true,
        error: _msg(e),
      );
    }
  }

  /// 目录 + 当前配置 → 分组行。
  List<ToolGroup> _build(Map<String, Object?> data) {
    final features = switch (data['features']) {
      final Map m => m.cast<String, Object?>(),
      _ => const <String, Object?>{},
    };
    final webSearch = data['webSearch'] as String?;
    final requestUserInput = data['requestUserInput'] as bool?;

    return [
      for (final cat in toolCatalog)
        ToolGroup(
          name: cat.name,
          rows: [
            for (final t in cat.tools)
              ToolRow(
                def: t,
                enabled: toolEnabled(
                  t,
                  features: features,
                  webSearch: webSearch,
                  requestUserInput: requestUserInput,
                ),
              ),
          ],
        ),
    ];
  }

  /// 就地改一行的 enabled（乐观更新与回滚共用）。
  List<ToolGroup> _patch(String id, bool enabled) => [
        for (final g in state.groups)
          ToolGroup(
            name: g.name,
            rows: [
              for (final r in g.rows)
                if (r.def.id == id)
                  ToolRow(def: r.def, enabled: enabled)
                else
                  r,
            ],
          ),
      ];
}

final toolsProvider =
    NotifierProvider<ToolsController, ToolsState>(ToolsController.new);

String _msg(Object e) =>
    e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
