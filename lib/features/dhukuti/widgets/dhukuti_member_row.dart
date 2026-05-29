import 'package:flutter/material.dart';

import '../../../src/app_state.dart';
import '../../../src/finance.dart';
import '../../../src/models.dart';
import 'dhukuti_status_badge.dart';
import 'dhukuti_tokens.dart';

class DhukutiMemberRow extends StatelessWidget {
  const DhukutiMemberRow({
    required this.store,
    required this.member,
    required this.contribution,
    required this.amountMinor,
    required this.isOrganizer,
    super.key,
  });

  final AppStore store;
  final DhukutiMember member;
  final DhukutiContribution? contribution;
  final int amountMinor;
  final bool isOrganizer;

  @override
  Widget build(BuildContext context) {
    final user = store.userById(member.userId);
    final contributionStatus =
        contribution?.status ?? ContributionStatus.pending;
    final role = isOrganizer ? 'Organizer' : 'Active Member';
    final memberStatus = member.status == DhukutiMemberStatus.active
        ? role
        : dhukutiEnumLabel(member.status);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: DhukutiAvatar(label: user.avatar),
      title: Text(user.displayName),
      subtitle: Text('$memberStatus • Payout order #${member.payoutOrder}'),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DhukutiStatusBadge(
            label: dhukutiEnumLabel(contributionStatus),
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
