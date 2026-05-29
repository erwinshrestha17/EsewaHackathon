import 'package:flutter/material.dart';

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

    return Material(
      color: Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected
              ? dhukutiPrimary
              : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pool.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(group.name),
                      ],
                    ),
                  ),
                  DhukutiStatusBadge(
                    label: statusLabel,
                    tone: toneForPoolStatus(statusLabel),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
                    label: 'Payout: $recipientName',
                  ),
                  _Fact(
                    icon: Icons.calendar_today_outlined,
                    label: currentCycle == null
                        ? 'Due date pending'
                        : 'Next due ${dateLabel(currentCycle.dueDate)}',
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
                  const SizedBox(width: 10),
                  Text(
                    '$paidCount/${contributions.length} paid',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 15), const SizedBox(width: 6), Text(label)],
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
