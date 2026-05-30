import 'package:flutter/material.dart';

import '../../../shared/design_system/app_colors.dart';
import '../../../shared/design_system/app_components.dart' as ds;
import '../../../shared/design_system/app_spacing.dart';
import '../../../shared/design_system/app_text_styles.dart';
import '../../../src/finance.dart';
import '../home_models.dart';

class ActiveGroupSection extends StatelessWidget {
  const ActiveGroupSection({
    required this.groups,
    required this.onViewAll,
    required this.onGroupTap,
    super.key,
  });

  final List<HomeGroupSummary> groups;
  final VoidCallback onViewAll;
  final ValueChanged<HomeGroupSummary> onGroupTap;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const SizedBox.shrink();
    }
    return _HomeSection(
      title: 'Active groups',
      action: TextButton(onPressed: onViewAll, child: const Text('View all')),
      child: Column(
        children: [
          for (final group in groups.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _GroupCard(group: group, onTap: () => onGroupTap(group)),
            ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onTap});

  final HomeGroupSummary group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final balanceLabel = group.userBalance == 0
        ? 'All settled'
        : group.userBalance > 0
        ? 'You are owed ${money(group.userBalance)}'
        : 'You owe ${money(group.userBalance.abs())}';
    final balanceColor = group.userBalance > 0
        ? AppColors.success
        : group.userBalance < 0
        ? AppColors.warning
        : Theme.of(context).colorScheme.onSurfaceVariant;
    final scheme = Theme.of(context).colorScheme;
    return ds.AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Icon(group.icon),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.cardTitle,
                    ),
                    Text(
                      '${group.category} · ${group.memberCount} members',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      group.recentText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          );
          final balance = Column(
            crossAxisAlignment: constraints.maxWidth < 390
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
            children: [
              Text(
                balanceLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: constraints.maxWidth < 390
                    ? TextAlign.start
                    : TextAlign.end,
                style: AppTextStyles.cardTitle.copyWith(color: balanceColor),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                group.dueStatus,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );
          if (constraints.maxWidth < 390) {
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 88),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  identity,
                  const SizedBox(height: AppSpacing.sm),
                  balance,
                ],
              ),
            );
          }
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: AppSpacing.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: balance,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: AppTextStyles.sectionTitle)),
            ?action,
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}
