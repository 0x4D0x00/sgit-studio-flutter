import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/brand/brand_assets.dart';
import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/network/ffi/sgit_request_ffi.dart' show Captcha;
import '../../../core/platform/window_bar/app_window_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/layout/layered_scaffold.dart';
import '../auth_controller.dart';
import '../services/auth_service.dart';

/// 登录页尺寸令牌——1:1 对齐 sgit-studio 登录页设计稿(`features/Auth/SignIn/style.ts`),
/// 与 8pt 栅格无关,故就近收在本页,不污染全局 [AppSpacing]。
class _LoginMetrics {
  _LoginMetrics._();

  /// 外框:内缩 8px 露出底图 + 16 圆角。
  static const double frameInset = 8;
  static const double frameRadius = 16;

  /// 卡片:480 宽、16 圆角、56/40 内边距、右侧 40 边距。
  static const double cardWidth = 480;
  static const double cardRadius = 16;
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(horizontal: 40, vertical: 56);
  static const double cardEndPadding = 40;

  /// 品牌 logo:盾牌 68x81 + 字标 118x36，间距 10。
  static const double markWidth = 68;
  static const double markHeight = 81;
  static const double wordmarkWidth = 118;
  static const double wordmarkHeight = 36;
  static const double brandGap = 10;

  /// 表单:字段高 46、圆角 14、字段间距 24、与 logo 间距 32。
  static const double fieldHeight = 46;
  static const double fieldRadius = 14;
  static const double fieldGap = 24;
  static const double formTop = 32;

  /// 验证码图片框宽 96，与输入框间距 12。
  static const double captchaWidth = 96;
  static const double captchaGap = 12;

  /// 登录按钮:高 54、圆角 14、20/700、字距 0.2em。
  static const double submitHeight = 54;
  static const double submitRadius = 14;
  static const double submitFontSize = 20;
  static const double submitLetterSpacing = 4; // 0.2em @ 20px
  static const double submitTop = 24;
}

