import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/data/repositories/settings_repository.dart';
import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/features/studio/application/settings_repository_provider.dart';

/// 输入框上那几个 sgcode 引擎设置（审批策略 / 沙箱档位 / 推理强度 /
/// 联网搜索 / 记忆）的读写。
///
/// ## 为什么走 [SettingsRepository] 而不是 `GatewayRepository`
///
/// 这是「先接本地」的落点。`SettingsRepository` 桌面端是
/// `dart:ffi → sgit_studio_read / sgit_settings_set_tool`，**直读直写本机
/// `config.toml`，完全不碰 gateway**；Web 端才回落 HTTP。用 `GatewayRepository`
/// 会把桌面也拖上网络：断网就读不出自己的本地配置，而那份配置本来就在硬盘上。
///
/// ## 五个值一次读回
///
/// 全部来自 `readPage('tools')` 一次调用 —— 它们都是 `config.toml` 的键，
/// 拆成五次读只会多五次 FFI 往返和五个各自会失败的分支。
///
/// ## 写是乐观更新
///
/// 先把界面翻过去，失败再翻回来。写要过一次（桌面是"先服务器后本地"）网络，
/// 等它返回再动控件，手感像卡住了。照抄 `ToolsController.toggle` 的做法。
@immutable
class ComposerSettingsState {
  const ComposerSettingsState({
    this.settings = const ComposerSettings(),
    this.loading = true,
    this.error,
  });

  final ComposerSettings settings;
  final bool loading;

  /// 上一次写失败的原因。**不常驻** —— 由调用方弹一次提示后调 [clearError]。
  final String? error;

  ComposerSettingsState copyWith({
    ComposerSettings? settings,
    bool? loading,
    String? error,
    bool clearError = false,
  }) =>
      ComposerSettingsState(
        settings: settings ?? this.settings,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
      );
}

class ComposerSettingsController extends Notifier<ComposerSettingsState> {
  static const _page = 'tools';

  late final SettingsRepository _settings =
      ref.read(settingsRepositoryProvider);

  @override
  ComposerSettingsState build() {
    Future.microtask(load);
    return const ComposerSettingsState();
  }

  /// SWR：先本地秒回，再后台刷新。与 studio 各页同一条路。
  Future<void> load() async {
    try {
      state = ComposerSettingsState(
        settings: ComposerSettings.fromToolsPage(
          await _settings.readPage(_page),
          keep: state.settings,
        ),
        loading: false,
      );
    } catch (e) {
      // 读不出配置**不该挡住对话** —— 退回默认档继续用，引擎侧自己也有默认值。
      debugPrint('[composer] 读引擎设置失败，用默认档：$e');
      state = const ComposerSettingsState(loading: false);
      return;
    }

    final out = await _settings.refreshPage(_page);
    if (!out.ok || !out.changed) return;
    try {
      state = state.copyWith(
        settings: ComposerSettings.fromToolsPage(
          await _settings.readPage(_page),
          keep: state.settings,
        ),
      );
    } catch (_) {
      // 重读失败留着第一次的数据，不退化成错误态。
    }
  }

  Future<void> setApprovalPolicy(ApprovalPolicy next) => _write(
        state.settings.copyWith(approvalPolicy: next),
        ComposerSettings.approvalPolicyKey,
        next.toWire(),
      );

  Future<void> setSandboxMode(SandboxMode next) => _write(
        state.settings.copyWith(sandboxMode: next),
        ComposerSettings.sandboxModeKey,
        next.wire,
      );

  Future<void> setReasoningEffort(ReasoningEffort next) => _write(
        state.settings.copyWith(reasoningEffort: next),
        ComposerSettings.reasoningEffortKey,
        next.wire,
      );

  Future<void> toggleWebSearch() {
    final next = state.settings.webSearch.toggled();
    return _write(
      state.settings.copyWith(webSearch: next),
      ComposerSettings.webSearchKey,
      // toggled() 一定给出非空档位，`!` 在这里是安全的。
      next.raw!,
    );
  }

  Future<void> setMemoryEnabled(bool next) => _write(
        state.settings.copyWith(memoryEnabled: next),
        ComposerSettings.memoryEnabledKey,
        next,
      );

  /// 切换引擎模式（本地 / 云端）。
  /// ⚠️ 这不是 config.toml 的键，不需要落盘，只改内存状态。
  void setEngineMode(EngineMode next) {
    state = state.copyWith(settings: state.settings.copyWith(engineMode: next));
  }

  /// 选模型。`null` = 选回"默认模型"（用列表第一个）。
  ///
  /// ⚠️ 放在 provider 里而不是 `ChatComposer` 的 State：空态与会话态是**两棵
  /// 不同的子树**，发第一条消息时 widget 会销毁重建 —— 私有字段活不过那一下，
  /// 表现就是"L1 选好的模型，进 L2 变回默认"。
  void setSelectedModel(String? id) {
    state = state.copyWith(
      settings: id == null
          ? state.settings.copyWith(clearSelectedModel: true)
          : state.settings.copyWith(selectedModel: id),
    );
  }

  void clearError() => state = state.copyWith(clearError: true);

  /// 乐观写：先翻界面 → 落盘 → 以落盘后的实际内容重算；失败则回滚并报错。
  Future<void> _write(
    ComposerSettings optimistic,
    String keyPath,
    Object value,
  ) async {
    final prev = state.settings;
    state = state.copyWith(settings: optimistic, clearError: true);

    try {
      await _settings.setToolConfig(keyPath, value);
      // 别让界面停在乐观值上 —— 以真正落盘的内容为准再读一次。
      state = state.copyWith(
        settings: ComposerSettings.fromToolsPage(
          await _settings.readPage(_page),
          keep: state.settings,
        ),
      );
    } catch (e) {
      state = state.copyWith(settings: prev, error: _msg(e));
    }
  }
}

final composerSettingsProvider =
    NotifierProvider<ComposerSettingsController, ComposerSettingsState>(
  ComposerSettingsController.new,
);

String _msg(Object e) =>
    e.toString().replaceFirst(RegExp(r'^\w*Exception:\s*'), '');
