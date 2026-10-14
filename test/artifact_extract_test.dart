import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';

/// 产物提取测试。
///
/// 这一组守的核心是**提取与正文渲染必须用同一套围栏识别**。改版前提取器
/// 自己扫一遍原文（按行 `startsWith('```')`），于是：
/// - `~~~` 围栏正文渲染成卡片，却提取不出产物；
/// - 段落里出现的 ``` 被正文当普通文字，却被提取器当成围栏起点；
/// - 流式期未闭合的围栏会吐出一个半截产物，卡片上的标题来自被吃掉的半句话。
///
/// 现在提取走 `MarkdownParser` 的 AST，这些行为全部由解析器统一决定。
void main() {
  /// 走真实路径：解析 → 提取。测试里不手工构造块。
  ///
  /// ⚠️ 这里**关掉行数阈值**（传 0 = 不设下限）—— 本组测试守的是「围栏识别」，
  /// 短围栏正好是最省事的最小样例。阈值行为由上面单独一组用 [extractProduction] 钉。
  List<ChatArtifact> extract(String source) => ChatArtifact.fromBlocks(
        MarkdownParser.parse(source),
        source,
        inlineLineLimit: 0,
      );

  /// 走**默认阈值** —— 生产路径。
  List<ChatArtifact> extractProduction(String source) =>
      ChatArtifact.fromBlocks(MarkdownParser.parse(source), source);

  group('行数阈值：短块不生成文件卡', () {
    /// 造一个恰好 [lines] 行非空内容的围栏。
    String fence(String lang, int lines) =>
        '```$lang\n${List.generate(lines, (i) => 'line $i').join('\n')}\n```\n';

    test('「用法」那种 12 行 bash → 不产出（留在聊天里当普通代码块）', () {
      const usage = '```bash\n'
          '# 单个目标，限速，保证凭据能打印出来\n'
          'nuclei -u https://target.example.com -t weak.yaml -rl 5 -c 1\n'
          '\n'
          '# 批量目标 + 结构化输出，便于筛选凭据\n'
          'nuclei -l targets.txt -t weak-*.yaml -jsonl -o out.jsonl -rl 5 -c 1\n'
          '```\n';
      expect(extractProduction(usage), isEmpty,
          reason: '短代码块不该变成"文件"');
    });

    test('恰好 30 行 → 还不产出；31 行 → 产出', () {
      expect(extractProduction(fence('bash', 30)), isEmpty);
      expect(extractProduction(fence('bash', 31)).length, 1);
    });

    test('空行不计入行数（格式化得稀疏的短代码仍是短代码）', () {
      // 10 行代码 + 40 行空行：按 split('\n').length 会误判成 50 行产物。
      final sparse = '```dart\n${List.generate(10, (i) => 'line $i').join('\n\n')}\n```\n';
      expect(extractProduction(sparse), isEmpty);
    });

    test('长短混杂 → 只提取长的那个', () {
      final src = '${fence('bash', 5)}\n文字\n\n${fence('dart', 45)}\n';
      final out = extractProduction(src);
      expect(out.length, 1);
      expect(out.single.language, 'dart');
    });

    test('阈值可通过参数调整（后续按语言放开时的入口）', () {
      expect(
        ChatArtifact.fromBlocks(
          MarkdownParser.parse(fence('bash', 5)),
          fence('bash', 5),
          inlineLineLimit: 3,
        ).length,
        1,
        reason: '5 行 > 阈值 3 → 产出，证明阈值真的在起作用',
      );
    });
  });

  group('围栏识别与解析器一致', () {
    test('短语段里的 ``` 不是围栏起点', () {
      // 行内代码 / 正文里提到反引号，正文不当围栏，提取也不该当。
      final artifacts = extract('用 ``` 包住代码，这一行是正文。\n');
      expect(artifacts, isEmpty);
    });

    test('~~~ 围栏同样能提取（旧实现认不出）', () {
      final artifacts = extract('~~~dart\nvar x = 1;\n~~~\n');
      expect(artifacts.length, 1);
      expect(artifacts.first.content, 'var x = 1;');
      expect(artifacts.first.language, 'dart');
    });

    test('缩进 ≤3 空格的围栏认，≥4 空格的不认', () {
      expect(extract('   ```dart\n   var x = 1;\n   ```\n').length, 1);
      expect(extract('    ```dart\n    var x = 1;\n    ```\n'), isEmpty);
    });

    test('未闭合围栏（流式期常态）→ 不抛，且不产出半截产物', () {
      // 未闭合时解析器把剩余全文当 code —— 提取得到一条，但这不崩。
      expect(() => extract('```dart\nvar x = 1;'), returnsNormally);
    });

    test('空围栏 → 不产出产物', () {
      // 空围栏在聊天里仍画一张无标题的卡，但**不能**给它配 Download：
      // 点了会落出一个空文件。
      expect(extract('```\n```\n'), isEmpty);
      expect(extract('```dart\n```\n'), isEmpty);
    });

    test('引用块里的围栏也能提取（递归）', () {
      final artifacts = extract('> ```dart\n> var x = 1;\n> ```\n');
      expect(artifacts.length, 1);
      expect(artifacts.first.content, 'var x = 1;');
    });

    test('多个围栏按出现顺序提取', () {
      final artifacts = extract(
        '```dart\nvar a = 1;\n```\n\n文字\n\n```python\nb = 2\n```\n',
      );
      expect(artifacts.length, 2);
      expect(artifacts[0].language, 'dart');
      expect(artifacts[1].language, 'python');
    });
  });

  group('类型判定', () {
    test('markdown 类语言 → document', () {
      expect(ArtifactKind.fromLanguage('md'), ArtifactKind.document);
      expect(ArtifactKind.fromLanguage('Markdown'), ArtifactKind.document);
      expect(ArtifactKind.fromLanguage(' gfm '), ArtifactKind.document);
    });

    test('图表类语言 → chart', () {
      expect(ArtifactKind.fromLanguage('mermaid'), ArtifactKind.chart);
      expect(ArtifactKind.fromLanguage('dot'), ArtifactKind.chart);
      expect(ArtifactKind.fromLanguage('plantuml'), ArtifactKind.chart);
    });

    test('数据类语言 → code（不能走 Markdown 渲染）', () {
      // ⚠️ 这条是刻意的：YAML 的 `# 注释` 会被 Markdown 渲染成标题，
      // CSV 的 `*` 会变成强调。结构化数据必须等宽显示。
      expect(ArtifactKind.fromLanguage('json'), ArtifactKind.code);
      expect(ArtifactKind.fromLanguage('yaml'), ArtifactKind.code);
      expect(ArtifactKind.fromLanguage('csv'), ArtifactKind.code);
    });

    test('未知语言与空语言 → code', () {
      expect(ArtifactKind.fromLanguage('brainfuck'), ArtifactKind.code);
      expect(ArtifactKind.fromLanguage(''), ArtifactKind.code);
    });
  });

  group('标题推断', () {
    test('首行 # 注释 → 当标题', () {
      final a = extract('```yaml\n# 部署配置\nreplicas: 2\n```\n').single;
      expect(a.title, '部署配置');
    });

    test('首行 // 注释 → 当标题', () {
      final a = extract('```js\n// 计算总和\nlet s = 0;\n```\n').single;
      expect(a.title, '计算总和');
    });

    test('围栏上一行的描述 → 当标题', () {
      final a = extract('这是登录接口的模板\n\n```yaml\nkey: value\n```\n').single;
      expect(a.title, '这是登录接口的模板');
    });

    test('上一行带 markdown 标记 → 标记被剥掉', () {
      final a = extract('### 弱口令登录\n\n```yaml\nkey: value\n```\n').single;
      expect(a.title, '弱口令登录');
    });

    test('上一行过长（是正文段落）→ 不用它，退回语言名', () {
      final long = '这段说明写得非常长' * 8;
      final a = extract('$long\n\n```yaml\nkey: value\n```\n').single;
      expect(a.title, 'YAML');
    });

    test('无任何线索 → 语言名大写；无语言 → 按形态兜底', () {
      expect(extract('```sql\nSELECT 1;\n```\n').single.title, 'SQL');
      expect(extract('```\n裸文本\n```\n').single.title, 'Code');
      expect(extract('```mermaid\n```\n'), isEmpty); // 空围栏不产出
    });
  });

  group('来源偏移与行号', () {
    test('startLine 精确到围栏所在行', () {
      final a = extract('第一行\n第二行\n```dart\nvar x = 1;\n```\n').single;
      expect(a.startLine, 2, reason: '``` 在第 3 行，0 起即 2');
    });

    test('sourceStart 与块的偏移一致 —— 卡片靠它配对', () {
      // ⚠️ 走**默认阈值**（生产路径），所以样例必须够长才会产出产物。
      final body = List.generate(40, (i) => 'var x$i = $i;').join('\n');
      final src = '开头\n\n```dart\n$body\n```\n';
      final blocks = MarkdownParser.parse(src);
      final fence = blocks.whereType<MdCodeFence>().single;
      final a = ChatArtifact.fromBlocks(blocks, src).single;

      expect(a.sourceStart, fence.sourceStart,
          reason: '配对依据必须是偏移；语言和内容都可能重复');
    });

    test('同一语言的两个围栏 → 偏移各不相同（按语言配对会拿错）', () {
      const src = '```dart\nvar a = 1;\n```\n\n```dart\nvar b = 2;\n```\n';
      final artifacts = extract(src);
      expect(artifacts.length, 2);
      expect(artifacts[0].sourceStart, isNot(artifacts[1].sourceStart));
      expect(artifacts[0].content, 'var a = 1;');
      expect(artifacts[1].content, 'var b = 2;');
    });
  });

  group('落盘文件名', () {
    test('常见语言 → 对应扩展名', () {
      expect(extract('```dart\nvar x = 1;\n```\n').single.extension, '.dart');
      expect(extract('```python\nb = 2\n```\n').single.extension, '.py');
      expect(extract('```md\n# 标题\n```\n').single.extension, '.md');
      expect(extract('```mermaid\ngraph TD\nA-->B\n```\n').single.extension,
          '.mmd');
    });

    test('未知语言 → 按形态兜底（不能落出无扩展名）', () {
      expect(extract('```brainfuck\n+++\n```\n').single.extension, '.txt');
    });

    test('标题里的非法字符被剥掉 —— 否则 Windows 保存框会拒绝', () {
      final a = extract('```json\n{}\n```\n').single;
      final artifact = ChatArtifact(
        title: 'a/b:c*d?e"f<g>h|i',
        language: a.language,
        content: a.content,
        kind: a.kind,
      );
      expect(artifact.fileName, isNot(contains('/')));
      expect(artifact.fileName, isNot(contains(':')));
      expect(artifact.fileName, isNot(contains('*')));
      expect(artifact.fileName, isNot(contains('?')));
      expect(artifact.fileName, isNot(contains('"')));
      expect(artifact.fileName, isNot(contains('<')));
      expect(artifact.fileName, isNot(contains('>')));
      expect(artifact.fileName, isNot(contains('|')));
      expect(artifact.fileName, endsWith('.json'));
    });

    test('标题为空 / 全非法 → 退回 artifact 主干，不落出裸扩展名', () {
      const a = ChatArtifact(
        title: '///',
        language: '',
        content: 'x',
        kind: ArtifactKind.code,
      );
      expect(a.fileName, 'artifact.txt');
      expect(a.fileName, isNot(startsWith('.')));
    });

    test('结尾的点与空格被剥掉（Win32 会静默吃掉）', () {
      const a = ChatArtifact(
        title: 'report...   ',
        language: 'txt',
        content: 'x',
        kind: ArtifactKind.code,
      );
      expect(a.fileName, 'report.txt');
    });
  });

  group('类型标签', () {
    test('有语言 → 大写的语言名', () {
      expect(extract('```yaml\nk: v\n```\n').single.typeLabel, 'YAML');
    });

    test('无语言 → 按形态给中性名', () {
      const a = ChatArtifact(
        title: 't',
        language: '',
        content: 'x',
        kind: ArtifactKind.chart,
      );
      expect(a.typeLabel, 'CHART');
    });
  });

  group('工具产物', () {
    test('fromTool 不带围栏也能构造，sourceStart 为 -1', () {
      final a = ChatArtifact.fromTool(
        name: 'shell',
        argsSummary: 'ls -la',
        output: 'file.txt',
      );
      expect(a.kind, ArtifactKind.tool);
      expect(a.content, 'file.txt');
      expect(a.sourceStart, -1, reason: '工具产物不来自围栏，没有偏移');
    });

    test('工具没有 output 时退回入参摘要', () {
      final a = ChatArtifact.fromTool(name: 'shell', argsSummary: 'ls -la');
      expect(a.content, 'ls -la');
    });
  });
}
