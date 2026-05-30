import 'package:flutter/material.dart';

import '../../../src/app_state.dart';
import '../../../src/finance.dart';
import '../../../src/models.dart';
import 'savings_circle_status_badge.dart';
import 'savings_circle_tokens.dart';

class SavingsCircleMemberRow extends StatelessWidget {
  const SavingsCircleMemberRow({
    required this.store,
    required this.member,
    required this.contribution,
    required this.amountMinor,
    required this.isOrganizer,
    super.key,
  });

  final AppStore store;
  final SavingsCircleMember member;
  final SavingsCircleContribution? contribution;
  final int amountMinor;
  final bool isOrganizer;

  @override
  Widget build(BuildContext context) {
    final user = store.userById(member.userId);
    final contributionStatus =
        contribution?.status ?? ContributionStatus.pending;
    final role = isOrganizer ? 'Organizer' : 'Active Member';
    final memberStatus = member.status == SavingsCircleMemberStatus.active
        ? role
        : savingsCircleEnumLabel(member.status);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SavingsCircleAvatar(label: user.avatar),
      title: Text(user.displayName),
      subtitle: Text('$memberStatus • Payout order #${member.payoutOrder}'),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SavingsCircleStatusBadge(
            label: savingsCircleEnumLabel(contributionStatus),
            tone: toneForContributionStatus(contributionStatus),
            icon: contributionStatus == ContributionStatus.paid
                ? Icons.check_circle_outline
                : contributionStatus == ContributionStatus.late ||
                      contributionStatus == ContributionStatus.missed
                ? Icons.warning_amber_outlined
                : Icons.schedule_outlined,
          ),
          Text(
            money(amountMinor),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
