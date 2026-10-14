import 'package:flutter/foundation.dart';

import 'package:sgit_studio_flutter/domain/models/chat/markdown/markdown_block.dart';

/// 产物的形态 —— 决定右侧面板用哪条渲染分支打开它，也决定卡片上的图标。
///
/// ⚠️ 分类的依据是**怎么渲染**，不是"这文件是什么"。所以 `json` / `yaml` / `csv`
/// 归 [code] 而不是 [document]：[document] 走 Markdown 富文本渲染，把一份 JSON
/// 丢进去会被星号、下划线、`#` 注释搅成乱码。只有**本来就是 Markdown 原文**的
/// 才配 [document]。
enum ArtifactKind {
  /// 代码 / 结构化数据：等宽展示。
  code,

  /// Markdown 文档：走富文本渲染，与聊天里同一套。
  document,

  /// 图表描述（mermaid / dot / plantuml）：尽力画成图，画不出来退回等宽。
  chart,

  /// 工具产出：键值结构化展示。**不来自围栏**，由 `ToolItem` 直接构造。
  tool;

  /// 围栏的 info string → 产物形态。
  static ArtifactKind fromLanguage(String language) {
    switch (language.trim().toLowerCase()) {
      case 'md':
      case 'markdown':
      case 'gfm':
        return ArtifactKind.document;
      case 'mermaid':
      case 'mmd':
      case 'dot':
      case 'graphviz':
      case 'plantuml':
      case 'puml':
        return ArtifactKind.chart;
      default:
        return ArtifactKind.code;
    }
  }
}

/// 会话中产生的一份可打开产物 —— 代码、文档、图表或工具产出。
///
/// 卡片（`ui/components/chat/markdown/code_block_card.dart`）拿它画标题行，
/// 右侧面板（`ui/components/chat/artifact/artifact_viewer.dart`）拿它选渲染分支。
///
/// ## 为什么提取走 [fromBlocks] 而不是自己扫一遍原文
///
/// 这里曾经有一套独立于 `MarkdownParser` 的手写围栏扫描：按行 `startsWith('```')`
/// 切段。后果是它与解析器**行为漂移** —— `~~~` 围栏认不出、缩进围栏认不出、
/// 段落里出现的 ``` 会误判成块、流式期未闭合的围栏会吐出一个半截产物。
/// 解析器那边每修一次这类问题，这里都要再修一次。
///
/// 现在改成消费解析器已经产出的 AST：围栏识别的全部规则（含未闭合围栏的
/// 容错）都只有一处实现，卡片与正文永远同进同出。
@immutable
class ChatArtifact {
  const ChatArtifact({
    required this.title,
    required this.language,
    required this.content,
    required this.kind,
    this.startLine = 0,
    this.sourceStart = -1,
  });

  /// 展示标题（从上下文推断或代码块首行注释提取）。
  final String title;

  /// 语言 / 工具名标识。卡片上大写成类型标签。
  final String language;

  /// 完整内容。
  final String content;

  final ArtifactKind kind;

  /// 在原消息中的起始行（0 起，用于定位）。
  final int startLine;

  /// 产生这条产物的围栏在**规范化原文**里的起始偏移，等价于
  /// [MdCodeFence.sourceStart]。`-1` 表示不是从围栏来的（工具产物）。
  ///
  /// 这是卡片与产物之间唯一的配对依据 —— 比对语言或内容都不行：一条回答里
  /// 两个 ```dart 块的语言完全相同、两段空代码的内容也完全相同。渲染时按偏移
  /// 精确取，见 `MarkdownView.artifactFor`。
  final int sourceStart;

  /// 卡片上的类型标签。
  String get typeLabel {
    if (language.trim().isNotEmpty) return language.trim().toUpperCase();
    return switch (kind) {
      ArtifactKind.document => 'MD',
      ArtifactKind.chart => 'CHART',
      ArtifactKind.tool => 'TOOL',
      ArtifactKind.code => 'CODE',
    };
  }

  /// 落盘时用的扩展名（含点），如 `.dart`。
  String get extension => extensionFor(language, kind);

  /// 落盘时用的文件名。标题里的非法字符必须全部剥掉 —— 用户可能直接
  /// 拿它去 Windows 的文件对话框，那里 `\ / : * ? " < > |` 一个都不许出现。
  String get fileName => '${_slug(title)}$extension';

