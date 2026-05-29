import 'package:flutter/material.dart';

import '../../../src/app_state.dart';
import '../../../src/finance.dart';
import '../../../src/models.dart';
import 'dhukuti_status_badge.dart';
import 'dhukuti_tokens.dart';

enum DhukutiLedgerFilter { all, contributions, payouts, statusUpdates }

class DhukutiLedgerItem extends StatelessWidget {
  const DhukutiLedgerItem({
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
    final color = dhukutiToneColor(context, tone);
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
          DhukutiStatusBadge(label: _statusForEvent(event), tone: tone),
        ],
      ),
    );
  }
}

bool ledgerEventMatches(ActivityLog event, DhukutiLedgerFilter filter) {
  if (!event.eventType.startsWith('dhukuti_')) {
    return false;
  }
  return switch (filter) {
    DhukutiLedgerFilter.all => true,
    DhukutiLedgerFilter.contributions => event.eventType.contains(
      'contribution',
    ),
    DhukutiLedgerFilter.payouts => event.eventType.contains('payout'),
    DhukutiLedgerFilter.statusUpdates =>
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

DhukutiTone _toneForEvent(ActivityLog event) {
  if (event.eventType.contains('late') || event.eventType.contains('risk')) {
    return DhukutiTone.warning;
  }
  if (event.eventType.contains('contribution') ||
      event.eventType.contains('payout')) {
    return DhukutiTone.success;
  }
  return DhukutiTone.neutral;
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
  if (event.entityType == 'dhukuti_contribution') {
    for (final contribution in store.dhukutiContributions) {
      if (contribution.id == event.entityId) {
        return contribution.amountMinor;
      }
    }
  }
  if (event.entityType == 'dhukuti_payout') {
    for (final payout in store.dhukutiPayouts) {
      if (payout.id == event.entityId) {
        return payout.amountMinor;
      }
    }
  }
  return null;
}
