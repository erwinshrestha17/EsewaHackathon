import 'package:flutter/material.dart';

import '../../../src/app_state.dart';
import '../../../src/finance.dart';
import '../../../src/models.dart';
import 'dhukuti_status_badge.dart';
import 'dhukuti_tokens.dart';

class DhukutiCycleCard extends StatelessWidget {
  const DhukutiCycleCard({
    required this.store,
    required this.cycle,
    required this.members,
    required this.contributions,
    required this.current,
    super.key,
  });

  final AppStore store;
  final DhukutiCycle cycle;
  final List<DhukutiMember> members;
  final List<DhukutiContribution> contributions;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final completed =
        cycle.status == DhukutiCycleStatus.paidOut ||
        cycle.status == DhukutiCycleStatus.closed;
    final color = current
        ? dhukutiPrimary
        : completed
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : dhukutiToneColor(context, toneForCycleStatus(cycle.status));
    final paidCount = contributions
        .where((item) => item.status == ContributionStatus.paid)
        .length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: current ? 0.18 : 0.10),
              foregroundColor: color,
              child: Text(
                '${cycle.cycleNumber}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Container(
              width: 2,
              height: 18,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: color.withValues(alpha: 0.24),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Material(
            color: completed
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(
                color: current
                    ? dhukutiPrimary.withValues(alpha: 0.45)
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              initiallyExpanded: current,
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              title: Text(
                'Cycle ${cycle.cycleNumber}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${dateLabel(cycle.dueDate)} • Payout recipient: ${store.nameOf(cycle.payoutRecipientId)}',
              ),
              trailing: DhukutiStatusBadge(
                label: dhukutiEnumLabel(cycle.status),
                tone: toneForCycleStatus(cycle.status),
              ),
              children: [
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${money(cycle.paidContributionTotalMinor)} paid of ${money(cycle.expectedContributionTotalMinor)}',
                      ),
                    ),
                    Text(
                      '$paidCount of ${contributions.length} contributions',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final member in members)
                  _ContributionLine(
                    name: store.nameOf(member.userId),
                    avatar: store.userById(member.userId).avatar,
                    contribution: contributions.firstWhere(
                      (item) => item.userId == member.userId,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ContributionLine extends StatelessWidget {
  const _ContributionLine({
    required this.name,
    required this.avatar,
    required this.contribution,
  });

  final String name;
  final String avatar;
  final DhukutiContribution contribution;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: DhukutiAvatar(label: avatar, small: true),
      title: Text(name),
      subtitle: Text(dateLabel(contribution.dueDate)),
      trailing: DhukutiStatusBadge(
        label: dhukutiEnumLabel(contribution.status),
        tone: toneForContributionStatus(contribution.status),
      ),
    );
  }
}
