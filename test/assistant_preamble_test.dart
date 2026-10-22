import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/domain/models/chat/assistant_preamble.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_item.dart';

/// 助手回复开头的「技能 / 工具调用抬头」清理。
///
/// 这里钉住的是**两侧的边界**，而不是那三段英文本身：
/// - 该藏的藏掉（截图里那种三行抬头 + 引号参数）；
/// - 不该动的**一个字都不能动** —— 误删正文比多显示三行噪声严重得多。
void main() {
  group('挡住真实抬头', () {
    test('工具名 + file: + 引号参数 → 只留后面的正文', () {
      const raw = 'imagegen\n'
          'file: r1/svg-diagram/SKILL.md\n'
          '"Generate a basic style flowchart with standard elements: a start '
          'rectangle, one process rectangle."\n'
          '以下是一个基本样式流程图的示例：\n';

      expect(AssistantPreamble.strip(raw), '以下是一个基本样式流程图的示例：\n');
    });

    test('没有引号参数也能认出来', () {
      const raw = 'imagegen\nfile: r1/svg-diagram/SKILL.md\n正文第一行\n';
      expect(AssistantPreamble.strip(raw), '正文第一行\n');
    });

    test('路径被括号 / 引号 / 方括号包着也认得出', () {
      for (final line in [
        '(file: r1/skill-creator/SKILL.md)',
        '[file: r1/skill-creator/SKILL.md]',
        '(path: "r1/skill-creator/SKILL.md")',
        'File: `r1/skill-creator/SKILL.md`',
      ]) {
        expect(
          AssistantPreamble.strip('skill-creator\n$line\n很抱歉，我无法访问。\n'),
          '很抱歉，我无法访问。\n',
          reason: line,
        );
      }
    });

    test('抬头与正文之间夹空行一并吃掉', () {
      const raw = 'mcp__server__tool\nfile: /tmp/a/SKILL.md\n\n\n正文\n';
      expect(AssistantPreamble.strip(raw), '正文\n');
    });

    test('Windows 路径的抬头', () {
      const raw = 'imagegen\nfile: C:\\skills\\svg\\SKILL.md\n"draw it"\n答案\n';
      expect(AssistantPreamble.strip(raw), '答案\n');
    });

    test('跨行的引号参数', () {
      const raw = 'imagegen\nfile: r1/x/SKILL.md\n'
          '"第一行参数\n'
          '第二行参数"\n'
          '正文\n';
      expect(AssistantPreamble.strip(raw), '正文\n');
    });

    test('CRLF 换行同样处理', () {
      const raw = 'imagegen\r\nfile: r1/x/SKILL.md\r\n正文\r\n';
      expect(AssistantPreamble.strip(raw), '正文\r\n');
    });

    test('技能名 + 单行 JSON 参数（截图 2）', () {
      const raw = 'skill-creator\n'
          '{"name": "website_list", "description": "Create a list of popular '
          'AI websites in China, including their URLs and functions.", '
          '"url": "https://api.example.com/creator/website_list", '
          '"inputs": ["input_parameters"]}\n'
          '根据2026年中国地区的情况，以下是一些较为流行的网页版AI应用及其特色：\n';
      expect(
        AssistantPreamble.strip(raw),
        '根据2026年中国地区的情况，以下是一些较为流行的网页版AI应用及其特色：\n',
      );
    });

    test('技能名 + 多行 JSON + 闭合后残留技能名 + 第二段 JSON（截图 3）', () {
      const raw = 'skill-creator\n'
          '{\n'
          '"name": "comparison skill",\n'
          '"file": "C:/Users/86158/.sgitai/skills/comparison_skill/SKILL.md",\n'
          '"description": "This skill enables a comparative analysis of different '
          'technologies, products, or services."\n'
          '}comparison skill\n'
          '{\n'
          '"tech1": "Claude",\n'
          '"tech2": "DeepSeek",\n'
          '"tech3": "豆包",\n'
          '"tech4": "ChatGPT",\n'
          '"output_field1": "优点",\n'
          '"output_field2": "缺点"\n'
          '}\n'
          '以下是Claude、DeepSeek、豆包和ChatGPT的优缺点对比：\n';
      expect(
        AssistantPreamble.strip(raw),
        '以下是Claude、DeepSeek、豆包和ChatGPT的优缺点对比：\n',
      );
    });

    test('JSON 里的字符串含花括号也能正确配平', () {
      const raw = 'skill-creator\n'
          '{"name": "tpl", "description": "输出 { 和 } 作为占位符"}\n'
          '正文\n';
      expect(AssistantPreamble.strip(raw), '正文\n');
    });

    test('JSON 里的反斜杠转义引号不会提前收尾', () {
      const raw = 'skill-creator\n'
          '{"name": "q", "description": "say \\"hi\\" then stop"}\n'
          '正文\n';
      expect(AssistantPreamble.strip(raw), '正文\n');
    });
  });

  group('绝不误删正文', () {
    test('普通中文回答原样返回', () {
      const raw = '这是一个普通回答。\n\n第二段。';
      expect(AssistantPreamble.strip(raw), raw);
    });

    test('以英文开头的正常回答原样返回', () {
      const raw = 'Yes.\n\nThe fix is to restart the service.';
      expect(AssistantPreamble.strip(raw), raw);
    });

    test('首行是标识符、第二行不是 file: → 原样返回', () {
      const raw = 'imagegen\n这是一段解释 imagegen 的文字。';
      expect(AssistantPreamble.strip(raw), raw);
    });

    test('第二行是 file: 但不像路径（带空格）→ 原样返回', () {
      const raw = 'imagegen\nfile: 这不是路径\n正文';
      expect(AssistantPreamble.strip(raw), raw);
    });

    test('第二行是 file: 但没有路径分隔符 → 原样返回', () {
      const raw = 'imagegen\nfile: SKILL.md\n正文';
      expect(AssistantPreamble.strip(raw), raw);
    });

    test('只有一个单词的一行回答不会被吞', () {
      const raw = 'imagegen';
      expect(AssistantPreamble.strip(raw), raw);
    });

    test('首行带空格的普通句子 → 原样返回', () {
      const raw = 'Here is the plan\nfile: /tmp/x\n正文';
      expect(AssistantPreamble.strip(raw), raw);
    });

    test('首行大写开头的普通词不算技能名', () {
      for (final raw in [
        'Example\n{"a": "b"}\n正文',
        'Note\nfile: /tmp/x/SKILL.md\n正文',
        'Yes\n{"ok": true}\n正文',
      ]) {
        expect(AssistantPreamble.strip(raw), raw, reason: raw);
      }
    });

    test('首行是小写词、后面跟普通句子 → 原样返回', () {
      const raw = 'example\n这是一段正文，不是 JSON。';
      expect(AssistantPreamble.strip(raw), raw);
    });

    test('花括号里没有键值对（普通段落）→ 原样返回', () {
      const raw = 'note\n{这是一段说明}\n正文';
      expect(AssistantPreamble.strip(raw), raw);
    });

    test('小写词 + JSON 之后紧跟中文正文 → 只吃到 JSON 为止', () {
      const raw = 'skill-creator\n{"a": "b"}\n以下是回答：\n';
      expect(AssistantPreamble.strip(raw), '以下是回答：\n');
    });
  });

  group('流式期', () {
    test('只吐到工具名 → 不动', () {
      expect(AssistantPreamble.strip('imagegen'), 'imagegen');
      expect(AssistantPreamble.strip('imagegen\n'), 'imagegen\n');
    });

    test('第二行只到 file: 的一半 → 不动（不能拿前缀去猜）', () {
      expect(AssistantPreamble.strip('imagegen\nfi'), 'imagegen\nfi');
    });

    test('路径还没收尾 → 整段先藏', () {
      expect(AssistantPreamble.strip('imagegen\nfile: r1/svg'), '');
    });

    test('引号参数没收尾 → 整段先藏，正文一到就露出来', () {
      const partial = 'imagegen\nfile: r1/x/SKILL.md\n"draw a flow';
      expect(AssistantPreamble.strip(partial), '');
      expect(AssistantPreamble.strip('$partial"\n正文'), '正文');
    });

    test('永远不闭合的引号 → 放弃识别，原样返回（不能吞掉整篇回答）', () {
      final raw = 'imagegen\nfile: r1/x/SKILL.md\n"${'a' * 40000}';
      expect(AssistantPreamble.strip(raw), raw);
    });
  });

  group('TextItem.displayText', () {
    test('助手条目走清理，原文仍保留在 text 上', () {
      final item = TextItem(
        id: 1,
        role: ChatRole.assistant,
        initial: 'imagegen\nfile: r1/x/SKILL.md\n"draw"\n正文',
      );
      expect(item.text, startsWith('imagegen'));
      expect(item.displayText, '正文');
    });

    test('用户条目原样返回 —— 用户写的什么都是他自己的', () {
      final item = TextItem(
        id: 2,
        role: ChatRole.user,
        initial: 'imagegen\nfile: r1/x/SKILL.md\n"draw"\n正文',
      );
      expect(item.displayText, item.text);
    });

    test('append 之后缓存失效，抬头补全了也能跟上', () {
      final item = TextItem(id: 3, role: ChatRole.assistant, initial: 'image');
      expect(item.displayText, 'image');
      item.append('gen\nfile: r1/x/SKILL.md\n"draw"\n正文');
      expect(item.displayText, '正文');
    });
  });
}
