import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/domain/models/chat/chat_artifact.dart';

/// 产物类型 → 图标。
///
/// 卡片（[CodeBlockCard]）与芯片（[ArtifactChip]）画的是同一个东西 ——
/// 同一条产物，两个入口。映射写两份必然漂移：改一处忘了另一处，
/// 于是同一个 dart 文件在聊天里是 `</>`、在下面那排里是别的图标。
IconData artifactKindIcon(ArtifactKind kind) => switch (kind) {
  ArtifactKind.code => Icons.code,
  ArtifactKind.document => Icons.description_outlined,
  ArtifactKind.chart => Icons.insights_outlined,
  ArtifactKind.tool => Icons.build_outlined,
};
