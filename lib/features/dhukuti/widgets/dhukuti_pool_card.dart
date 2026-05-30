import 'package:flutter/material.dart';

import '../../../shared/design_system/app_components.dart' as ds;
import '../../../shared/design_system/app_spacing.dart';
import '../../../shared/design_system/app_text_styles.dart';
import '../../../src/app_state.dart';
import '../../../src/finance.dart';
import '../../../src/models.dart';
import 'dhukuti_status_badge.dart';
import 'dhukuti_tokens.dart';

class DhukutiPoolCard extends StatelessWidget {
  const DhukutiPoolCard({
    required this.store,
    required this.pool,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AppStore store;
  final DhukutiPool pool;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final group = store.groupById(pool.groupId);
    final members = store.membersForPool(pool.id);
    final cycles =
        store.dhukutiCycles.where((cycle) => cycle.poolId == pool.id).toList()
          ..sort((a, b) => a.cycleNumber.compareTo(b.cycleNumber));
    final currentCycle = currentCycleFor(pool, cycles);
    final contributions = store.dhukutiContributions
        .where((item) => item.cycleId == currentCycle?.id)
        .toList();
    final paidCount = contributions
        .where((item) => item.status == ContributionStatus.paid)
        .length;
    final recipientName = currentCycle == null
        ? 'Not assigned'
        : store.nameOf(currentCycle.payoutRecipientId);
    final statusLabel = poolDisplayStatus(pool, currentCycle);
    final progress = contributions.isEmpty
        ? 0.0
        : paidCount / contributions.length;
    final color = dhukutiToneColor(context, toneForPoolStatus(statusLabel));

    return ds.AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      tone: selected ? ds.AppStatusTone.success : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundColor: color,
                child: const Icon(Icons.account_balance_wallet_outlined),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pool.name, style: AppTextStyles.sectionTitle),
                    Text(group.name, style: AppTextStyles.bodySecondary),
                  ],
                ),
              ),
              DhukutiStatusBadge(
                label: statusLabel,
                tone: toneForPoolStatus(statusLabel),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _Fact(
                icon: Icons.savings_outlined,
                label:
                    '${money(pool.contributionAmountMinor)} ${pool.frequency}',
              ),
              _Fact(
                icon: Icons.event_repeat,
                label: currentCycle == null
                    ? 'No cycle'
                    : 'Cycle ${currentCycle.cycleNumber} of ${members.length}',
              ),
              _Fact(
                icon: Icons.person_outline,
                label: 'Recipient: $recipientName',
              ),
              _Fact(
                icon: Icons.calendar_today_outlined,
                label: currentCycle == null
                    ? 'Due date pending'
                    : 'Next due ${dateLabel(currentCycle.dueDate)}',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 9,
                    value: progress,
                    backgroundColor: color.withValues(alpha: 0.13),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$paidCount/${contributions.length} paid',
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

DhukutiCycle? currentCycleFor(DhukutiPool pool, List<DhukutiCycle> cycles) {
  if (cycles.isEmpty) {
    return null;
  }
  final active = cycles.where(
    (cycle) =>
        cycle.status == DhukutiCycleStatus.open ||
        cycle.status == DhukutiCycleStatus.atRisk ||
        cycle.status == DhukutiCycleStatus.readyForPayout,
  );
  if (active.isNotEmpty) {
    return active.first;
  }
  final upcoming = cycles.where(
    (cycle) => cycle.status == DhukutiCycleStatus.upcoming,
  );
  if (upcoming.isNotEmpty) {
    return upcoming.first;
  }
  return cycles.last;
}

String poolDisplayStatus(DhukutiPool pool, DhukutiCycle? currentCycle) {
  if (pool.status == DhukutiPoolStatus.completed) {
    return 'Completed';
  }
  if (currentCycle == null) {
    return 'Upcoming';
  }
  if (currentCycle.status == DhukutiCycleStatus.atRisk) {
    return 'At Risk';
  }
  if (currentCycle.status == DhukutiCycleStatus.upcoming) {
    return 'Upcoming';
  }
  if (pool.status == DhukutiPoolStatus.active) {
    return 'Active';
  }
  return dhukutiEnumLabel(pool.status);
}
