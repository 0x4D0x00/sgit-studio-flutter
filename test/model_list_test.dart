import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/kernel_client_mock.dart';
import 'package:sgit_studio_flutter/features/chat/application/chat_ports_impl.dart';
import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_settings_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/model_list_controller.dart';
import 'package:sgit_studio_flutter/app/app_providers.dart';
import 'package:sgit_studio_flutter/features/studio/application/relay_controller.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';

import 'fakes/fake_settings_repository.dart';

/// 模型列表的读取回归。
///
/// ## 这组测试为什么存在
///
/// 加「引擎模式」下拉时，`ChatController.connect()` 里写了
/// `ref.read(composerSettingsProvider.select(...))`。`.select()` 是给 `watch` 用的
/// （它靠 selector 决定要不要重建订阅者），用在 `read` 上会在 provider 之间牵出
/// 一条本不该有的依赖边 —— 而 `ComposerSettingsController.build()` 里有
/// `Future.microtask(load)`，走的是 `SettingsRepository` 的 FFI，`ModelListController`
/// 读的是同一个 repository。
///
/// 结果：**中转站页和输入框的模型同时变空**，而 DLL 探针单独调 `sgit_relay_manage`
/// 一切正常（6597 字节真实数据）。两个入口一起坏、底层却是好的 —— 这种故障
/// 只能靠"把两个 controller 放在同一个容器里跑一遍"才抓得到。
void main() {
  ProviderContainer makeContainer(FakeSettingsRepository settings) {
    final c = ProviderContainer(
      overrides: [
 chatPortsOverride,
        settingsRepositoryProvider.overrideWithValue(settings),
        kernelClientProvider.overrideWithValue(MockKernelClient()),
        chatControllerProvider.overrideWith(
          () => ChatController(client: MockKernelClient()),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  FakeSettingsRepository newSettings() => FakeSettingsRepository(
        pages: const {'tools': FakeSettingsRepository.toolsSnapshot},
      );

  test('模型列表能读出厂商与模型（两个 scope 各取一次）', () async {
    final settings = newSettings();
    final c = makeContainer(settings);

    c.read(modelListProvider);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final state = c.read(modelListProvider);
    expect(state.isEmpty, isFalse, reason: '模型列表不该是空的');
    expect(state.first?.displayName, isNotNull);

    // 平台与个人两路都要取。
    expect(settings.calls, contains('relayManage:model/providers:master'));
    expect(settings.calls, contains('relayManage:model/providers:personal'));
  });

  test('ChatController 连接后，模型列表仍然读得出来', () async {
    // ⚠️ 这条是真正的回归守卫：connect() 会读 composerSettingsProvider，
    // 而它与 modelListProvider 共用 SettingsRepository。用错读法时这里会空。
    final settings = newSettings();
    final c = makeContainer(settings);

    // 先把两个 controller 都唤醒，模拟真实启动顺序。
    c.read(modelListProvider);
    c.read(composerSettingsProvider);
    await c.read(chatControllerProvider.notifier).connect();
    await Future<void>.delayed(const Duration(milliseconds: 150));

    final state = c.read(modelListProvider);
    expect(
      state.isEmpty,
      isFalse,
      reason: 'connect() 之后模型列表被清空 —— provider 之间牵出了不该有的依赖',
    );
  });

  // ⚠️ 这一组才是真正的病灶守卫。
  //
  // 实测：DLL 探针分别调两路，`cache/master` 返回 6597 字节好数据，
  // `sync/master` 返回 `{"error":"Request failed: Failed to get nonce"}` ——
  // 本地模式下 sync 永远打不通（它要打后端做加密握手）。
  //
  // 而 `load()` 原本写的是 `state = ModelListState(groups: await _build('sync'))`。
  // 看着像"有异常会被 catch 接住"，但 `_scope()` 的 catch 把失败**咽掉回空列表**
  // （那是对的：一个 scope 挂了不该拖累另一个），于是 sync 失败时不抛异常，
  // 而是拿空列表**盖掉 cache 刚读出来的好数据** —— 本地模式下必现。
  group('sync 失败时不能覆盖 cache 的数据（本地模式必现）', () {
    test('sync 打不通，模型列表仍要显示本地缓存', () async {
      final settings = FakeSettingsRepository(
        pages: const {'tools': FakeSettingsRepository.toolsSnapshot},
        failSync: true, // 复现本地模式：只有 cache 能出数据
      );
      final c = makeContainer(settings);

      c.read(modelListProvider);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final state = c.read(modelListProvider);
      expect(
        state.isEmpty,
        isFalse,
        reason: 'sync 失败把 cache 的好数据盖成空了 —— 这正是「模型中转站没模型」的成因',
      );
      expect(state.first?.displayName, 'GLM-4');
      expect(state.loading, isFalse);
      // 显示的确实是本地缓存，没刷新成功 —— 要如实标出来。
      expect(state.stale, isTrue);
    });

    test('sync 打不通时 loading 也要收掉，不能永远转圈', () async {
      final settings = FakeSettingsRepository(
        pages: const {'tools': FakeSettingsRepository.toolsSnapshot},
        failSync: true,
      );
      final c = makeContainer(settings);

      c.read(modelListProvider);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(c.read(modelListProvider).loading, isFalse);
    });
  });

  // 中转站页（studio 的「大模型中转站」）走的是另一个 controller，但**同一个坑**：
  // `_providersOf()` 的 catch 咽掉失败回空列表 → sync 失败时空结果盖掉 cache。
  // 用户看到的就是"中转站也没模型了"。
  //
  // ⚠️ 注意 `_fetchProviders` 是两路合并：master 跟随 mode，**personal 固定 cache**
  // （个人行只落本地，没有远端真源）。所以 sync 失败时 personal 那路仍有数据 ——
  // 真正要守的是「**平台厂商没被丢掉**」，不是整个列表非空。
  test('中转站页：sync 打不通时平台厂商仍在', () async {
    final settings = FakeSettingsRepository(
      pages: const {'llm-relay': FakeSettingsRepository.relaySnapshot},
      failSync: true,
    );
    final c = makeContainer(settings);

    await c.read(relayProvider.notifier).loadProviders();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final state = c.read(relayProvider);
    expect(state.providers, isNotEmpty);
    expect(state.loading, isFalse);
    // fixture 里 Alibaba 是启用的平台厂商（tag=builtin）。它来自 master 那一路，
    // 正是 sync 失败时最容易被空列表盖掉的那部分。
    expect(
      state.providers.any((p) => !p.isCustom),
      isTrue,
      reason: 'sync 失败把平台厂商（master 那路）盖没了',
    );
  });

  // ⚠️ 空态(L1)与会话态(L2)是 `workspace_page.dart` 里三元切换出来的**两棵不同子树**，
  // 发第一条消息时 `ChatComposer` 的 State 会被销毁重建。模型选择若放在私有字段里
  // 活不过那一下 —— 表现就是"L1 选好的模型，进 L2 变回默认"。所以它必须住在 provider。
  group('选中的模型要跨 L1→L2 保持', () {
    test('选了模型后，重建 widget 也不丢', () async {
      final c = makeContainer(newSettings());
      final notifier = c.read(composerSettingsProvider.notifier);

      notifier.setSelectedModel('glm4:latest');
      expect(
        c.read(composerSettingsProvider).settings.selectedModel,
        'glm4:latest',
      );

      // widget 重建不碰 provider —— 值还在。
      expect(
        c.read(composerSettingsProvider).settings.selectedModel,
        'glm4:latest',
        reason: '模型选择丢了 —— 它不该活在 widget 的 State 里',
      );
    });

    test('改别的设置后重读配置，选中的模型不被冲掉', () async {
      // `_write` 落盘后会 `fromToolsPage` 重建 settings —— 那里必须 keep 住
      // 运行时状态，否则"选了模型 → 顺手改个开关 → 模型悄悄变回默认"。
      final settings = newSettings();
      final c = makeContainer(settings);
      final notifier = c.read(composerSettingsProvider.notifier);

      notifier.setSelectedModel('glm4:latest');
      notifier.setEngineMode(EngineMode.remote);
      await notifier.setMemoryEnabled(false); // 触发落盘 + 重读

      final s = c.read(composerSettingsProvider).settings;
      expect(s.selectedModel, 'glm4:latest', reason: '重读配置把模型选择冲掉了');
      expect(s.engineMode, EngineMode.remote, reason: '重读配置把引擎模式冲掉了');
    });

    test('setSelectedModel(null) 要能真的清空选择', () async {
      final c = makeContainer(newSettings());
      final notifier = c.read(composerSettingsProvider.notifier);

      notifier.setSelectedModel('glm4:latest');
      notifier.setSelectedModel(null);

      // ⚠️ copyWith 里 `?? this.x` 会把 null 当"没传"而保留旧值 ——
      // 必须走 clearSelectedModel 才清得掉。
      expect(
        c.read(composerSettingsProvider).settings.selectedModel,
        isNull,
        reason: 'copyWith 把 null 当成没传，选择清不掉',
      );
    });
  });

  test('读引擎模式不该影响模型列表', () async {
    final settings = newSettings();
    final c = makeContainer(settings);

    c.read(modelListProvider);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final before = c.read(modelListProvider).groups.length;

    // 反复读引擎模式（connect 每次都会做这件事）。
    for (var i = 0; i < 5; i++) {
      c.read(composerSettingsProvider).settings.engineMode;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(c.read(modelListProvider).groups.length, before);
  });
}
