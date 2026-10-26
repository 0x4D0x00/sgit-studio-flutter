import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sgit_studio_flutter/features/chat/application/chat_ports_impl.dart';
import 'package:sgit_studio_flutter/core/storage/local_storage.dart';
import 'fakes/kernel_client_mock.dart';
import 'package:sgit_studio_flutter/design/themes/app_theme.dart';
import 'package:sgit_studio_flutter/design/tokens/app_colors.dart';
import 'package:sgit_studio_flutter/features/chat/presentation/chat_composer.dart';
import 'package:sgit_studio_flutter/app/app_providers.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/services/layout/transcript_width.dart';
import 'package:sgit_studio_flutter/ui/components/chat/composer/composer_shell.dart';

import 'fakes/fake_settings_repository.dart';

/// 「转录宽度」这档设置。
///
/// 两条最要紧的判据，都在这里钉住：
/// 1. **默认档 = 改动前的宽度**。这是加设置项，不是改设计 —— 任何现存用户
///    升级后不该看到界面变了一个像素。medium → 800 就是原来那个
///    `contentMaxWidth`。
/// 2. **输入框与正文列同源**。两者宽度都从同一个档位算出来，谁也不能写死。
///    历史上输入框是常量 768、正文是 800 − padding，恰好相等纯属巧合；
///    档位一动，这两个"巧合相等"的常量就会分叉。
void main() {
  // ⚠️ 挂在 main 顶层，不放进任何 group。LocalStorage 是进程级单例，而
  // `TranscriptWidthController.build` 会直接读它 —— 放进某个 group 的
  // `setUpAll` 里，就等于让「谁先跑」决定「谁不炸」：整个文件跑能过，
  // 单跑 widget 那个 group 必炸（前置 group 的 setUpAll 没执行）。
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('档位 → 像素（单一真源）', () {
    test('默认档 medium 等于改动前的 800，界面不会跳', () {
      expect(TranscriptWidth.medium.contentMaxWidth,
          WorkspaceMetrics.transcriptMediumWidth);
      expect(WorkspaceMetrics.transcriptMediumWidth, 800,
          reason: '这是改动前的 contentMaxWidth，动了就等于改了默认外观');
    });

    test('三档递增，且都不是魔法数', () {
      expect(TranscriptWidth.narrow.contentMaxWidth,
          lessThan(TranscriptWidth.medium.contentMaxWidth));
      expect(TranscriptWidth.medium.contentMaxWidth,
          lessThan(TranscriptWidth.wide.contentMaxWidth));
    });

    test('输入框宽度 = 正文列 − 左右内边距（两者同源）', () {
      for (final w in TranscriptWidth.values) {
        expect(
          w.composerWidth,
          w.contentMaxWidth - WorkspaceMetrics.contentPaddingInline * 2,
          reason: '$w：输入框与正文列必须由同一档算出，否则窄档下输入框会宽出去',
        );
      }
    });

    test('medium 档的输入框宽度仍是 768', () {
      expect(TranscriptWidth.medium.composerWidth, 768);
    });
  });

  group('解析：坏值一律退回默认，不崩', () {
    test('认识三个档名', () {
      expect(TranscriptWidth.parse('narrow'), TranscriptWidth.narrow);
      expect(TranscriptWidth.parse('medium'), TranscriptWidth.medium);
      expect(TranscriptWidth.parse('wide'), TranscriptWidth.wide);
    });

    test('null（从没设置过）与脏值都落到 medium', () {
      expect(TranscriptWidth.parse(null), TranscriptWidth.medium);
      expect(TranscriptWidth.parse(''), TranscriptWidth.medium);
      expect(TranscriptWidth.parse('huge'), TranscriptWidth.medium);
    });
  });

  group('落盘与回读', () {
    test('改档会写进 LocalStorage，重建后仍是这一档', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);

      expect(c.read(transcriptWidthProvider), TranscriptWidth.medium,
          reason: '没设置过就是默认档');

      c.read(transcriptWidthProvider.notifier).set(TranscriptWidth.wide);
      expect(c.read(transcriptWidthProvider), TranscriptWidth.wide);
      expect(LocalStorage.instance.transcriptWidth, 'wide',
          reason: '存的是档名不是像素 —— 存像素会在改基准值时把用户卡在旧宽度');

      // 新容器 = App 重启，值必须还在。
      final again = ProviderContainer();
      addTearDown(again.dispose);
      expect(again.read(transcriptWidthProvider), TranscriptWidth.wide);
    });
  });

  group('真的渲染出来：输入框宽度跟着档走', () {
    /// 视口要够宽，否则三档都被 800 的测试窗口压平，测不出差别
    /// （宽档 928 会被窗口裁到 800）。
    const viewSize = Size(1400, 900);

    Widget harness() => ProviderScope(
          overrides: [
 chatPortsOverride,
            chatControllerProvider.overrideWith(
              () => ChatController(client: MockKernelClient()),
            ),
            kernelClientProvider.overrideWithValue(MockKernelClient()),
            settingsRepositoryProvider.overrideWithValue(
              FakeSettingsRepository(
                pages: const {'tools': FakeSettingsRepository.toolsSnapshot},
              ),
            ),
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
            home: const Scaffold(
              body: Center(child: ChatComposer(variant: ComposerVariant.empty)),
            ),
          ),
        );

    testWidgets('窄 / 中 / 宽三档 → 输入框三个宽度，且等于档位算出的值', (tester) async {
      // 测试会报错 对实际运行无影响
      tester.view.physicalSize = viewSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(harness());
      await tester.pump();

      // ⚠️ 从树里取容器**再改档**，而不是给 ProviderScope 塞不同初值 ——
      // 后者只能测"初值对不对"，测不到"改档后界面会不会跟着变"。用户是在
      // 设置页里点一下，靠的就是这条 reactive 路径。
      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatComposer)),
      );

      for (final w in TranscriptWidth.values) {
        container.read(transcriptWidthProvider.notifier).set(w);
        await tester.pump();

        expect(
          tester.getSize(find.byType(ComposerShell)).width,
          w.composerWidth,
          reason: '$w 档：外壳宽度没跟上设置',
        );
      }
    });
  });
}
