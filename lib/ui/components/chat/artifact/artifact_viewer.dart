import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/design/tokens/app_typography.dart';
import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/chat/artifact/mermaid_chart_view.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/markdown_view.dart';
import 'package:sgit_studio_flutter/ui/components/chat/markdown/markdown_view_cache.dart';

/// 产物正文 —— 按 [ChatArtifact.kind] 选渲染分支。
///
/// 放在 `ui/`：它是纯展示，且要复用同目录的 [MarkdownView]。
/// `layout/panels/artifact_output_panel.dart` 引用它 —— `layout → ui` 是本仓
/// 既有方向（`nav_panel.dart` 早就 import 了 `ui/components/menu`），不是新开的边。
///
/// ## 为什么按类型分而不是一律等宽
///
/// 一份后端返回的 `data` 报告用等宽显示时，表格会变成一堆竖线，
/// 层次全丢；反过来一份 YAML 配置丢进 Markdown 渲染器，`# 注释` 会变成标题、
/// `*` 会变成强调。**什么形态就用什么渲染器**是这里唯一的规则。
/// [ArtifactKind.fromLanguage] 决定归属，认不出来的走 [ArtifactKind.code] 等宽 ——
/// 原文至少是忠实的。
class ArtifactViewer extends StatefulWidget {
  const ArtifactViewer({super.key, required this.artifact});

  final ChatArtifact artifact;

  @override
  State<ArtifactViewer> createState() => _ArtifactViewerState();
}

class _ArtifactViewerState extends State<ArtifactViewer> {
  /// 文档分支的块缓存 + 链接 recognizer 列表，生命周期与内容绑定。
  MarkdownViewCache? _cache;
  var _recognizers = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers = <TapGestureRecognizer>[];
  }

  @override
  Widget build(BuildContext context) {
    final artifact = widget.artifact;
    // 换一条产物时，上一份的块缓存与 recognizer 都该丢掉。
    _cache ??= MarkdownViewCache();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      // 面板自己的选区。`_markdown` 里的 [MarkdownView] 用的是普通 [Text]
      // （选区统一交给外层 `SelectionArea`，见 `ChatTranscript`），聊天那边
      // 已经包了一层；这里不包的话右栏的文档就变成**完全选不中**。
      child: SelectionArea(
        child: switch (artifact.kind) {
          ArtifactKind.code => _monospace(artifact),
          ArtifactKind.document => _markdown(artifact),
          ArtifactKind.chart => _chart(artifact),
          ArtifactKind.tool => _tool(artifact),
        },
      ),
    );
  }

  /// 代码 / 未知：等宽原文。任何形态的兜底。
  Widget _monospace(ChatArtifact artifact) => Text(
    artifact.content,
    style: TextStyle(
      fontFamily: AppTypography.monospace,
      fontSize: 13,
      height: 1.5,
      color: AppSkin.of(context).text,
    ),
  );

  /// 文档：与聊天里**同一套** Markdown 渲染。两张视图、两套解析器必然漂移。
  Widget _markdown(ChatArtifact artifact) {
    _disposeRecognizers();

    final blocks = _cache!.parse(artifact.content);

    return MarkdownView(blocks: blocks, recognizers: _recognizers);
  }

  /// 图表：认得出就画，认不出退回等宽原文 —— 并明确告诉用户"这是原文，不是图"，
  /// 否则用户会以为渲染坏了。
  Widget _chart(ChatArtifact artifact) {
    final graph = MermaidChartView.tryBuild(artifact.content);
    if (graph != null) return graph;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _notice(AppLocalizations.of(context).chatArtifactUnavailable),
        const SizedBox(height: AppSpacing.sm),
        _monospace(artifact),
      ],
    );
  }

  /// 工具产出：JSON 解得出就按键值结构化，否则等宽。
  Widget _tool(ChatArtifact artifact) {
    final skin = AppSkin.of(context);
    final decoded = _tryDecode(artifact.content);

    if (decoded is Map) {
      return Text.rich(
        TextSpan(
          children: [
            for (final entry in decoded.entries)
              TextSpan(
                children: [
                  TextSpan(
                    text: '${entry.key}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: skin.textSecondary,
                    ),
                  ),
                  TextSpan(
                    text: '  ${_stringify(entry.value)}\n',
                    style: TextStyle(color: skin.text),
                  ),
                ],
              ),
          ],
        ),
        style: TextStyle(
          fontFamily: AppTypography.monospace,
          fontSize: 13,
          height: 1.6,
        ),
      );
    }

    // 能解析成 JSON 但不是对象（数组 / 标量）时，美化后的 JSON 比原文好读。
    final text = decoded == null
        ? artifact.content
        : const JsonEncoder.withIndent('  ').convert(decoded);
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppTypography.monospace,
        fontSize: 13,
        height: 1.5,
        color: skin.text,
      ),
    );
  }

  static Object? _tryDecode(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    // 只在看起来像 JSON 时才试 —— `jsonDecode('123')` 会成功并把它变成 int，
    // 于是任意一段纯数字文本都会被当 JSON 美化，反而失真。
    if (!t.startsWith('{') && !t.startsWith('[')) return null;
    try {
      return jsonDecode(t);
    } catch (_) {
      return null;
    }
  }

  static String _stringify(Object? v) {
    if (v == null) return 'null';
    if (v is String) return v;
    if (v is Map || v is List) {
      return const JsonEncoder.withIndent('  ').convert(v);
    }
    return '$v';
  }

  Widget _notice(String text) {
    final skin = AppSkin.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 14, color: skin.textTertiary),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: skin.textTertiary),
          ),
        ),
      ],
    );
  }
}
