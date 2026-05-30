import 'package:flutter/material.dart';

import '../../../src/app_state.dart';
import '../../../src/finance.dart';
import '../../../src/models.dart';
import 'savings_circle_status_badge.dart';
import 'savings_circle_tokens.dart';

enum SavingsCircleLedgerFilter { all, contributions, payouts, statusUpdates }

class SavingsCircleLedgerItem extends StatelessWidget {
  const SavingsCircleLedgerItem({
    required this.store,
    required this.event,
    super.key,
  });

  final AppStore store;
  final ActivityLog event;

  @override
  Widget build(BuildContext context) {
    final actorName = event.actorId == null
        ? 'System'
        : store.nameOf(event.actorId!);
    final tone = _toneForEvent(event);
    final color = savingsCircleToneColor(context, tone);
    final amount = _amountForEvent(store, event);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Icon(_iconForEvent(event)),
      ),
      title: Text(event.title),
      subtitle: Text('$actorName • ${dateLabel(event.createdAt)}'),
      trailing: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (amount != null)
            Text(
              money(amount),
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          SavingsCircleStatusBadge(label: _statusForEvent(event), tone: tone),
        ],
      ),
    );
  }
}

bool ledgerEventMatches(ActivityLog event, SavingsCircleLedgerFilter filter) {
  if (!event.eventType.startsWith('savings_circle_')) {
    return false;
  }
  return switch (filter) {
    SavingsCircleLedgerFilter.all => true,
    SavingsCircleLedgerFilter.contributions => event.eventType.contains(
      'contribution',
    ),
    SavingsCircleLedgerFilter.payouts => event.eventType.contains('payout'),
    SavingsCircleLedgerFilter.statusUpdates =>
      event.eventType.contains('opened') ||
          event.eventType.contains('seeded') ||
          event.eventType.contains('recipient') ||
          event.eventType.contains('late') ||
          event.eventType.contains('accepted') ||
          event.eventType.contains('created'),
  };
}

IconData _iconForEvent(ActivityLog event) {
  if (event.eventType.contains('contribution')) {
    return Icons.payments_outlined;
  }
  if (event.eventType.contains('payout')) {
    return Icons.outbox_outlined;
  }
  if (event.eventType.contains('late') || event.eventType.contains('risk')) {
    return Icons.warning_amber_outlined;
  }
  if (event.eventType.contains('accepted')) {
    return Icons.person_add_alt_1;
  }
  return Icons.timeline;
}

SavingsCircleTone _toneForEvent(ActivityLog event) {
  if (event.eventType.contains('late') || event.eventType.contains('risk')) {
    return SavingsCircleTone.warning;
  }
  if (event.eventType.contains('contribution') ||
      event.eventType.contains('payout')) {
    return SavingsCircleTone.success;
  }
  return SavingsCircleTone.neutral;
}

String _statusForEvent(ActivityLog event) {
  if (event.eventType.contains('late') || event.eventType.contains('risk')) {
    return 'Attention';
  }
  if (event.eventType.contains('contribution')) {
    return 'Paid';
  }
  if (event.eventType.contains('payout')) {
    return 'Completed';
  }
  return 'Logged';
}

int? _amountForEvent(AppStore store, ActivityLog event) {
  if (event.entityType == 'savings_circle_contribution') {
    for (final contribution in store.savingsCircleContributions) {
      if (contribution.id == event.entityId) {
        return contribution.amountMinor;
      }
    }
  }
  if (event.entityType == 'savings_circle_payout') {
    for (final payout in store.savingsCirclePayouts) {
      if (payout.id == event.entityId) {
        return payout.amountMinor;
      }
    }
  }
  return null;
}
