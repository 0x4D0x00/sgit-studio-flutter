import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/domain/models/studio/tool_catalog.dart';

import 'fakes/fake_settings_repository.dart';

void main() {
  group('工具启用判定', () {
    // 现网 config.toml 只写了 10 个键，而目录里的开关不止 10 个。
    final features = (FakeSettingsRepository.toolsSnapshot['features']! as Map)
        .cast<String, Object?>();

    ToolDef byId(String id) => toolCatalog
        .expand((c) => c.tools)
        .firstWhere((t) => t.id == id, orElse: () => throw '目录里没有 $id');

    test('配置里没写 ≠ 关闭 —— 走引擎默认', () {
      // 现网 config.toml 的 [features] 只写了一部分键。没写的那些并非关闭，
      // 而是走引擎默认（`features/src/lib.rs` 的 FEATURES 表）。
      // 拿"键不存在就当 false"渲染，界面会把开着的工具显示成关的。
      for (final t in toolCatalog.expand((c) => c.tools)) {
        if (t.kind != ToolKind.feature) continue;
        expect(
          toolEnabled(t, features: const {}), // 空配置 = 什么都没写
          t.defaultOn ?? false,
          reason: '${t.id}（键 ${t.featureKey}）在空配置下应取引擎默认 '
              '${t.defaultOn}，而不是一律 false',
        );
      }

      // 目录里至少要有一个"默认开"的，否则上面那条永远恒真、测不出东西。
      expect(
        toolCatalog
            .expand((c) => c.tools)
            .any((t) => t.kind == ToolKind.feature && t.defaultOn == true),
        isTrue,
        reason: '没有任何"默认开"的 feature 工具，这条回归就失去意义了',
      );
    });

    test('webSearch / requestUserInput 未配置时默认是开的', () {
      expect(toolEnabled(byId('web_search'), features: features), isTrue);
      expect(toolEnabled(byId('AskUserQuestion'), features: features), isTrue);

      // 只有显式 disabled 才算关。
      expect(
        toolEnabled(byId('web_search'),
            features: features, webSearch: 'disabled'),
        isFalse,
      );
      expect(
        toolEnabled(byId('web_search'), features: features, webSearch: 'cached'),
        isTrue,
      );
      expect(
        toolEnabled(byId('AskUserQuestion'),
            features: features, requestUserInput: false),
        isFalse,
      );
    });

    test('核心工具恒为开，且没有写入路径（关不掉）', () {
      final cores =
          toolCatalog.expand((c) => c.tools).where((t) => t.kind == ToolKind.core);
      expect(cores, isNotEmpty);
      for (final t in cores) {
        expect(toolEnabled(t, features: const {}), isTrue, reason: t.id);
        expect(toolWritePath(t, false), isNull,
            reason: '${t.id} 是核心工具，不该有可写的开关');
      }
    });

    test('配置里写了就按配置来', () {
      // 快照里 code_mode=true、memories=true。
      expect(toolEnabled(byId('exec / wait'), features: features), isTrue);
      expect(
        toolEnabled(byId('exec / wait'), features: const {'code_mode': false}),
        isFalse,
      );
    });
  });

  group('工具写入路径', () {
    test('三类开关落在三个不同的键上', () {
      ToolDef byId(String id) =>
          toolCatalog.expand((c) => c.tools).firstWhere((t) => t.id == id);

      // feature：键名与工具 id 不同 —— 这正是不能拿 id 当键的原因。
      final fanout = byId('spawn_agents_on_csv');
      expect(fanout.featureKey, 'enable_fanout');
      expect(toolWritePath(fanout, true), ('features.enable_fanout', true));

      // webSearch：值是字符串不是 bool。
      expect(toolWritePath(byId('web_search'), false),
          ('web_search', 'disabled'));
      expect(
          toolWritePath(byId('web_search'), true), ('web_search', 'cached'));

      // requestUserInput：三层嵌套路径。
      expect(
        toolWritePath(byId('AskUserQuestion'), true),
        ('tools.experimental_request_user_input.enabled', true),
      );
    });

    test('每个 feature 类工具都有 featureKey —— 漏了会写成 features.null', () {
      for (final t in toolCatalog.expand((c) => c.tools)) {
        if (t.kind == ToolKind.feature) {
          expect(t.featureKey, isNotNull, reason: t.id);
          expect(t.featureKey, isNotEmpty, reason: t.id);
        }
      }
    });
  });

  group('目录内容', () {
    test('收录了引擎首轮直接可见的那批核心工具', () {
      final ids = toolCatalog.expand((c) => c.tools).map((t) => t.id).toSet();
      // 对照 core/src/tools/spec_plan.rs 的 CORE_BUILTIN_TOOLS 白名单。
      for (final want in [
        'Read', 'Edit', 'Write', 'Grep', 'Glob', 'Bash', 'TodoWrite',
        'render_svg', 'render_mermaid', 'tool_search',
      ]) {
        expect(ids, contains(want), reason: '$want 是引擎白名单里的工具，必须列出来');
      }
    });

    test('不含本 fork 已摘掉的工具', () {
      final ids = toolCatalog.expand((c) => c.tools).map((t) => t.id).toSet();
      // React studio 的 CATALOG 还列着这些，但本 fork 不再暴露给模型
      // （spec_plan.rs:845 文件改动统一走 Edit/Write；:737 只暴露 Bash）。
      // 照抄那份目录会让用户看到根本不存在的工具。
      for (final gone in ['apply_patch', 'exec_command', 'update_plan']) {
        expect(ids, isNot(contains(gone)),
            reason: '$gone 在本 fork 已不暴露给模型，不该出现在工具页');
      }
    });

    test('工具 id 不重复 —— 乐观更新按 id 定位，重复会一起翻', () {
      final ids = toolCatalog.expand((c) => c.tools).map((t) => t.id).toList();
      expect(ids.length, ids.toSet().length);
    });
  });
}