  static final RegExp _illegal = RegExp(r'[\\/:*?"<>|\x00-\x1F]');
  static final RegExp _spaces = RegExp(r'\s+');

  /// 标题 → 安全文件名主干。空标题退回 `artifact`，避免落出一个 `.dart` 这种纯扩展名。
  static String _slug(String raw) {
    var s = raw.replaceAll(_illegal, ' ').replaceAll(_spaces, ' ').trim();
    // Windows 的路径分隔符之外，还要挡掉结尾的点与空格（Win32 会静默吃掉）。
    s = s.replaceAll(RegExp(r'[. ]+$'), '');
    if (s.isEmpty) return 'artifact';
    // 太长会被部分文件系统拒绝，且对话框里也显示不全。
    if (s.length > 60) s = s.substring(0, 60).trim();
    return s.isEmpty ? 'artifact' : s;
  }

  /// info string → 落盘扩展名。
  static String extensionFor(String language, ArtifactKind kind) {
    final ext = _extensions[language.trim().toLowerCase()];
    if (ext != null) return ext;
    // 没有映射的语言按形态给一个能打开的兜底 —— 未知语言的代码落成 .txt
    // 至少双击能开，落成空扩展名在 Windows 上会卡在关联对话框。
    return switch (kind) {
      ArtifactKind.document => '.md',
      ArtifactKind.chart => '.mmd',
      ArtifactKind.tool => '.json',
      ArtifactKind.code => '.txt',
    };
  }

  static const Map<String, String> _extensions = {
    // 代码
    'dart': '.dart',
    'py': '.py',
    'python': '.py',
    'js': '.js',
    'javascript': '.js',
    'jsx': '.jsx',
    'ts': '.ts',
    'typescript': '.ts',
    'tsx': '.tsx',
    'java': '.java',
    'kt': '.kt',
    'kotlin': '.kt',
    'go': '.go',
    'rs': '.rs',
    'rust': '.rs',
    'c': '.c',
    'h': '.h',
    'cpp': '.cpp',
    'c++': '.cpp',
    'hpp': '.hpp',
    'cs': '.cs',
    'csharp': '.cs',
    'rb': '.rb',
    'ruby': '.rb',
    'php': '.php',
    'swift': '.swift',
    'm': '.m',
    'mm': '.mm',
    'scala': '.scala',
    'lua': '.lua',
    'r': '.r',
    'pl': '.pl',
    'perl': '.pl',
    'ex': '.ex',
    'exs': '.exs',
    'erl': '.erl',
    'clj': '.clj',
    'hs': '.hs',
    'zig': '.zig',
    'nim': '.nim',
    'groovy': '.groovy',
    'gradle': '.gradle',
    'vb': '.vb',
    'asm': '.asm',
    'vue': '.vue',
    'svelte': '.svelte',
    // 脚本 / 配置
    'sh': '.sh',
    'bash': '.sh',
    'shell': '.sh',
    'zsh': '.sh',
    'fish': '.fish',
    'ps1': '.ps1',
    'powershell': '.ps1',
    'bat': '.bat',
    'cmd': '.cmd',
    'sql': '.sql',
    'makefile': '.mk',
    'dockerfile': '.dockerfile',
    'toml': '.toml',
    'ini': '.ini',
    'cfg': '.cfg',
    'conf': '.conf',
    'env': '.env',
    'properties': '.properties',
    'htaccess': '.htaccess',
    // 标记 / 数据
    'html': '.html',
    'htm': '.html',
    'xml': '.xml',
    'svg': '.svg',
    'css': '.css',
    'scss': '.scss',
    'sass': '.sass',
    'less': '.less',
    'json': '.json',
    'jsonc': '.jsonc',
    'json5': '.json5',
    'yaml': '.yaml',
    'yml': '.yaml',
    'csv': '.csv',
    'tsv': '.tsv',
    'tex': '.tex',
    'latex': '.tex',
    'md': '.md',
    'markdown': '.md',
    'gfm': '.md',
    'txt': '.txt',
    'text': '.txt',
    'plain': '.txt',
    'log': '.log',
    'diff': '.diff',
    'patch': '.patch',
    'http': '.http',
    // 图表
    'mermaid': '.mmd',
    'mmd': '.mmd',
    'dot': '.dot',
    'graphviz': '.dot',
    'plantuml': '.puml',
    'puml': '.puml',
    'puml ': '.puml',
  };

