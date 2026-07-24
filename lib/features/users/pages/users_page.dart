import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/glass_card.dart';
import '../models/app_user.dart';
import '../users_controller.dart';
import 'widgets/register_user_dialog.dart';
import 'widgets/user_table.dart';

/// 用户管理页：头部（面包屑/标题/说明/工具栏）+ 用户列表。
class UsersPage extends ConsumerStatefulWidget {
  const UsersPage({super.key});

  @override
  ConsumerState<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends ConsumerState<UsersPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<AppUser> _filter(List<AppUser> users) {
    if (_query.isEmpty) return users;
    final q = _query.toLowerCase();
    return users.where((u) {
      return (u.userName ?? '').toLowerCase().contains(q) ||
          (u.realName ?? '').toLowerCase().contains(q) ||
          (u.nickname ?? '').toLowerCase().contains(q) ||
          (u.email ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usersAsync = ref.watch(usersControllerProvider);
    final total = usersAsync.asData?.value.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(theme),
        const SizedBox(height: AppSpacing.md),
        _toolbar(theme, total),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: GlassCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: usersAsync.when(
              data: (users) => _buildContent(_filter(users)),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(theme, e),
            ),
          ),
        ),
      ],
    );
  }

  /// 面包屑 + 标题 + 说明。
  Widget _header(ThemeData theme) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 第一行：路由面包屑
        Row(
          children: [
            Text('Sisyphus Ventures',
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Icon(Icons.chevron_right_rounded, size: 16, color: muted),
            ),
            Text('User management',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurface)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // 第二行：标题
        Text('User management',
            style: theme.textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.xxs),
        // 第三行：说明
        Text(
          'Manage your team members and their account permissions here.',
          style: theme.textTheme.bodyMedium?.copyWith(color: muted),
        ),
      ],
    );
  }

  /// 工具栏：左 All users xx | 右 Search / Filters / Add user。
  Widget _toolbar(ThemeData theme, int total) {
    return Row(
      children: [
        Text('All users',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(width: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text('$total',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.primary)),
        ),
        const Spacer(),
        // 搜索框
        SizedBox(
          width: 240,
          height: 40,
          child: TextField(
            controller: _search,
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: AppSpacing.sm),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Filters
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('Filters'),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Add user
        FilledButton.icon(
          onPressed: _openRegisterDialog,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add user'),
        ),
      ],
    );
  }

  Widget _buildContent(List<AppUser> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
            const SizedBox(height: AppSpacing.sm),
            Text(_query.isEmpty ? '暂无用户' : '无匹配用户'),
          ],
        ),
      );
    }
    return UserTable(
      users: users,
      onToggleStatus: (u) =>
          ref.read(usersControllerProvider.notifier).toggleStatus(u),
    );
  }

  Widget _buildError(ThemeData theme, Object error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: AppSpacing.sm),
          Text('加载失败：$error',
              textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
            onPressed: () =>
                ref.read(usersControllerProvider.notifier).refreshUsers(),
          ),
        ],
      ),
    );
  }

  Future<void> _openRegisterDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const RegisterUserDialog(),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('账号注册成功')),
      );
    }
  }
}
