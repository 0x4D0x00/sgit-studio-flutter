import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../users_controller.dart';

/// 账号注册弹窗。用户名/手机号/邮箱至少填一个，昵称可选。
class RegisterUserDialog extends ConsumerStatefulWidget {
  const RegisterUserDialog({super.key});

  @override
  ConsumerState<RegisterUserDialog> createState() => _RegisterUserDialogState();
}

class _RegisterUserDialogState extends ConsumerState<RegisterUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _nickname = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _phone.dispose();
    _email.dispose();
    _nickname.dispose();
    super.dispose();
  }

  bool get _hasAnyIdentifier =>
      _username.text.trim().isNotEmpty ||
      _phone.text.trim().isNotEmpty ||
      _email.text.trim().isNotEmpty;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasAnyIdentifier) {
      setState(() => _error = '用户名、手机号、邮箱至少填写一个');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(usersControllerProvider.notifier).register(
            username: _username.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim(),
            nickname: _nickname.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = '注册失败：$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('注册新账号'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(_username, '用户名', Icons.person_outline_rounded),
              const SizedBox(height: AppSpacing.sm),
              _field(_phone, '手机号', Icons.phone_outlined,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: AppSpacing.sm),
              _field(_email, '邮箱', Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: AppSpacing.sm),
              _field(_nickname, '昵称（可选）', Icons.badge_outlined),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('注册'),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        isDense: true,
      ),
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
    );
  }
}
