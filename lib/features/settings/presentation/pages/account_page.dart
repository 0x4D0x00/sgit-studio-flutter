import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sgit_studio_flutter/l10n/generated/app_localizations.dart';
import 'package:sgit_studio_flutter/design/tokens/app_spacing.dart';
import 'package:sgit_studio_flutter/features/auth/application/auth_controller.dart';
import 'package:sgit_studio_flutter/features/settings/application/user_profile_controller.dart';
import 'package:sgit_studio_flutter/features/settings/presentation/widgets/settings_section.dart';
import 'package:sgit_studio_flutter/ui/components/menu/app_menu.dart';

const _kMaxAvatarBytes = 5 * 1024 * 1024;

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final _fullNameController = TextEditingController();
  final _callYouController = TextEditingController();
  final _instructionsController = TextEditingController();
  String _workDescription = 'product_management';

  @override
  void dispose() {
    _fullNameController.dispose();
    _callYouController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _resetAvatar() async {
    final l10n = AppLocalizations.of(context);
    await ref.read(userProfileControllerProvider.notifier).resetAvatar();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.accountUpdateSuccess)),
    );
  }

  Future<void> _changeAvatar() async {
    final l10n = AppLocalizations.of(context);

    final result = await FilePicker.pickFiles(
      type: FileType.image,
    );
    if (result.isEmpty) return;

    final file = result.first;
    final bytes = await file.readAsBytes();

    if (bytes.length > _kMaxAvatarBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accountAvatarTooLarge)),
      );
      return;
    }

    final extension = file.extension ?? 'png';
    await ref
        .read(userProfileControllerProvider.notifier)
        .updateAvatar(bytes, extension);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.accountUpdateSuccess)),
    );
  }

  void _showUsernameDialog() {
    final l10n = AppLocalizations.of(context);
    final profile = ref.read(userProfileControllerProvider);
    final usernameController = TextEditingController(text: profile.username);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.accountUsername),
        content: TextField(
          controller: usernameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.accountUsernamePlaceholder,
          ),
          onSubmitted: (_) => _saveUsername(usernameController.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => _saveUsername(usernameController.text),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
  }

  Future<void> _saveUsername(String username) async {
    final l10n = AppLocalizations.of(context);
    final trimmed = username.trim();

    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accountUsernamePlaceholder)),
      );
      return;
    }

    await ref.read(userProfileControllerProvider.notifier).updateUsername(trimmed);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.accountUpdateSuccess)),
    );
  }

  void _notWired(String what) {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.commonNotWired(what)),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileControllerProvider);
    final dividerColor = theme.colorScheme.outlineVariant.withValues(alpha: 0.4);

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Profile section title
        SettingsSectionHeader(l10n.accountProfile),
        const SizedBox(height: AppSpacing.sm),

        // 头像行
        SettingsSectionRow(
          title: l10n.accountAvatar,
          trailing: SizedBox(
            width: 66,
            height: 66,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 6,
                  top: 6,
                  child: InkWell(
                    onTap: _changeAvatar,
                    borderRadius: BorderRadius.circular(32),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          backgroundImage: profile.avatarBytes != null
                              ? MemoryImage(profile.avatarBytes!)
                              : null,
                          child: profile.avatarBytes == null
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 32,
                                  color: theme.colorScheme.onPrimaryContainer,
                                )
                              : null,
                        ),
                        // Camera overlay
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
                // Close button for reset
                if (profile.avatarBytes != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: InkWell(
                      onTap: _resetAvatar,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: dividerColor,
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SettingsSectionDivider(),

        // 用户名
        SettingsSectionRow(
          title: l10n.accountUsername,
          trailing: InkWell(
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

        const SettingsSectionDivider(),

        // 工作描述-下拉菜单
        SettingsSectionRow(
          title: l10n.accountWorkDescription,
          trailing: AppMenuAnchor(
            entries: [
              AppMenuRadioGroup(
                values: const [
                  'product_management',
                  'engineering',
                  'human_resources',
                  'design',
                  'software_engineering',
                  'student',
                  'other',
                ],
                selected: _workDescription,
                labelOf: (value) {
                  switch (value) {
                    case 'product_management':
                      return l10n.accountWorkRoleProductManagement;
                    case 'engineering':
                      return l10n.accountWorkRoleEngineering;
                    case 'human_resources':
                      return l10n.accountWorkRoleHumanResources;
                    case 'design':
                      return l10n.accountWorkRoleDesign;
                    case 'software_engineering':
                      return l10n.accountWorkRoleSoftwareEngineering;
                    case 'student':
                      return l10n.accountWorkRoleStudent;
                    case 'other':
                      return l10n.accountWorkRoleOther;
                    default:
                      return value;
                  }
                },
                onSelect: (value) {
                  setState(() {
                    _workDescription = value;
                  });
                },
              ),
            ],
            align: AppMenuAlign.underEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    () {
                      switch (_workDescription) {
                        case 'product_management':
                          return l10n.accountWorkRoleProductManagement;
                        case 'engineering':
                          return l10n.accountWorkRoleEngineering;
                        case 'human_resources':
                          return l10n.accountWorkRoleHumanResources;
                        case 'design':
                          return l10n.accountWorkRoleDesign;
                        case 'software_engineering':
                          return l10n.accountWorkRoleSoftwareEngineering;
                        case 'student':
                          return l10n.accountWorkRoleStudent;
                        case 'other':
                          return l10n.accountWorkRoleOther;
                        default:
                          return _workDescription;
                      }
                    }(),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // 说明
        SettingsSectionHeader(l10n.accountInstructions),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.accountInstructionsDesc,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: TextField(
            controller: _instructionsController,
            maxLines: 5,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: l10n.accountInstructionsPlaceholder,
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              contentPadding: const EdgeInsets.all(AppSpacing.sm),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Account section
        SettingsSectionHeader(l10n.accountSectionTitle),
        const SizedBox(height: AppSpacing.sm),

        // 退出登录
        SettingsSectionRow(
          title: l10n.accountLogoutAll,
          trailing: FilledButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,
              side: BorderSide(color: dividerColor),
            ),
            child: Text(l10n.accountLogout),
          ),
        ),

        const SettingsSectionDivider(),

        // 删除账户
        SettingsSectionRow(
          title: l10n.accountDelete,
          trailing: FilledButton(
            onPressed: () => _notWired(l10n.accountDeleteButton),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.surface,
              foregroundColor: theme.colorScheme.onSurface,
            ),
            child: Text(l10n.accountDeleteButton),
          ),
        ),

        const SettingsSectionDivider(),

        // Organization ID
        SettingsSectionRow(
          title: l10n.accountOrgId,
          trailing: SelectableText(
            '7f58d316-46af-4a6c-a9b2-111da584d443',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