  /// 从解析好的块 AST 里提取所有围栏产物（含引用块内部，递归）。
  ///
  /// [source] 是**产生这些块的原文**（未规范化也行，内部会规范化）——
  /// 标题推断要看围栏上一行的描述文字，那段文字不在块 AST 里。
  static List<ChatArtifact> fromBlocks(
    List<MarkdownBlock> blocks,
    String source, {
    int inlineLineLimit = defaultInlineLineLimit,
  }) {
    final out = <ChatArtifact>[];
    _collect(blocks, MarkdownParser.normalize(source), out, inlineLineLimit);
    return out;
  }

  /// 短围栏的行数上限 —— **不超过这个行数的围栏不生成产物**。
  /// 阈值取 30：带注释的多步命令一般在 10 行上下，而真正值得单独成一个文件的
  /// 通常是整段实现（几十行起）。
  ///
  /// TODO 后端/用户若要求某些语言一律以文件形式展示，在这里按 language 放开
  ///      —— 那是"按类型"而不是"按长度"的策略，与这个阈值并存。
  static const int defaultInlineLineLimit = 30;

  static void _collect(
    List<MarkdownBlock> blocks,
    String source,
    List<ChatArtifact> out,
    int inlineLineLimit,
  ) {
    for (final block in blocks) {
      switch (block) {
        case MdCodeFence():
          // 空围栏没有可打开的产物 —— 它在聊天里仍会画一张普通代码块。
          if (block.code.trim().isEmpty) break;
          // 短块留在正文里，不生成文件卡。
          if (_lineCount(block.code) <= inlineLineLimit) break;
          final line = _lineOf(source, block.sourceStart);
          out.add(ChatArtifact(
            title: _inferTitle(block.code, block.language, source, line),
            language: block.language,
            content: block.code,
            kind: ArtifactKind.fromLanguage(block.language),
            startLine: line,
            sourceStart: block.sourceStart,
          ));
        case MdQuote():
          _collect(block.children, source, out, inlineLineLimit);
        case MdParagraph():
        case MdHeading():
        case MdList():
        case MdRule():
        case MdTable():
          break;
      }
    }
  }

  /// 非空行数。
  ///
  /// ⚠️ **空行不计** —— 一个 40 行的块里塞 20 行空行不算"长"，
  /// 按 `split('\n').length` 算会让格式化得稀疏的短代码误判成产物。
  static int _lineCount(String code) {
    var n = 0;
    for (final line in code.split('\n')) {
      if (line.trim().isNotEmpty) n++;
    }
    return n;
  }

  /// 工具产出 → 产物。工具内容不来自围栏，所以单独一条构造路径。
  static ChatArtifact fromTool({
    required String name,
    required String argsSummary,
    String? output,
  }) =>
      ChatArtifact(
        title: name,
        language: name,
        content: (output ?? '').trim().isNotEmpty ? output! : argsSummary,
        kind: ArtifactKind.tool,
      );

  /// 偏移量 → 0 起的行号。
  static int _lineOf(String source, int offset) {
    final end = offset.clamp(0, source.length);
    var line = 0;
    for (var i = 0; i < end; i++) {
      if (source.codeUnitAt(i) == 0x0A) line++;
    }
    return line;
  }

