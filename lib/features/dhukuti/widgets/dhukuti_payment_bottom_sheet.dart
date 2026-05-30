import 'package:flutter/material.dart';

import '../../../features/auth/auth_controller.dart';
import '../../../shared/api/backend_api.dart';
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
  final result = await openTransactionConfirmation(context, data, (
    paymentContext,
  ) {
    return confirmWithEsewa(
      context: paymentContext,
      data: data,
      onSuccess: (receipt) async {
        final api = BackendApi();
        if (!api.isConfigured) {
          return TransactionResult.failure(
            reason:
                'Backend API is required for signed-in actions. Start the API server and set BACKEND_API_BASE_URL.',
            amount: contribution.amountMinor,
            transactionReference: receipt.reference,
            createdAt: DateTime.now(),
            status: TransactionStatus.failedReview,
          );
        }
        final token = await AuthScope.of(context).backendAccessToken();
        if (token == null) {
          return TransactionResult.failure(
            reason: 'Sign in again to continue.',
            amount: contribution.amountMinor,
            transactionReference: receipt.reference,
            createdAt: DateTime.now(),
            status: TransactionStatus.failedReview,
          );
        }
        try {
          await api.submitCommunitySavingsContribution(
            accessToken: token,
            savingsGroupId: pool.id,
            contributionId: contribution.id,
            contribution: {
              'amountPaid': contribution.amountMinor,
              'paymentMethod': 'esewa',
              'referenceNumber': receipt.reference,
              'note': 'Submitted via eSewa',
            },
          );
          final snapshot = await api.appBootstrap(accessToken: token);
          store.loadBackendSnapshot(snapshot);
        } on BackendApiException catch (error) {
          return TransactionResult.failure(
            reason: error.message,
            amount: contribution.amountMinor,
            transactionReference: receipt.reference,
            createdAt: DateTime.now(),
            status: TransactionStatus.failedReview,
          );
        }
        return TransactionResult.success(
          title: 'Contribution Submitted',
          message:
              'Your community savings contribution was submitted for admin confirmation.',
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
