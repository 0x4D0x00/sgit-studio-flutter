import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/pages/memory_page.dart';
import 'package:sgit_studio_flutter/features/studio/application/settings_repository_provider.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';

import 'fakes/fake_settings_repository.dart';

/// 记忆页的编辑 / 删除。
///
/// 要守的两条契约，都是"看起来能用、其实坏了"的那类：
///
/// 1. **点开编辑器拿的是磁盘全文**，不是列表里那两行摘要。列表给的是
///    `ResourceItem`（标题 + 截断摘要），拿它当正文保存会把整篇记忆截断。
/// 2. **删除走 `removeFromPage('memory', id)` 而不是 `delete('memories', id)`**
///    —— 前者是 studio 页的统一入口（`sgit_studio_remove`），后者在 Web 上
///    是另一条语义。写错了在本机能跑，但在 Web 上会静默删错东西。
const noteId = 'project-sgit.md';

void main() {
  const fullText = '''
# SGIT-Studio 项目

把 LobeChat 分支做成 sgcode 的展示皮。
正文第二段，这一行在列表摘要里绝不会出现。
''';

  Widget harness(FakeSettingsRepository repo) => ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(
            primary: AppColors.defaultPrimary,
            secondary: AppColors.defaultSecondary,
          ),
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(body: MemoryPage()),
        ),
      );

  testWidgets('点开记忆：编辑器里是磁盘全文，不是列表摘要', (tester) async {
    final repo = FakeSettingsRepository(
      pages: const {
        'tools': {
          'features': {'memories': true},
        },
        'memory': {
          'notes': [
            {
              'id': noteId,
              'name': 'SGIT-Studio 项目',
              'description': '把 LobeChat 分支做成 sgcode 的展示皮。',
            },
          ],
        },
      },
    );
    StubReadContent(repo, fullText);

    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SGIT-Studio 项目'));
    await tester.pumpAndSettle();

    // 全文里的第二段必须出现在编辑器里 —— 摘要里没有它。
    expect(find.textContaining('正文第二段'), findsOneWidget);
    // 且读的是 memories 这个 kind（与 write/settings 的 path_of 同一套解析）。
    expect(repo.calls, contains('read:memories/$noteId'));
  });

  testWidgets('改动后保存：写回 memories，并刷新列表', (tester) async {
    final repo = FakeSettingsRepository(
      pages: const {
        'tools': {
          'features': {'memories': true},
        },
        'memory': {
          'notes': [
            {'id': noteId, 'name': 'SGIT-Studio 项目', 'description': '旧摘要'},
          ],
        },
      },
    );
    StubReadContent(repo, fullText);

    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('SGIT-Studio 项目'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '$fullText\n新增一行');
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final write = repo.calls.firstWhere((c) => c.startsWith('write:'));
    expect(write, 'write:memories/$noteId');
    expect(repo.written[noteId], contains('新增一行'));
    // 保存后必须重取列表，否则界面还挂着旧摘要。
    expect(repo.calls, contains('readPage:memory'));
  });

  testWidgets('删除记忆：先确认，确认后走 removeFromPage(memory)', (tester) async {
    final repo = FakeSettingsRepository(
      pages: const {
        'tools': {
          'features': {'memories': true},
        },
        'memory': {
          'notes': [
            {'id': noteId, 'name': 'SGIT-Studio 项目', 'description': '旧摘要'},
          ],
        },
      },
    );

    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    // 未确认时不删 —— 删除不可逆，误点一下不能就没。
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();
    expect(find.text('确定删除「SGIT-Studio 项目」？'), findsOneWidget);
    expect(repo.calls.where((c) => c.startsWith('removeFromPage')), isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('removeFromPage:memory/$noteId'));
  });
}

/// 让假仓储的 `read('memories', ...)` 返回指定正文。
///
/// `FakeSettingsRepository.read` 恒返回空串，而记忆页要靠它取全文 ——
/// 不覆盖的话，"点开是全文"这条断言永远绿不了（也永远测不出问题）。
void StubReadContent(FakeSettingsRepository repo, String content) {
  repo.readContent['memories/$noteId'] = content;
}