  /// 推断标题：代码首行注释 → 围栏上一行的描述 → 语言/形态兜底。
  ///
  /// ⚠️ 拿到任何来源都会再走一次 [_keywords] —— 模型写的描述往往是一整句话
  /// （「一个可以直接跑的待办清单示例，包含数据模型、状态管理……」），
  /// 原样塞进卡片会把标题撑成一整行省略号，看不出这是什么文件。
  static String _inferTitle(
    String code,
    String lang,
    String source,
    int startLine,
  ) {
    // 1. 代码首行注释（`# 文件名` / `// 标题` / `<!-- 标题 -->`）
    final firstLine = code.trimLeft().split('\n').first.trim();
    if (firstLine.startsWith('#')) {
      final t = _keywords(firstLine.substring(1));
      if (t.isNotEmpty) return t;
    }
    if (firstLine.startsWith('//')) {
      final t = _keywords(firstLine.substring(2));
      if (t.isNotEmpty) return t;
    }
    if (firstLine.startsWith('<!--') && firstLine.endsWith('-->')) {
      final t = _keywords(firstLine.substring(4, firstLine.length - 3));
      if (t.isNotEmpty) return t;
    }

    // 2. 围栏上一行的描述。⚠️ 要**向上跳过空行** —— 模型写卡片时几乎总是
    //    `描述\n\n```lang`，中间那行空行不能当成"上一行是空的，没描述可用"。
    if (startLine > 0) {
      final lines = source.split('\n');
      for (var i = startLine - 1; i >= 0; i--) {
        final prev = lines[i].trim();
        if (prev.isEmpty) continue;
        if (prev.startsWith('```') || prev.startsWith('~~~')) break;
        // ⚠️ 上一行要求**必须能切出分句**：它是描述句还是正文段落，靠标点区分。
        //    截图那种「一个可以直接跑的待办清单示例，包含数据模型……」切出首句
        //    就是好标题；而一坨没标点的长文本（正文里被折行的段落）截前 20 字
        //    只会得到一个随机字符串，那种情况宁可退回语言名。
        final cleaned = _keywords(prev, requireClause: true);
        if (cleaned.isNotEmpty) return cleaned;
        break;
      }
    }

    // 3. 兜底：语言大写，或按形态给个中性名。
    if (lang.trim().isNotEmpty) return lang.trim().toUpperCase();
    return switch (ArtifactKind.fromLanguage(lang)) {
      ArtifactKind.document => 'Markdown',
      ArtifactKind.chart => 'Chart',
      ArtifactKind.tool => 'Tool',
      ArtifactKind.code => 'Code',
    };
  }

  /// 从一句描述里取标题关键词 —— 截到第一个分句，并限长。
  ///
  /// 模型给的描述通常是**句子**而不是**名字**：
  /// 「一个可以直接跑的待办清单示例，包含数据模型、状态管理、列表增删改……」
  /// 整句塞进卡片只会变成一整行省略号，看标题跟没看一样。所以取第一个分句
  /// ——「一个可以直接跑的待办清单示例」，这才是这张卡的身份。
  ///
  /// ⚠️ **不按 `.` 切**（只在 `.` 后跟空白时切）：`main.dart`、`v1.2` 这类
  /// 文件名/版本号会被切成 `main`。模型写 `// main.dart` 当标题很常见。
  static String _keywords(String raw, {bool requireClause = false}) {
    var s = raw
        .replaceAll(RegExp(r'^#+\s*'), '')
        .replaceAll(RegExp(r'^[*-]+\s*'), '')
        .replaceAll(RegExp(r'^\d+\.\s*'), '')
        .replaceAll(RegExp(r'[*_`]'), '')
        .trim();
    if (s.isEmpty) return '';

    // 第一个分句。中英文标点都认 —— 模型两种都会用。
    final clauses = s.split(RegExp(r'[，。；：！？、,;:!?]|\.\s'));
    final hadClause = clauses.length > 1;
    s = clauses.first.trim();
    if (s.isEmpty) return '';

    // ⚠️ 一行**又长又没有分句标点** = 正文段落（被折行的说明文字），不是名字。
    //    短的无标点行（「这是登录接口的模板」）是正常标题，不能一起拒掉 ——
    //    区分依据是长度，不是"有没有标点"。
    if (requireClause && !hadClause && s.length > _proseLength) return '';

    // 分句本身还太长（整段没标点）就硬截，末尾补省略号让"被截过"看得出来。
    if (s.length > _titleMaxLength) {
      s = '${s.substring(0, _titleMaxLength).trim()}…';
    }
    return s;
  }

  /// 超过这个长度、又没有任何分句标点的上一行，判定为正文段落。
  static const int _proseLength = 40;

  /// 标题最大字符数。中文比英文占宽，这个值是按中文折算的
  /// —— 约等于卡片里一行放得下的量，再长就该靠省略号了。
  static const int _titleMaxLength = 20;
}
