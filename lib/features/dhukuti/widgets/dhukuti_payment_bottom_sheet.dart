import 'package:flutter/material.dart';

import '../../../shared/payments/esewa_payment_service.dart';
import '../../../shared/transactions/transaction_confirmation_controller.dart';
import '../../../shared/transactions/transaction_confirmation_data.dart';
import '../../../shared/transactions/transaction_status.dart';
import '../../../shared/transactions/transaction_type.dart';
import '../../../src/app_state.dart';
import '../../../src/models.dart';

Future<bool> showDhukutiPaymentBottomSheet({
  required BuildContext context,
  required AppStore store,
  required DhukutiPool pool,
  required DhukutiContribution contribution,
}) async {
  final data = TransactionConfirmationData(
    id: 'dhukuti-${contribution.id}',
    transactionType: TransactionType.dhukutiContribution,
    title: 'Confirm Contribution',
    subtitle: '${pool.name} • Month ${contribution.cycleNumber}',
    amount: contribution.amountMinor,
    payerName: store.nameOf(store.currentUserId),
    payerAvatarUrl: store.currentUser.avatar,
    groupName: store.groupById(pool.groupId).name,
    poolName: pool.name,
    confirmationButtonText: 'Pay with eSewa',
    createdAt: DateTime.now(),
    idempotencyKey: contribution.idempotencyKey,
    operationType: contribution.operationType,
    details: [
      TransactionDetail('Cycle', 'Month ${contribution.cycleNumber}'),
      TransactionDetail('Due date', _dateLabel(contribution.dueDate)),
    ],
  );
  final result = await openTransactionConfirmation(context, data, () {
    return confirmWithEsewa(
      context: context,
      data: data,
      onSuccess: (receipt) async {
        store.payDhukutiContribution(
          contribution.id,
          paymentProvider: 'esewa',
          paymentReference: receipt.reference,
          rawPayload: receipt.rawPayload,
        );
        return TransactionResult.success(
          title: 'Contribution Paid',
          message: 'Your community savings contribution was paid via eSewa.',
          amount: contribution.amountMinor,
          transactionReference: receipt.reference,
          createdAt: DateTime.now(),
        );
      },
    );
  });
  return result?.isSuccess ?? false;
}

String _dateLabel(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}
