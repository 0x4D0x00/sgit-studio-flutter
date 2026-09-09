import 'package:flutter/foundation.dart';

/// 从文本消息中提取的代码块/产物。
@immutable
class CodeArtifact {
  const CodeArtifact({
    required this.title,
    required this.language,
    required this.code,
    this.startLine = 0,
  });

  /// 标题（从上下文推断或代码块首行注释提取）。
  final String title;

  /// 语言标识（markdown 代码块的 language）。
  final String language;

  /// 完整代码。
  final String code;

  /// 在原消息中的起始行（用于定位）。
  final int startLine;

  /// 从 Markdown 文本中提取所有代码块。
  static List<CodeArtifact> extractFromMarkdown(String text) {
    final results = <CodeArtifact>[];
    final lines = text.split('\n');

    int i = 0;
    while (i < lines.length) {
      final line = lines[i];

      // 检测代码块开始标记：```language
      if (line.trim().startsWith('```')) {
        final lang = line.trim().substring(3).trim();
        final startLine = i;
        final codeLines = <String>[];
        i++;

        // 收集代码内容直到结束标记
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }

        if (codeLines.isNotEmpty) {
          final code = codeLines.join('\n');
          // 尝试从代码或上文提取标题
          final title = _inferTitle(code, lang, lines, startLine);

          results.add(CodeArtifact(
            title: title,
            language: lang.isEmpty ? 'plain' : lang,
            code: code,
            startLine: startLine,
          ));
        }

        i++; // 跳过结束的 ```
      } else {
        i++;
      }
    }

    return results;
  }

  /// 推断标题：从代码首行注释、上文描述或语言类型。
  static String _inferTitle(
    String code,
    String lang,
    List<String> allLines,
    int startLine,
  ) {
    // 1. 尝试从代码首行提取（如 # 文件名 或 // 标题）
    final firstLine = code.trim().split('\n').first.trim();
    if (firstLine.startsWith('#')) {
      return firstLine.substring(1).trim();
    }
    if (firstLine.startsWith('//')) {
      return firstLine.substring(2).trim();
    }

    // 2. 尝试从代码块前一行获取描述
    if (startLine > 0) {
      final prevLine = allLines[startLine - 1].trim();
      if (prevLine.isNotEmpty && !prevLine.startsWith('```')) {
        // 移除 markdown 标记
        final cleaned = prevLine
            .replaceAll(RegExp(r'^#+\s*'), '')
            .replaceAll(RegExp(r'^\*+\s*'), '')
            .replaceAll(RegExp(r'^-+\s*'), '');
        if (cleaned.length < 60) {
          return cleaned;
        }
      }
    }

    // 3. 回退到语言类型
    return lang.isEmpty ? 'Code' : lang.toUpperCase();
  }
}
