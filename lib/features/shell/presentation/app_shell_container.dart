import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sgit_studio_flutter/features/auth/application/auth_controller.dart';
import 'package:sgit_studio_flutter/features/find/application/find_controller.dart';
import 'package:sgit_studio_flutter/features/find/presentation/find_host.dart';
import 'package:sgit_studio_flutter/features/chat/application/composer_focus_controller.dart';
import 'package:sgit_studio_flutter/features/chat/application/transcript_selection_pin.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/language_dialog.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:sgit_studio_flutter/layout/shell/side_rail.dart';
import 'package:sgit_studio_flutter/layout/shell/window_toolbar.dart';
import 'package:sgit_studio_flutter/platform/desktop_window.dart';
import 'package:sgit_studio_flutter/router/route_names.dart';
import 'package:sgit_studio_flutter/services/brand/brand_config.dart';
import 'package:sgit_studio_flutter/services/chat/chat_controller.dart';
import 'package:sgit_studio_flutter/services/theme/theme_controller.dart';
import 'package:sgit_studio_flutter/ui/components/dialogs/keyboard_shortcuts_dialog.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

import 'package:sgit_studio_flutter/features/chat/presentation/thread_title_bar.dart';
import 'package:sgit_studio_flutter/features/shell/presentation/nav_panel_container.dart';
import 'package:sgit_studio_flutter/features/settings/application/user_profile_controller.dart';
import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/layout/metrics/workspace_metrics.dart';
import 'package:sgit_studio_flutter/layout/panels/artifact_output_panel.dart';
import 'package:sgit_studio_flutter/layout/panels/output_panel.dart';
import 'package:sgit_studio_flutter/layout/shell/app_shell.dart';
import 'package:sgit_studio_flutter/services/layout/layout_controller.dart';
import 'package:sgit_studio_flutter/services/layout/transcript_width.dart';
import 'package:sgit_studio_flutter/ui/components/chat/artifact/artifact_viewer.dart';
import 'package:sgit_studio_flutter/design/extensions/app_skin.dart';

/// 外壳容器 —— 把布局状态与回调喂给纯组件 `AppShell`。
///
/// 这是**整个外壳唯一的 provider 订阅点**：`AppShell` / `NavPanel` / `OutputPanel`
/// 三个纯组件都不认识 Riverpod。
///
/// ⚠️ 它同时是**右侧面板的收口点**。面板里的产物属于某条会话，所以它的可见性
/// 由「布局状态」与「当前是不是会话页」两个条件共同决定 —— 只看前者，用户在
/// Projects 页会看到一个占着半屏、内容却来自那条会话的面板（见 [didUpdateWidget]）。
class AppShellContainer extends ConsumerStatefulWidget {
  const AppShellContainer({
    super.key,
    required this.child,
    required this.isConversation,
    this.showNav = true,
    this.activePath,
    this.activeNavId,
  });

  final Widget child;

  /// 是否挂左栏（图像 / 定时任务 / 资料库为 false）。
  final bool showNav;

  /// 当前路由路径，用来点亮最左侧工具列对应的项。
  final String? activePath;

  /// 当前路由是不是**会话页**（工作台）。
  ///
  /// 由路由层判定后注入 —— 不在这一层靠 `activeNavId == null` 反推：那个条件
  /// 是"没有激活的导航项"，而设置页、登录页同样满足，会把非会话页误判成会话页。
  /// 右侧面板只在会话页上有效，判错就会漏关（见 [didUpdateWidget]）。
  final bool isConversation;

  /// 当前激活的导航项 id（产物页 / 智能体子页 / null=工作台）。
  final String? activeNavId;

  @override
  ConsumerState<AppShellContainer> createState() => _AppShellContainerState();
}

class _AppShellContainerState extends ConsumerState<AppShellContainer> {
  /// 路由访问历史（go_router 的 go 是替换式导航，没有现成的前进/后退栈）。
  final List<String> _history = [];
  int _cursor = -1;

