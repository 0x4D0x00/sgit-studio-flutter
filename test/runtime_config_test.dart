import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/core/config/runtime_config.dart';

/// 后端地址解析的回归。
///
/// ## 这组测试为什么存在
///
/// Dart 侧原本读 `SGIT_API_BASE`，而 sgcode Rust 侧（`ApiConfig`）读的是
/// **`SGIT_API_BASE_URL`** —— 两个不同的名字。于是用
/// `SGIT_API_BASE_URL=... flutter run` 启动时：
///
/// ```text
/// Rust 侧  → 生效（登录、模型列表、relay 全都正常）
/// Dart 侧  → 始终"未配置"
/// ```
///
/// 本地引擎路不读这个地址，所以一直没暴露；一切到**云端引擎**就报
/// 「后端地址未配置」。两边各写各的变量名是根因。
void main() {
  setUp(() => RuntimeConfig.applyOverride(null));
  tearDown(() => RuntimeConfig.applyOverride(null));

  test('变量名与 sgcode Rust 侧一致', () {
    // ⚠️ 改这个名字就必须同时改 `sgit-services/src/http/routes.rs` 的
    // `env_base_url()`，否则又会退回"配了一个、另一边不认"的状态。
    expect(RuntimeConfig.envVarName, 'SGIT_API_BASE_URL');
  });

  test('applyOverride 优先级最高', () {
    RuntimeConfig.applyOverride('http://10.100.0.66:32717');
    expect(RuntimeConfig.isConfigured, isTrue);
    expect(RuntimeConfig.apiBaseUrl, 'http://10.100.0.66:32717');
  });

  test('结尾斜杠要去掉 —— 后面会拼 /sgcode-kernel/ws', () {
    RuntimeConfig.applyOverride('http://10.100.0.66:32717/');
    expect(RuntimeConfig.apiBaseUrl, 'http://10.100.0.66:32717');
  });

  test('空串/空白视同没配', () {
    RuntimeConfig.applyOverride('   ');
    // 测试进程里通常也没有那个环境变量，所以应当回到"未配置"。
    // 若本机恰好设了 SGIT_API_BASE_URL，这条会读到它 —— 那也是正确行为，
    // 所以只断言"不是那个空白串"。
    expect(RuntimeConfig.isConfigured ? RuntimeConfig.apiBaseUrl : '', isNot('   '));
  });

  // ⚠️ gateway 与后端 API **可能不是同一个入口**，这组钉住"能分开配、缺省回落"。
  //
  // 实测某内网环境：
  //   10.100.0.66:32717  Go 后端 API   有 /api/*，无 /sgcode-kernel/ws
  //   10.100.0.66:18088  studio nginx  有 /sgcode-*，但 /api/* 被 SPA 首页吃掉
  // 混用一个变量必然有一头是坏的。
  group('gateway 地址可独立于后端 API', () {
    tearDown(() => RuntimeConfig.applyGatewayOverride(null));

    test('未单独配置时回落到 apiBaseUrl（同机部署）', () {
      RuntimeConfig.applyOverride('http://10.100.0.66:32717');
      RuntimeConfig.applyGatewayOverride(null);
      expect(RuntimeConfig.gatewayBaseUrl, 'http://10.100.0.66:32717');
    });

    test('单独配置时各走各的（分开部署）', () {
      RuntimeConfig.applyOverride('http://10.100.0.66:32717');
      RuntimeConfig.applyGatewayOverride('http://10.100.0.66:18088');
      expect(RuntimeConfig.apiBaseUrl, 'http://10.100.0.66:32717',
          reason: '后端 API 该保持独立');
      expect(RuntimeConfig.gatewayBaseUrl, 'http://10.100.0.66:18088');
    });

    test('变量名与部署文档一致', () {
      expect(RuntimeConfig.gatewayEnvVarName, 'SGIT_GATEWAY_BASE_URL');
    });

    test('结尾斜杠同样要去掉', () {
      RuntimeConfig.applyGatewayOverride('http://10.100.0.66:18088/');
      expect(RuntimeConfig.gatewayBaseUrl, 'http://10.100.0.66:18088');
    });
  });

  test('未配置时报错要说清三种配法，且不回落到任何域名', () {
    RuntimeConfig.applyOverride(null);
    if (RuntimeConfig.isConfigured) {
      // 本机设了环境变量（开发机常见）——那就验它确实被用上了，而不是硬编码域名。
      expect(RuntimeConfig.apiBaseUrl, isNotEmpty);
      expect(RuntimeConfig.apiBaseUrl, isNot(contains('potagi.cn')));
      return;
    }
    expect(
      () => RuntimeConfig.apiBaseUrl,
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('SGIT_API_BASE_URL'),
            contains('--dart-define'),
            contains('runtime.json'),
          ),
        ),
      ),
    );
  });
}
