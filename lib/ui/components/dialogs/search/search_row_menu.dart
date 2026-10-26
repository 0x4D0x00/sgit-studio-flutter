import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/ui/components/dialogs/search/search_models.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu_entry.dart';

/// 行尾「⁝」菜单的条目。[fire] 负责真正执行动作（关弹窗 / 回传调用方 / 就地刷新）。
List<AppMenuEntry> buildSearchRowMenuEntries(
  AppLocalizations l10n,
  SearchDialogCategory category,
  Future<void> Function(SearchDialogRowAction action) fire,
) {
  AppMenuAction open() => AppMenuAction(
    icon: Icons.open_in_new,
    label: l10n.searchOpen,
    onTap: () => fire(SearchDialogRowAction.open),
  );
  AppMenuAction pin(String label) => AppMenuAction(
    icon: Icons.push_pin_outlined,
    label: label,
    onTap: () => fire(SearchDialogRowAction.pin),
  );
  final delete = AppMenuAction(
    icon: Icons.delete_outline,
    label: l10n.commonDelete,
    danger: true,
    onTap: () => fire(SearchDialogRowAction.delete),
  );

  // 三类的动作集合各不一样：产物只有开关与复制链接；项目/聊天多一个置顶，
  // 但项目走「编辑细节」、聊天走「重命名」。
  return switch (category) {
    SearchDialogCategory.artifact => [
      open(),
      AppMenuAction(
        icon: Icons.link,
        label: l10n.artifactsCopyLink,
        onTap: () => fire(SearchDialogRowAction.copyLink),
      ),
    ],
    SearchDialogCategory.project => [
      open(),
      pin(l10n.projectsPin),
      AppMenuAction(
        icon: Icons.edit_outlined,
        label: l10n.projectsEditDetails,
        onTap: () => fire(SearchDialogRowAction.editDetails),
      ),
      delete,
    ],
    SearchDialogCategory.chat => [
      open(),
      pin(l10n.navChatPin),
      AppMenuAction(
        icon: Icons.edit_outlined,
        label: l10n.navChatRename,
        onTap: () => fire(SearchDialogRowAction.rename),
      ),
      delete,
    ],
  };
}
