import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../models/app_user.dart';

/// 用户列表表格。展示用户名/昵称、联系方式、状态、创建时间，支持切换启用状态。
class UserTable extends StatelessWidget {
  const UserTable({
    super.key,
    required this.users,
    required this.onToggleStatus,
  });

  final List<AppUser> users;
  final ValueChanged<AppUser> onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columnSpacing: AppSpacing.xl,
          headingRowHeight: 48,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          columns: const [
            DataColumn(label: Text('用户名')),
            DataColumn(label: Text('真实姓名')),
            DataColumn(label: Text('邮箱')),
            DataColumn(label: Text('状态')),
            DataColumn(label: Text('创建时间')),
            DataColumn(label: Text('操作')),
          ],
          rows: users.map((u) => _row(context, theme, u)).toList(),
        ),
      ),
    );
  }

  DataRow _row(BuildContext context, ThemeData theme, AppUser u) {
    return DataRow(cells: [
      DataCell(Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            backgroundImage:
                (u.avatarUrl?.isNotEmpty ?? false) ? NetworkImage(u.avatarUrl!) : null,
            child: (u.avatarUrl?.isEmpty ?? true)
                ? Text(
                    (u.userName?.isNotEmpty ?? false ? u.userName! : u.displayName)
                        .characters
                        .first
                        .toUpperCase(),
                    style: theme.textTheme.labelMedium,
                  )
                : null,
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(u.userName?.isNotEmpty ?? false ? u.userName! : u.displayName,
                  style: theme.textTheme.bodyMedium),
              if (u.nickname?.isNotEmpty ?? false)
                Text(u.nickname!,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ],
      )),
      DataCell(Text(u.realName?.isNotEmpty ?? false ? u.realName! : '—')),
      DataCell(Text(u.email?.isNotEmpty ?? false ? u.email! : '—')),
      DataCell(_statusChip(theme, u)),
      DataCell(Text(u.createdAt?.isNotEmpty ?? false ? u.createdAt! : '—')),
      DataCell(TextButton(
        onPressed: () => onToggleStatus(u),
        child: Text(u.isActive ? '禁用' : '启用'),
      )),
    ]);
  }

  Widget _statusChip(ThemeData theme, AppUser u) {
    final color = u.isActive ? const Color(0xFF22C55E) : const Color(0xFF94A3B8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        u.isActive ? '正常' : '禁用',
        style: theme.textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