  /// 后退/前进触发的跳转不该再往历史里追加。
  bool _replaying = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final loc = GoRouterState.of(context).uri.toString();
    if (_replaying) {
      _replaying = false;
      return;
    }
    if (_cursor >= 0 && _history[_cursor] == loc) return;
    // 在历史中间导航：丢弃「前进」分支。
    _history.removeRange(_cursor + 1, _history.length);
    _history.add(loc);
    _cursor = _history.length - 1;
  }

  void _go(int delta) {
    final next = _cursor + delta;
    if (next < 0 || next >= _history.length) return;
    setState(() {
      _cursor = next;
      _replaying = true;
    });
    context.go(_history[next]);
  }

  final _toolbarKey = GlobalKey();

  /// 点菜单之前的焦点（输入框 / 会话正文的选区）。
  ///
  /// 点触发器、悬停菜单项都会把焦点抢走，菜单项真正被点下时
  /// `primaryFocus` 早已是菜单自己 —— 编辑动作必须认这里记下的那个。
  FocusNode? _editTarget;

  /// 工具行里任何一次按下都先记账（此刻触发器还没来得及拿焦点）。
  /// 焦点已经在菜单 / 触发器自己身上就不覆盖，免得把真正的目标冲掉。
  void _captureEditTarget() {
    final f = FocusManager.instance.primaryFocus;
    final ctx = f?.context;
    if (f == null || ctx == null) return;
    final bar = _toolbarKey.currentContext;
    var inToolbar = false;
    ctx.visitAncestorElements((e) {
      if (e == bar) inToolbar = true;
      return !inToolbar;
    });
    if (!inToolbar) {
      _editTarget = f;
      // 目标是会话正文就钉住它的选区：点菜单让正文失焦，选区却要留着，
      // 直到粘贴（正文焦点作废）才放开。
      transcriptSelectionPin.value = f == transcriptSelectionPin.node;
      composerSelectionPin.value = f == composerSelectionPin.node;
    }
  }

  /// 焦点去了输入框 = 正文选区的使命结束（粘贴走的也是这条路）；
  /// 焦点去了正文 = 输入框的选区该放开。
  void _releasePinOnEditableFocus() {
    final f = FocusManager.instance.primaryFocus;
    if (transcriptSelectionPin.value && _isEditable(f)) {
      transcriptSelectionPin.value = false;
    }
    if (composerSelectionPin.value && f == transcriptSelectionPin.node) {
      composerSelectionPin.value = false;
    }
  }

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_releasePinOnEditableFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_releasePinOnEditableFocus);
    super.dispose();
  }

  bool _isEditable(FocusNode? f) =>
      f?.context?.findAncestorWidgetOfExactType<EditableText>() != null;

  /// 把记下的焦点控件（输入框 / 可选文本）当作菜单动作的目标。
  ///
  /// - 粘贴只对输入框有意义：目标不是输入框（比如会话正文）就送去输入框，
  ///   焦点也留在输入框里，接着做别的操作。
  /// - 其余动作做完把焦点还给原目标 —— 否则全选之后焦点丢了，
  ///   再点「复制」就找不到选区。
  void _editAction(Intent intent) {
    var target = _editTarget;
    if (target == null || target.context == null) {
      target = FocusManager.instance.primaryFocus;
    }

    if (intent is PasteTextIntent && !_isEditable(target)) {
      ref.read(composerFocusProvider.notifier).requestFocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = FocusManager.instance.primaryFocus?.context;
        if (ctx == null || !_isEditable(FocusManager.instance.primaryFocus)) {
          return;
        }
        final input = FocusManager.instance.primaryFocus!;
        Actions.maybeInvoke(ctx, intent);
        // 正文的焦点 / 选区到此作废；此后的编辑动作都认输入框。
        transcriptSelectionPin.value = false;
        _editTarget = input;
        // 菜单收起时可能把焦点还给之前的控件，再等一帧拉回输入框。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (input.context != null) input.requestFocus();
        });
        WidgetsBinding.instance.scheduleFrame();
      });
      WidgetsBinding.instance.scheduleFrame();
      return;
    }

    final ctx = target?.context;
    if (ctx == null) return;
    Actions.maybeInvoke(ctx, intent);
    // 菜单收起是在 onPressed 之后，焦点要等它收完再还。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (target!.context != null && target.canRequestFocus) target.requestFocus();
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void didUpdateWidget(AppShellContainer old) {
    super.didUpdateWidget(old);
    // 离开会话页 → 真的关掉右侧面板（不只是藏起来）。
    //
    // ⚠️ 判据是**离开**会话页，而不是"路由变了"。产物页点一张卡片的顺序是
    // `showArtifact()` 之后才 `go(home)` —— 打开面板那一刻人还站在产物页上。
    // 按"路由变了"关，会在跳回会话的路上把它当场关掉。
    if (old.isConversation && !widget.isConversation) {
      // 延到帧后再改状态：本回调跑在 build 之前，此刻动 provider 会把正在
      // 构建的这棵树标脏。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(layoutControllerProvider.notifier).closeOutput();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final layout = ref.watch(layoutControllerProvider);
    final ctrl = ref.read(layoutControllerProvider.notifier);
    // 中栏宽度档位。布局是 5 个横切状态之一，这一层是它在外壳上的唯一订阅点。
    final contentMaxWidth = ref.watch(transcriptWidthProvider).contentMaxWidth;

    final artifact = layout.activeArtifact;

    // 根据是否有活跃产物选择右侧面板内容
    final outputPanel = artifact != null
        ? ArtifactOutputPanel(
            artifact: artifact,
            copyLabel: l10n.chatCopy,
            closeLabel: l10n.chatArtifactClose,
            onClose: ctrl.closeOutput,
            onCopy: () => copyArtifact(context, artifact, l10n.chatCopied),
            child: ArtifactViewer(artifact: artifact),
          )
        : OutputPanel(
            title: l10n.shellOutputTitle,
            emptyText: l10n.shellOutputEmpty,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        // 根据可用宽度动态计算右侧面板的安全宽度
        // 总宽度 - 左栏宽度(如果展开) - 中栏最小宽度 = 右侧面板可用空间
        final totalWidth = constraints.maxWidth;
        final navActualWidth = widget.showNav && layout.navExpanded
            ? layout.navWidth
            : 0;
        final minCenterWidth = contentMaxWidth * 0.6; // 中栏至少保留 70% 的内容宽度
        final availableForOutput = totalWidth - navActualWidth - minCenterWidth;
        final safeOutputWidth = layout.outputWidth.clamp(
          WorkspaceMetrics.outputMinWidth,
          availableForOutput.clamp(
            WorkspaceMetrics.outputMinWidth,
            WorkspaceMetrics.outputMaxWidth,
          ),
        );

        final rail = SideRail(
          items: [
            SideRailItem(
              icon: Icons.home_rounded,
              tooltip: l10n.navNewChat,
              // 首页 = 左栏那一族页面（会话 / 历史 / 输出物 / Projects / Customize）。
              selected: widget.showNav,
              onTap: () => context.go(RouteNames.home),
            ),
            SideRailItem(
              icon: Icons.photo_library_outlined,
              tooltip: l10n.railImages,
              selected: widget.activePath == RouteNames.images,
              onTap: () => context.go(RouteNames.images),
            ),
            SideRailItem(
              icon: Icons.schedule_rounded,
              tooltip: l10n.railTasks,
              selected: widget.activePath == RouteNames.tasks,
              onTap: () => context.go(RouteNames.tasks),
            ),
            SideRailItem(
              icon: Icons.local_library_outlined,
              tooltip: l10n.railLibrary,
              selected: widget.activePath == RouteNames.library,
              onTap: () => context.go(RouteNames.library),
            ),
            SideRailItem(
              icon: Icons.more_horiz_rounded,
              tooltip: l10n.railMore,
              menu: [
                AppMenuAction(
                  icon: Icons.settings_outlined,
                  label: l10n.navSettings,
                  onTap: () => showSettingsDialog(context),
                ),
                AppMenuAction(
                  icon: Icons.language,
                  label: l10n.settingsLanguage,
                  onTap: () => showLanguageDialog(context),
                ),
              ],
            ),
          ],
          bottom: _buildUserAvatar(context, ref),
        );

        void notWired(String what) =>
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.commonNotWired(what)),
                duration: const Duration(seconds: 1),
              ),
            );
        // 还没有对应功能的菜单项：只弹「功能待接」。
        AppMenuAction stub(String label, {String? shortcut}) => AppMenuAction(
          label: label,
          shortcut: shortcut,
          onTap: () => notWired(label),
        );
        final themeCtrl = ref.read(themeControllerProvider.notifier);

        void newChat() {
          ref.read(chatControllerProvider.notifier).newChat();
          context.go(RouteNames.home);
        }

        // 与左栏的搜索按钮是同一个弹窗（左栏收起 / 无左栏时也能唤出），快捷键 Ctrl+K。
        void openSearch() =>
            const NavPanelContainer().openSearch(context, ref);

        // 关闭当前页面（回到工作台）；已经没有可关的页面就最小化客户端。
        void closePage() {
          if (widget.activePath == RouteNames.home) {
            minimizeClient();
          } else {
            context.go(RouteNames.home);
          }
        }

        final menus = [
          WindowMenu(
            label: l10n.menuFile,
            entries: [
              AppMenuAction(
                label: l10n.menuNewWindow,
                onTap: openNewClientWindow,
              ),
              AppMenuAction(
                label: l10n.navNewChat,
                shortcut: 'Ctrl+N',
                onTap: newChat,
              ),
              AppMenuAction(
                label: l10n.menuNewProject,
                onTap: () => context.go(RouteNames.projects),
              ),
              const AppMenuDivider(),
              stub(l10n.menuOpenFolder, shortcut: 'Ctrl+O'),
              AppMenuAction(
                label: l10n.navSettings,
                shortcut: 'Ctrl+,',
                onTap: () => showSettingsDialog(context),
              ),
              const AppMenuDivider(),
              AppMenuAction(
                label: l10n.menuClose,
                shortcut: 'Ctrl+W',
                onTap: closePage,
              ),
              const AppMenuDivider(),
              AppMenuAction(
                label: l10n.navLogout,
                onTap: () => ref.read(authControllerProvider.notifier).logout(),
              ),
              AppMenuAction(
                label: l10n.menuQuitBrand(BrandConfig.instance.name),
                shortcut: 'Ctrl+Q',
                onTap: quitClient,
              ),
            ],
          ),
          WindowMenu(
            label: l10n.menuEdit,
            entries: [
              AppMenuAction(
                label: l10n.editUndo,
                shortcut: 'Ctrl+Z',
                onTap: () => _editAction(
                  const UndoTextIntent(SelectionChangedCause.toolbar),
                ),
              ),
              AppMenuAction(
                label: l10n.editRedo,
                shortcut: 'Ctrl+Y',
                onTap: () => _editAction(
                  const RedoTextIntent(SelectionChangedCause.toolbar),
                ),
              ),
              const AppMenuDivider(),
              AppMenuAction(
                label: l10n.editCut,
                shortcut: 'Ctrl+X',
                onTap: () => _editAction(
                  const CopySelectionTextIntent.cut(
                    SelectionChangedCause.toolbar,
                  ),
                ),
              ),
              AppMenuAction(
                label: l10n.editCopy,
                shortcut: 'Ctrl+C',
                onTap: () => _editAction(CopySelectionTextIntent.copy),
              ),
              AppMenuAction(
                label: l10n.editPaste,
                shortcut: 'Ctrl+V',
                onTap: () => _editAction(
                  const PasteTextIntent(SelectionChangedCause.toolbar),
                ),
              ),
              AppMenuAction(
                label: l10n.editDelete,
                onTap: () =>
                    _editAction(const DeleteCharacterIntent(forward: true)),
              ),
              const AppMenuDivider(),
              AppMenuAction(
                label: l10n.editSelectAll,
                shortcut: 'Ctrl+A',
                onTap: () => _editAction(
                  const SelectAllTextIntent(SelectionChangedCause.toolbar),
                ),
              ),
            ],
          ),
          WindowMenu(
            label: l10n.menuView,
            entries: [
              AppMenuAction(
                label: l10n.menuToggleSidebar,
                shortcut: 'Ctrl+Shift+S',
                onTap: ctrl.toggleNav,
              ),
              stub(l10n.menuOpenTerminal, shortcut: 'Ctrl+`'),
              stub(l10n.menuSwitchChatTabs, shortcut: 'Alt+Ctrl+B'),
              const AppMenuDivider(),
              AppMenuSubmenu(
                label: l10n.menuBrowser,
                entries: [stub(l10n.menuBrowser)],
              ),
              const AppMenuDivider(),
              AppMenuAction(
                label: l10n.menuFind,
                shortcut: 'Ctrl+F',
                onTap: ref.read(findControllerProvider.notifier).show,
              ),
              const AppMenuDivider(),
              AppMenuAction(
                label: l10n.toolbarBack,
                shortcut: 'Ctrl+[',
                enabled: _cursor > 0,
                onTap: () => _go(-1),
              ),
              AppMenuAction(
                label: l10n.toolbarForward,
                enabled: _cursor < _history.length - 1,
                onTap: () => _go(1),
              ),
              const AppMenuDivider(),
              AppMenuAction(
                label: l10n.menuZoomIn,
                shortcut: 'Ctrl+Shift+=',
                onTap: () => themeCtrl.bumpFontScale(1),
              ),
              AppMenuAction(
                label: l10n.menuZoomOut,
                shortcut: 'Ctrl+-',
                onTap: () => themeCtrl.bumpFontScale(-1),
              ),
              AppMenuAction(
                label: l10n.menuActualSize,
                shortcut: 'Ctrl+0',
                onTap: themeCtrl.resetFontScale,
              ),
              const AppMenuDivider(),
              AppMenuAction(
                label: l10n.menuFullScreen,
                shortcut: 'F11',
                onTap: toggleFullScreen,
              ),
            ],
          ),
          WindowMenu(
            label: l10n.menuHelp,
            entries: [
              stub(l10n.helpDocs),
              AppMenuAction(
                label: l10n.navKeyboardShortcuts,
                shortcut: 'Ctrl+/',
                onTap: () => showKeyboardShortcutsDialog(context),
              ),
              stub(l10n.helpWhatsNew),
              const AppMenuDivider(),
              stub(l10n.helpTroubleshoot),
              stub(l10n.helpSystemStatus),
              stub(l10n.helpFeedback),
              const AppMenuDivider(),
              stub(l10n.helpTaskManager),
              stub(l10n.helpStartTrace),
              const AppMenuDivider(),
              stub(l10n.helpCheckUpdates),
              stub(l10n.navAboutBrand(BrandConfig.instance.name)),
            ],
          ),
        ];

        final shell = AppShell(
          rail: rail,
          showNav: widget.showNav,
          toolbarBuilder: (toggleNav) => Listener(
            key: _toolbarKey,
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _captureEditTarget(),
            child: WindowToolbar(
              canGoBack: _cursor > 0,
              canGoForward: _cursor < _history.length - 1,
              onBack: () => _go(-1),
              onForward: () => _go(1),
              onToggleNav: toggleNav,
              navExpanded: layout.navExpanded,
              backTooltip: l10n.toolbarBack,
              forwardTooltip: l10n.toolbarForward,
              toggleNavTooltip: layout.navExpanded
                  ? l10n.shellCollapseNav
                  : l10n.shellExpandNav,
              menus: menus,
            ),
          ),
          navExpanded: layout.navExpanded,
          navWidth: layout.navWidth,
          // ⚠️ 非会话页恒为 false。关状态是 post-frame 的（见 didUpdateWidget），
          // 只靠它会让离开会话页的那一帧仍把面板画出来 —— 肉眼就是"闪一下"。
          outputExpanded: widget.isConversation && layout.outputExpanded,
          outputWidth: safeOutputWidth,
          // 只有会话页吃「转录宽度」档位。其余页（技能库 / 设置 / 产物 / Projects）
          // 是铺卡片或表格的，限宽会让大窗口右半边整片空着 —— 传 0 表示不设上限。
          contentMaxWidth: widget.isConversation ? contentMaxWidth : 0,
          onToggleNav: ctrl.toggleNav,
          onToggleOutput: ctrl.toggleOutput,
          onNavWidthChanged: ctrl.setNavWidth,
          onOutputWidthChanged: ctrl.setOutputWidth,
          nav: NavPanelContainer(activeNavId: widget.activeNavId),
          output: outputPanel,
          headerTitle: widget.isConversation ? const ThreadTitleBar() : null,
          child: widget.child,
        );

        // 菜单里写的快捷键要有真实按键。输入框 / 选区自带 Ctrl+Z/X/C/V/A，不用再绑；
        // Flutter 在 Windows/Linux 只认 Ctrl+Shift+Z 重做，Ctrl+Y 这里补上。
        // 还没有功能的项和菜单一样只弹「功能待接」。
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyN, control: true): newChat,
            const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
                notWired(l10n.menuOpenFolder),
            const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
                showSettingsDialog(context),
            const SingleActivator(LogicalKeyboardKey.keyW, control: true): closePage,
            const SingleActivator(LogicalKeyboardKey.keyQ, control: true): quitClient,
            const SingleActivator(LogicalKeyboardKey.keyY, control: true): () {
              final ctx = FocusManager.instance.primaryFocus?.context;
              if (ctx == null) return;
              Actions.maybeInvoke(
                ctx,
                const RedoTextIntent(SelectionChangedCause.keyboard),
              );
            },
            // 视图
            const SingleActivator(LogicalKeyboardKey.keyS, control: true, shift: true):
                ctrl.toggleNav,
            const SingleActivator(LogicalKeyboardKey.backquote, control: true): () =>
                notWired(l10n.menuOpenTerminal),
            const SingleActivator(LogicalKeyboardKey.keyB, control: true, alt: true): () =>
                notWired(l10n.menuSwitchChatTabs),
            // 查找（页内）与搜索（聊天 / 项目 / 产物的命令面板）是两件事。
            const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                ref.read(findControllerProvider.notifier).show,
            const SingleActivator(LogicalKeyboardKey.keyK, control: true):
                openSearch,
            const SingleActivator(LogicalKeyboardKey.bracketLeft, control: true): () =>
                _go(-1),
            const SingleActivator(LogicalKeyboardKey.equal, control: true, shift: true): () =>
                themeCtrl.bumpFontScale(1),
            const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
                themeCtrl.bumpFontScale(1),
            const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true): () =>
                themeCtrl.bumpFontScale(1),
            const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
                themeCtrl.bumpFontScale(-1),
            const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true): () =>
                themeCtrl.bumpFontScale(-1),
            const SingleActivator(LogicalKeyboardKey.digit0, control: true):
                themeCtrl.resetFontScale,
            const SingleActivator(LogicalKeyboardKey.f11): toggleFullScreen,
            // 帮助
            const SingleActivator(LogicalKeyboardKey.slash, control: true): () =>
                showKeyboardShortcutsDialog(context),
          },
          child: FindHost(child: shell),
        );
      },
    );
  }

  /// 构建用户头像，显示在 SideRail 底部。
  Widget _buildUserAvatar(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileControllerProvider);
    final skin = AppSkin.of(context);
    final userMenu = NavPanelContainer.buildUserMenu(context, ref);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(WorkspaceMetrics.navItemRadius),
      child: AppMenuAnchor(
        align: AppMenuAlign.above,
        entries: userMenu,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: skin.navItemActive,
            backgroundImage: userProfile.avatarBytes != null
                ? MemoryImage(userProfile.avatarBytes!)
                : null,
            child: userProfile.avatarBytes == null
                ? Icon(Icons.person_rounded, size: 18, color: skin.text)
                : null,
          ),
        ),
      ),
    );
  }
}
