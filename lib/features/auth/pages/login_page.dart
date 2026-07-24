import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/network/ffi/sgit_request_ffi.dart' show Captcha;
import '../../../core/platform/window_bar/app_window_bar.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/layout/layered_scaffold.dart';
import '../../../shared/widgets/animated_border_text_field.dart';
import '../../../shared/widgets/glass_card.dart';
import '../auth_controller.dart';
import '../services/auth_service.dart';

/// 登录页。手机号/用户名 + 密码 + 图形验证码（走 FFI → sgcode login_v2）。
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

  @override
  void initState() {
    super.initState();
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
      final c = await Future(() => const AuthService().fetchCaptcha());
      if (!mounted) return;
      setState(() {
        _captcha = c;
        _captchaLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _captcha = null;
        _captchaLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    final id = _identifier.text.trim();
    final pwd = _password.text;
    final code = _captchaCode.text.trim();
    if (id.isEmpty || pwd.isEmpty || code.isEmpty) return;
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);

    return LayeredScaffold(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            const AppWindowBar(),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: GlassCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'SGiT Nexus',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AnimatedBorderTextField(
                          controller: _identifier,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.person_outline_rounded),
                            hintText: '手机号 / 用户名',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        AnimatedBorderTextField(
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                            hintText: '密码',
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // 图形验证码：输入框 + 图片
                        Row(
                          children: [
                            Expanded(
                              child: AnimatedBorderTextField(
                                controller: _captchaCode,
                                onSubmitted: (_) => _submit(),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.verified_outlined),
                                  hintText: '验证码',
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _buildCaptchaImage(theme),
                          ],
                        ),
                        if (auth.error != null) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            auth.error!,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.error),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xl),
                        FilledButton(
                          onPressed: auth.loading ? null : _submit,
                          child: auth.loading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(l10n.loginButton),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptchaImage(ThemeData theme) {
    return InkWell(
      onTap: _captchaLoading ? null : _loadCaptcha,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        width: 110,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: theme.dividerColor),
          color: Colors.white,
        ),
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        child: _captchaLoading
            ? const SizedBox(
                width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : (_captcha != null && _captcha!.svg.isNotEmpty)
                ? SvgPicture.string(_captcha!.svg, fit: BoxFit.contain)
                : const Icon(Icons.refresh_rounded),
      ),
    );
  }
}
