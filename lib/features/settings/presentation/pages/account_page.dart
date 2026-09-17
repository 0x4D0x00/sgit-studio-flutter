import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/settings/application/user_profile_controller.dart';

/// 账户设置页：头像、用户名等基本信息管理
/// 密码还未确定
class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _usernameController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // final bool _isEditingPassword = false;
  // final bool _obscureCurrentPassword = true;
  // final bool _obscureNewPassword = true;
  // final bool _obscureConfirmPassword = true;

  // String? _errorMessage;
  // final bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  //修改密码

  void _showUsernameDialog() {
    final l10n = AppLocalizations.of(context);
    final profile = ref.read(userProfileControllerProvider);
    _usernameController.text = profile.username;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountUsername),
        content: TextField(
          controller: _usernameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.accountUsernamePlaceholder,
          ),
          onSubmitted: (_) => _saveUsername(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: _saveUsername,
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUsername() async {
    final l10n = AppLocalizations.of(context);
    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accountUsernamePlaceholder)),
      );
      return;
    }

    // 更新用户名到状态管理
    await ref.read(userProfileControllerProvider.notifier).updateUsername(username);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.accountUpdateSuccess)),
    );
  }

  void _changeAvatar() {
    final l10n = AppLocalizations.of(context);
    // TODO: 实现头像选择功能
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.commonComingSoon)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileControllerProvider);
    final dividerColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.4);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Text(l10n.settingsAccount, style: theme.textTheme.headlineSmall),
        ),

        // 头像部分 - 点击头像中心图标触发修改
        _section(
          theme,
          l10n.accountAvatar,
          InkWell(
            onTap: _changeAvatar,
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person_rounded,
                    size: 36,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                // 中心相机图标
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        Divider(height: 1, thickness: 0.5, color: dividerColor),

        // 用户名部分 - 点击用户名直接弹出编辑对话框
        _section(
          theme,
          l10n.accountUsername,
          InkWell(
            onTap: _showUsernameDialog,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    profile.username,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
        ),

        Divider(height: 1, thickness: 0.5, color: dividerColor),

        // 密码部分

        // 错误提示
      ],
    );
  }

  Widget _section(ThemeData theme, String title, Widget child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, style: theme.textTheme.bodyLarge),
            child,
          ],
        ),
      );
}
