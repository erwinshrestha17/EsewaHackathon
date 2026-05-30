import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';
import '../design_system/app_components.dart' as ds;
import '../design_system/app_spacing.dart';
import '../design_system/app_text_styles.dart';
import '../../src/finance.dart';
import 'transaction_confirmation_data.dart';

class TransactionReceiptCard extends StatelessWidget {
  const TransactionReceiptCard({required this.data, super.key});

  final TransactionConfirmationData data;

  @override
  Widget build(BuildContext context) {
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

    return ds.AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transaction details', style: AppTextStyles.sectionTitle),
          const SizedBox(height: AppSpacing.md),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              detail.label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              detail.value,
              textAlign: TextAlign.end,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w800),
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
