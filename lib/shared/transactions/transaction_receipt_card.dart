import 'package:flutter/material.dart';

import '../../src/finance.dart';
import 'transaction_confirmation_data.dart';

class TransactionReceiptCard extends StatelessWidget {
  const TransactionReceiptCard({required this.data, super.key});

  final TransactionConfirmationData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final details = <TransactionDetail>[
      TransactionDetail('Amount', money(data.amount)),
      TransactionDetail('Payment method', data.paymentMethod),
      TransactionDetail(
        'Payment mode',
        data.isMockPayment ? 'Simulated payment' : 'Live payment',
      ),
      TransactionDetail('Date/time', _dateTimeLabel(data.createdAt)),
      TransactionDetail('Payer', data.payerName),
      if (data.recipientName != null)
        TransactionDetail('Recipient', data.recipientName!),
      if (data.groupName != null) TransactionDetail('Group', data.groupName!),
      if (data.poolName != null) TransactionDetail('Pool', data.poolName!),
      if (data.category != null) TransactionDetail('Category', data.category!),
      if (data.splitMode != null)
        TransactionDetail('Split mode', data.splitMode!),
      ...data.details,
      if (data.note != null && data.note!.trim().isNotEmpty)
        TransactionDetail('Note', data.note!),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction details',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          for (final detail in details) _ReceiptLine(detail: detail),
        ],
      ),
    );
  }
}

class _ReceiptLine extends StatelessWidget {
  const _ReceiptLine({required this.detail});

  final TransactionDetail detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              detail.label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              detail.value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

String _dateTimeLabel(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hour:$minute';
}