/// 登录页。手机号/用户名 + 密码 + 图形验证码（走 FFI → sgcode login_v2）。
///
/// 排版对齐 sgit-studio 登录页:L1 铺全屏品牌背景图(cover) → 内缩 8px 的半透明外框
/// (窗口 bar 在框内，与外框同色无缝) → 靠右垂直居中的 480 宽登录卡片。
///
/// 网络侧不经 gateway:验证码/登录全部委托 [AuthService] → `libsgit_ffi.so`
/// (sgcode 的 sgit-ffi crate)，Dart 只传参拿 JSON。
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _captchaCode = TextEditingController();

  Captcha? _captcha;
  bool _captchaLoading = false;
  bool _obscurePassword = true;

  /// 本地必填校验提示(提交时才亮)。
  String? _localError;

  @override
  void initState() {
    super.initState();
    // Web 端趁用户填账号密码的时间，把 sgit_crypto WASM 实例化 + 会话临时密钥先算好，
    // 别落在点「登录」之后。桌面端是空实现。
    // 预热失败不在这里报错:真正加密前 encryptEnvelope 会再 await 一次 warmup，
    // 届时的异常会走登录失败提示。这里只是不让它变成 unhandled rejection。
    const AuthService().warmupCrypto().onError((_, _) {});
    _loadCaptcha();
  }

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _captchaCode.dispose();
    super.dispose();
  }

  Future<void> _loadCaptcha() async {
    setState(() => _captchaLoading = true);
    try {
      final c = await const AuthService().fetchCaptcha();
      if (!mounted) return;
      setState(() {
        _captcha = c;
        _captchaLoading = false;
        _localError = null;
      });
    } catch (_) {
      if (!mounted) return;
      // 拉不到验证码多半是后端不通(私有化未设 SGIT_API_BASE_URL 时会打默认端点池)，
      // 必须显式报出来——否则只剩一个空框，用户/运维无从判断。
      setState(() {
        _captcha = null;
        _captchaLoading = false;
        _localError = AppLocalizations.of(context).loginCaptchaFailed;
      });
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final id = _identifier.text.trim();
    final pwd = _password.text;
    final code = _captchaCode.text.trim();

    final missing = id.isEmpty
        ? l10n.loginIdentifierRequired
        : pwd.isEmpty
            ? l10n.loginPasswordRequired
            : code.isEmpty
                ? l10n.loginCaptchaRequired
                : null;
    if (missing != null) {
      setState(() => _localError = missing);
      return;
    }
    setState(() => _localError = null);

    final ok = await ref.read(authControllerProvider.notifier).login(
          identifier: id,
          password: pwd,
          captchaId: _captcha?.captchaId ?? '',
          captchaCode: code,
        );
    if (!ok) {
      // 登录失败刷新验证码（可能是验证码已消费）
      _captchaCode.clear();
      _loadCaptcha();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayeredScaffold(
      // L1 · 全屏品牌背景图(cover)。L0 底色 / L2 霓虹保持全局默认，不在本页改动。
      backgroundImage: BrandAssets.image(BrandAssets.loginBg),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Padding(
          padding: const EdgeInsets.all(_LoginMetrics.frameInset),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_LoginMetrics.frameRadius),
            // 外框:统一半透明色、无模糊——窗口 bar 在框内且自身透明，视为一整块。
            child: ColoredBox(
              color: theme.colorScheme.surface
                  .withValues(alpha: isDark ? 0.22 : 0.12),
              child: Column(
                children: [
                  const AppWindowBar(),
                  Expanded(child: _cardArea(theme, isDark)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 卡片区:靠右 + 垂直居中。窄屏(< 卡片宽 + 边距)时退化为居中，避免被裁。
  Widget _cardArea(ThemeData theme, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final roomy = constraints.maxWidth >
            _LoginMetrics.cardWidth + _LoginMetrics.cardEndPadding * 2;
        return Align(
          alignment: roomy ? Alignment.centerRight : Alignment.center,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: roomy ? _LoginMetrics.cardEndPadding : AppSpacing.md,
            ),
            child: SingleChildScrollView(
              child: _card(theme, isDark),
            ),
          ),
        );
      },
    );
  }

  Widget _card(ThemeData theme, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final error = _localError ?? auth.error;

    return Container(
      width: _LoginMetrics.cardWidth,
      padding: _LoginMetrics.cardPadding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_LoginMetrics.cardRadius),
        // 亮色用纯表面白；暗色用略浅的表面变体(而非近黑)，与 studio 一致。
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.surface,
        boxShadow: const [
          BoxShadow(color: AppColors.loginCardShadow, blurRadius: 25, offset: Offset(0, 20)),
          BoxShadow(color: AppColors.loginCardShadow, blurRadius: 10, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brand(),
          const SizedBox(height: _LoginMetrics.formTop),
          _field(
            theme: theme,
            controller: _identifier,
            hint: l10n.loginIdentifierPlaceholder,
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: _LoginMetrics.fieldGap),
          _field(
            theme: theme,
            controller: _password,
            hint: l10n.loginPasswordPlaceholder,
            icon: Icons.vpn_key_outlined,
            obscure: _obscurePassword,
            textInputAction: TextInputAction.next,
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 18,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: _LoginMetrics.fieldGap),
          _captchaRow(theme, l10n),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              error,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: _LoginMetrics.submitTop),
          _submitButton(l10n, auth.loading),
        ],
      ),
    );
  }

  /// 品牌行:盾牌 mark + 字标 wordmark 居中。
  Widget _brand() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image(
          image: BrandAssets.image(BrandAssets.loginMark),
          width: _LoginMetrics.markWidth,
          height: _LoginMetrics.markHeight,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: _LoginMetrics.brandGap),
        Image(
          image: BrandAssets.image(BrandAssets.loginWordmark),
          width: _LoginMetrics.wordmarkWidth,
          height: _LoginMetrics.wordmarkHeight,
          fit: BoxFit.contain,
        ),
      ],
    );
  }

  /// 统一字段样式:高 46、圆角 14、前缀图标、浅底无描边。
  Widget _field({
    required ThemeData theme,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputAction? textInputAction,
  }) {
    return SizedBox(
      height: _LoginMetrics.fieldHeight,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        textInputAction: textInputAction,
        onSubmitted: (_) => _submit(),
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          suffixIcon: suffix,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          border: _fieldBorder(theme, focused: false),
          enabledBorder: _fieldBorder(theme, focused: false),
          focusedBorder: _fieldBorder(theme, focused: true),
        ),
      ),
    );
  }

  OutlineInputBorder _fieldBorder(ThemeData theme, {required bool focused}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(_LoginMetrics.fieldRadius),
        borderSide: BorderSide(
          color: focused ? theme.colorScheme.primary : theme.dividerColor,
          width: focused ? 1.5 : 1,
        ),
      );

  /// 验证码行:输入框(弹性) + 96px 图片框(点击换一张)。
  Widget _captchaRow(ThemeData theme, AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _field(
            theme: theme,
            controller: _captchaCode,
            hint: l10n.loginCaptchaPlaceholder,
            icon: Icons.verified_user_outlined,
            textInputAction: TextInputAction.done,
          ),
        ),
        const SizedBox(width: _LoginMetrics.captchaGap),
        _captchaImage(l10n),
      ],
    );
  }

  /// 后端验证码 SVG 里写死了 `font-family="Georgia, 'Times New Roman', serif"`。
  /// Web(CanvasKit)不认系统字体，这些名字一个都解析不到 → **字母整个不渲染**；而干扰线
  /// 和噪点是纯矢量图形照常画出，所以看着像"验证码空白"（实际是有图无字）。
  /// 统一改写成随包字体族，保证桌面/Web 都出字。
  static final RegExp _svgFontFamilyRe = RegExp('font-family="[^"]*"');

  String _withBundledFont(String svg) => svg.replaceAll(
        _svgFontFamilyRe,
        'font-family="${AppTypography.fontFamily}"',
      );

  Widget _captchaImage(AppLocalizations l10n) {
    return Tooltip(
      message: l10n.loginCaptchaRefresh,
      child: InkWell(
        onTap: _captchaLoading ? null : _loadCaptcha,
        borderRadius: BorderRadius.circular(_LoginMetrics.fieldRadius),
        child: Opacity(
          opacity: _captchaLoading ? 0.6 : 1,
          child: Container(
            width: _LoginMetrics.captchaWidth,
            height: _LoginMetrics.fieldHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_LoginMetrics.fieldRadius),
              border: Border.all(color: AppColors.loginCaptchaBorder),
              color: AppColors.loginCaptchaBg,
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            // flutter_svg 只做矢量绘制、不执行脚本，故 SVG 直绘不存在 studio 侧
            // 用 <img> data URI 规避的那类注入面。
            child: (_captcha != null && _captcha!.svg.isNotEmpty)
                ? SvgPicture.string(_withBundledFont(_captcha!.svg),
                    fit: BoxFit.contain)
                : const Icon(Icons.refresh_rounded, size: 18),
          ),
        ),
      ),
    );
  }

  /// 登录按钮:品牌蓝渐变(173deg)，高 54、圆角 14、20/700、字距 0.2em。
  Widget _submitButton(AppLocalizations l10n, bool loading) {
    return Opacity(
      opacity: loading ? 0.92 : 1,
      child: Container(
        height: _LoginMetrics.submitHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_LoginMetrics.submitRadius),
          gradient: const LinearGradient(
            // 173deg ≈ 自上而下、略向右倾。
            begin: Alignment(-0.12, -1),
            end: Alignment(0.12, 1),
            colors: [
              AppColors.loginSubmitGradientStart,
              AppColors.loginSubmitGradientEnd,
            ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : _submit,
            borderRadius: BorderRadius.circular(_LoginMetrics.submitRadius),
            child: Center(
              child: loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l10n.loginButton,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: _LoginMetrics.submitFontSize,
                        fontWeight: FontWeight.w700,
                        letterSpacing: _LoginMetrics.submitLetterSpacing,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
