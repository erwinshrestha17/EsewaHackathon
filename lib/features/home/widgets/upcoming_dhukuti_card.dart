import 'package:flutter/material.dart';

import '../../../src/finance.dart';
import '../home_models.dart';

class UpcomingDhukutiCard extends StatelessWidget {
  const UpcomingDhukutiCard({
    required this.due,
    required this.onPay,
    required this.onViewLedger,
    super.key,
  });

  final HomeDhukutiDue? due;
  final VoidCallback onPay;
  final VoidCallback onViewLedger;

  @override
  Widget build(BuildContext context) {
    if (due == null) {
      return const SizedBox.shrink();
    }
    final item = due!;
    final scheme = Theme.of(context).colorScheme;
    final needsAttention =
        item.status == 'At Risk' || item.status == 'Due Late';
    final color = needsAttention ? const Color(0xFFB56A12) : scheme.primary;
    return _HomeSection(
      title: 'Upcoming Saving Circle',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        item.poolName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${item.cycleLabel} · payout recipient: ${item.payoutRecipientName}',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _StatusPill(label: item.status, color: color),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _Detail(label: 'Amount', value: money(item.amount)),
                ),
                Expanded(
                  child: _Detail(label: 'Due', value: item.dueLabel),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Saving Circle is shown as a transparent contribution ledger and payment scheduler.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: item.isPayable ? onPay : onViewLedger,
              icon: Icon(
                item.isPayable
                    ? Icons.account_balance_wallet_outlined
                    : Icons.receipt_long_outlined,
              ),
              label: Text(item.isPayable ? 'Pay Contribution' : 'View Ledger'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}
