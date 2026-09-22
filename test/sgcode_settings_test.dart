import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/domain/models/chat/sgcode_settings.dart';
import 'package:sgit_studio_flutter/domain/models/studio/tool_catalog.dart';

/// 钉住输入框设置的**线上取值**与 sgcode 引擎一字不差。
///
/// 为什么值得单独一份测试：这些值最终落进 `~/.sgitai/config.toml`，而
/// **写一个引擎不认识的键/值不会报错** —— config 写入不校验未知键。
/// 拼错一个字符的表现是"开关拨了、界面变了、引擎行为一点没变"，
/// 没有任何报错指向真正的原因。
///
/// 真源（`D:/Projects/sgit-code/sgcode-rs`）：
/// - `protocol/src/protocol.rs`      的 `AskForApproval`
/// - `protocol/src/config_types.rs`  的 `SandboxMode`
/// - `protocol/src/sgai_models.rs`   的 `ReasoningEffort`
/// - `config/src/config_toml.rs`     的键名
void main() {
  group('审批策略的线值与引擎 AskForApproval 一致', () {
    test('三个字符串档', () {
      expect(const UntrustedApproval().toWire(), 'untrusted');
      expect(const OnRequestApproval().toWire(), 'on-request');
      expect(const NeverApproval().toWire(), 'never');
    });

    test('granular 档是一张表，5 个子键用 snake_case', () {
      const policy = GranularApproval(GranularApprovalConfig());
      expect(policy.toWire(), {
        'granular': {
          'sandbox_approval': true,
          'rules': true,
          'skill_approval': true,
          'request_permissions': true,
          'mcp_elicitations': true,
        },
      });
    });

    test('往返：写出去再读回来是同一档', () {
      const cases = <ApprovalPolicy>[
        UntrustedApproval(),
        OnRequestApproval(),
        NeverApproval(),
      ];
      for (final p in cases) {
        expect(
          ApprovalPolicy.fromWire(p.toWire()).runtimeType,
          p.runtimeType,
          reason: '${p.runtimeType} 往返后变了型',
        );
      }
    });

    test('granular 往返保住每个子开关', () {
      const config = GranularApprovalConfig(
        sandboxApproval: false,
        rules: true,
        skillApproval: false,
        requestPermissions: true,
        mcpElicitations: false,
      );
      final back = ApprovalPolicy.fromWire(
        const GranularApproval(config).toWire(),
      );
      expect(back, isA<GranularApproval>());
      final got = (back as GranularApproval).config;
      for (final f in GranularApprovalConfig.fields) {
        expect(got.valueOf(f), config.valueOf(f), reason: '${f.wire} 没对上');
      }
    });

    test('老配置里的 on-failure 别名读成 on-request', () {
      // 引擎侧 `#[serde(alias = "on-failure")]` —— 早期配置文件里是这个值。
      expect(
        ApprovalPolicy.fromWire('on-failure'),
        isA<OnRequestApproval>(),
      );
    });

    test('认不出来的值回默认档，而不是崩', () {
      // 引擎加新档位时，老客户端应当显示成默认值继续能用。
      expect(ApprovalPolicy.fromWire('brand-new-mode'), isA<OnRequestApproval>());
      expect(ApprovalPolicy.fromWire(null), isA<OnRequestApproval>());
    });
  });

  group('沙箱档位的线值与引擎 SandboxMode 一致', () {
    test('三档都是 kebab-case', () {
      expect(SandboxMode.readOnly.wire, 'read-only');
      expect(SandboxMode.workspaceWrite.wire, 'workspace-write');
      expect(SandboxMode.dangerFullAccess.wire, 'danger-full-access');
    });

    test('往返 + 未知值回默认（引擎默认是只读）', () {
      for (final m in SandboxMode.values) {
        expect(SandboxMode.fromWire(m.wire), m);
      }
      expect(SandboxMode.fromWire('nope'), SandboxMode.readOnly);
      expect(SandboxMode.defaults, SandboxMode.readOnly);
    });
  });

  group('推理强度的线值与引擎 ReasoningEffort 一致', () {
    test('八档全对上', () {
      expect(
        ReasoningEffort.values.map((e) => e.wire).toList(),
        ['none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max', 'ultra'],
      );
    });

    test('往返 + 未知值回默认（引擎默认是 medium）', () {
      for (final e in ReasoningEffort.values) {
        expect(ReasoningEffort.fromWire(e.wire), e);
      }
      // 引擎的 `Custom(String)` 变体：我们不建对应档，显示成默认即可。
      expect(ReasoningEffort.fromWire('some-custom'), ReasoningEffort.medium);
    });
  });

  group('config.toml 键名', () {
    test('与 ConfigToml 的字段名一字不差', () {
      expect(ComposerSettings.approvalPolicyKey, 'approval_policy');
      expect(ComposerSettings.sandboxModeKey, 'sandbox_mode');
      expect(ComposerSettings.reasoningEffortKey, 'model_reasoning_effort');
      expect(ComposerSettings.webSearchKey, 'web_search');
    });

    test('记忆开关是 use_memories，不是 enabled', () {
      // ⚠️ `MemoriesToml`（config/src/types.rs）里**没有 enabled 这个键**。
      // 按 enabled 写会静默不生效 —— 这条断言就是为了不让人"顺手改回去"。
      expect(ComposerSettings.memoryEnabledKey, 'memories.use_memories');
    });
  });

  group('解析 tools 页', () {
    test('空表 = 全部默认档', () {
      const s = ComposerSettings();
      final parsed = ComposerSettings.fromToolsPage(const {});
      expect(parsed.approvalPolicy, isA<OnRequestApproval>());
      expect(parsed.sandboxMode, s.sandboxMode);
      expect(parsed.reasoningEffort, s.reasoningEffort);
      expect(parsed.memoryEnabled, isTrue, reason: '键缺失应视为引擎默认开');
      expect(
        parsed.webSearch.enabled,
        isTrue,
        reason: '键缺失 = 跟随引擎默认档 Cached = 开（与 memoryEnabled 同理）',
      );
    });

    test('读出 Rust 两侧同形返回的六个字段', () {
      final parsed = ComposerSettings.fromToolsPage(const {
        'approvalPolicy': 'never',
        'features': <String, Object?>{},
        'memoryEnabled': false,
        'reasoningEffort': 'high',
        'requestUserInput': null,
        'sandboxMode': 'workspace-write',
        // 用引擎真实存在的档位。`'enabled'` 那个值根本不在 WebSearchMode 里
        // （只有 disabled / cached / indexed / live），拿它当样例会误导下一个人。
        'webSearch': 'cached',
      });
      expect(parsed.approvalPolicy, isA<NeverApproval>());
      expect(parsed.sandboxMode, SandboxMode.workspaceWrite);
      expect(parsed.reasoningEffort, ReasoningEffort.high);
      expect(parsed.memoryEnabled, isFalse);
      expect(parsed.webSearch.enabled, isTrue);
    });

    test('granular 档从表里读回来（不能被当成 null）', () {
      // 早前若用 `as_str()` 读 approval_policy，granular 会整个读成 null，
      // 用户精心配的细粒度档位显示成"默认"。Rust 侧改用整值转 JSON，这里守住。
      final parsed = ComposerSettings.fromToolsPage(const {
        'approvalPolicy': {
          'granular': {'sandbox_approval': false, 'rules': true},
        },
      });
      expect(parsed.approvalPolicy, isA<GranularApproval>());
      expect(
        (parsed.approvalPolicy as GranularApproval).config.sandboxApproval,
        isFalse,
      );
    });
  });

  group('联网搜索开关', () {
    // ⚠️ 这条原先断言「缺键 = 关」。改了 —— 引擎 WebSearchMode 的
    // `#[default]` 是 Cached，没配置这个键就是跟随默认档，也就是**开着**。
    //
    // 之所以之前是错的也没人发现：那时这个开关整个是空转的（工具压根没下发，
    // 见 `ext/web-search` 那次改造），开还是关都没有可观察的后果。
    test('缺键 = 开（引擎默认 Cached）；只有显式 disabled 才算关', () {
      expect(
        const WebSearchSetting(null).enabled,
        isTrue,
        reason: '键缺失 = 跟随引擎默认档 Cached = 开',
      );
      expect(const WebSearchSetting('disabled').enabled, isFalse);
      // 用户在 CLI 里设的其它档位也算"开着"，不该被界面读成关。
      expect(const WebSearchSetting('cached').enabled, isTrue);
      expect(const WebSearchSetting('indexed').enabled, isTrue);
      expect(const WebSearchSetting('live').enabled, isTrue);
    });

    test('与 tool_catalog 的 toolEnabled 判断一致', () {
      // ⚠️ 同一个 `web_search` 键有两处判断（输入框开关走
      // WebSearchSetting.enabled，智能体工具面板走 toolEnabled）。
      // 两处相反的话会直接表现成「面板显示开、输入框显示关」——
      // 之前确实相反过，这条把它们绑在一起。
      const webSearchTool = ToolDef(
        id: 'web_search',
        label: '联网搜索',
        desc: '',
        kind: ToolKind.webSearch,
      );
      for (final raw in [null, 'disabled', 'cached', 'indexed', 'live']) {
        expect(
          WebSearchSetting(raw).enabled,
          toolEnabled(webSearchTool, features: const {}, webSearch: raw),
          reason: 'raw=$raw 时两处判断应相同',
        );
      }
    });

    // ⚠️ 「开」必须写回引擎**真实存在**的档位。
    //
    // 这条原先断言写回 `'enabled'` —— 而引擎的 WebSearchMode 只有
    // disabled / cached / indexed / live。于是测试把 bug 一起钉住了：
    // 用户点一下开关，config.toml 就被写成 `web_search = "enabled"`，
    // 本地引擎从此解析失败起不来，而报错完全看不出跟开关有关。实测有人中招。
    test('切换在两端之间来回，开写回引擎真实档位', () {
      // 缺键时是"开着"，所以切换后应该去 disabled。
      expect(const WebSearchSetting(null).toggled().raw, 'disabled');
      expect(const WebSearchSetting('cached').toggled().raw, 'disabled');
      expect(const WebSearchSetting('disabled').toggled().raw, 'cached');
    });

    /// 钉死取值范围本身 —— 光测"切换结果等于某字符串"挡不住有人把它改成
    /// 另一个同样不存在的值。
    test('enabledWire 必须是引擎 WebSearchMode 里的档位', () {
      const engineModes = {'disabled', 'cached', 'indexed', 'live'};
      expect(engineModes, contains(WebSearchSetting.enabledWire));
      expect(engineModes, contains(WebSearchSetting.disabledWire));
    });
  });
}
