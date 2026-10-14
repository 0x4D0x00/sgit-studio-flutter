import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';

/// 产物落盘的结果。
///
/// ⚠️ 「用户取消」**不是失败**。这是三态而不是 `bool` 的全部理由：取消时弹
/// 「保存失败」会让用户以为出了错，而实际上什么都没发生。
enum SaveOutcome { saved, cancelled, failed }

/// 把产物写到用户选的位置。
///
/// ## 为什么是单文件而不是 io/web 两份实现
///
/// `FilePicker.saveFile` 在新版 `file_picker` 里已经**收成跨平台单入口**了：
/// 入参是 `bytes` 而不是路径，桌面端内部弹系统保存框、Web 端内部走 Blob 下载，
/// 两边都返回 `Uri?`（取消时为 null）。所以这里不需要照
/// `services/brand/brand_source_io.dart` 那套条件导入再写一份 —
/// 多一份实现就多一处要跟着上游改的地方。
///
/// 放 `services/` 而不是 `ui/`：它要碰第三方文件对话框，而 `ui/` 是纯展示层。
/// 卡片只收一个回调，由 `text_bubble.dart` 注入。
class ArtifactExporter {
  const ArtifactExporter._();

  /// 保存 [artifact]。[dialogTitle] 走 l10n，由调用方传入。
  ///
  /// 不抛异常：调用方是 UI 回调，异常只会变成控制台里一行谁都不看的堆栈。
  /// 失败返回 [SaveOutcome.failed]，由调用方决定怎么提示。
  static Future<SaveOutcome> save(
    ChatArtifact artifact, {
    String? dialogTitle,
  }) async {
    try {
      final bytes = Uint8List.fromList(utf8.encode(artifact.content));
      final uri = await FilePicker.saveFile(
        fileName: artifact.fileName,
        bytes: bytes,
        mimeType: _mimeTypeOf(artifact),
        dialogTitle: dialogTitle,
      );
      return uri == null ? SaveOutcome.cancelled : SaveOutcome.saved;
    } catch (_) {
      return SaveOutcome.failed;
    }
  }

  /// 产物的 MIME 类型。只影响保存框的筛选提示与 Web 端的 Blob 类型，
  /// 猜错也不影响内容本身，所以不必穷尽 —— 未知一律给文本。
  static String _mimeTypeOf(ChatArtifact artifact) {
    switch (artifact.extension) {
      case '.json':
        return 'application/json';
      case '.html':
      case '.htm':
        return 'text/html';
      case '.svg':
        return 'image/svg+xml';
      case '.xml':
        return 'application/xml';
      case '.csv':
      case '.tsv':
        return 'text/csv';
      case '.yaml':
        return 'application/yaml';
      case '.md':
        return 'text/markdown';
      case '.dart':
      case '.py':
      case '.js':
      case '.ts':
      case '.java':
      case '.kt':
      case '.go':
      case '.rs':
      case '.c':
      case '.cpp':
      case '.cs':
      case '.rb':
      case '.php':
      case '.swift':
      case '.sh':
      case '.sql':
      case '.toml':
      case '.ini':
      case '.css':
      case '.scss':
      case '.txt':
      case '.log':
      case '.mmd':
      case '.dot':
      case '.puml':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }
}
