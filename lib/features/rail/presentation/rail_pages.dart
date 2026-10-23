import 'package:flutter/material.dart';

import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

/// 最左侧工具列的三个页面（图像 / 定时任务 / 资料库）。目前只有界面，没有数据。

/// 大标题 + 一排胶囊标签 + 内容。图像、资料库共用。
class _TabbedPage extends StatefulWidget {
  const _TabbedPage({required this.title, required this.tabs});

  final String title;
  final List<String> tabs;

  @override
  State<_TabbedPage> createState() => _TabbedPageState();
}

class _TabbedPageState extends State<_TabbedPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 32,right: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: skin.text,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < widget.tabs.length; i++)
                _Pill(
                  label: widget.tabs[i],
                  selected: i == _tab,
                  onTap: () => setState(() => _tab = i),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Expanded(child: _CardGrid()),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return Material(
      color: selected ? skin.navItemActive : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? skin.text : skin.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 占位卡片网格。
class _CardGrid extends StatelessWidget {
  const _CardGrid();

  @override
  Widget build(BuildContext context) {
    final skin = AppSkin.of(context);
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: 6,
      itemBuilder: (_, _) => DecoratedBox(
        decoration: BoxDecoration(
          color: skin.containerBgSecondary,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class ImagesPage extends StatelessWidget {
  const ImagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _TabbedPage(
      title: l10n.railImages,
      tabs: [l10n.imagesTabHot, l10n.imagesTabTemplates],
    );
  }
}

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _TabbedPage(
      title: l10n.railLibrary,
      tabs: [
        l10n.libraryTabRecommended,
        l10n.libraryTabFavorites,
        l10n.libraryTabFolders,
        l10n.libraryTabImages,
        l10n.libraryTabAll,
      ],
    );
  }
}

/// 定时任务：页内自带一栏任务列表（标题 + 搜索 / 新建任务 / 即将执行），右侧是内容区。
class TasksPage extends StatelessWidget {
  const TasksPage({super.key});

  static const double _listWidth = 360;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final skin = AppSkin.of(context);
    final muted = TextStyle(fontSize: 14, color: skin.textTertiary);
    return Row(
      children: [
        Container(
          width: _listWidth,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: skin.borderSecondary)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.railTasks,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: skin.text,
                      ),
                    ),
                  ),
                  Icon(Icons.search, size: 20, color: skin.textSecondary),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.add, size: 20, color: skin.text),
                  const SizedBox(width: 12),
                  Text(
                    l10n.tasksNew,
                    style: TextStyle(fontSize: 15, color: skin.text),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Text(l10n.tasksUpcoming, style: muted)),
                  Icon(Icons.filter_list, size: 18, color: skin.textTertiary),
                ],
              ),
              const SizedBox(height: 12),
              Text(l10n.tasksEmpty, style: muted),
            ],
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
  }
}
