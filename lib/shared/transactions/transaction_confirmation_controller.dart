import 'package:flutter/material.dart';

import 'transaction_confirmation_data.dart';
import 'transaction_confirmation_screen.dart';
import 'transaction_failure_screen.dart';
import 'transaction_status.dart';
import 'transaction_success_screen.dart';

typedef TransactionConfirmCallback =
    Future<TransactionResult> Function(BuildContext context);
typedef TransactionSubmitCallback = Future<TransactionResult> Function();

class TransactionConfirmationController {
  TransactionConfirmationController._();

  static final Set<String> _inFlightKeys = <String>{};
  static final Map<String, TransactionResult> _completed =
      <String, TransactionResult>{};

  static Future<TransactionResult> submit(
    TransactionConfirmationData data,
    TransactionSubmitCallback onConfirm,
  ) async {
    final existing = _completed[data.idempotencyKey];
    if (existing != null) {
      return existing;
    }
    if (_inFlightKeys.contains(data.idempotencyKey)) {
      return TransactionResult.failure(
        reason: 'This transaction is already pending.',
        amount: data.amount,
        transactionReference: data.transactionReference ?? data.id,
        createdAt: DateTime.now(),
        status: TransactionStatus.pending,
      );
    }
    _inFlightKeys.add(data.idempotencyKey);
    try {
      final result = await onConfirm();
      if (result.isSuccess) {
        _completed[data.idempotencyKey] = result;
      }
      return result;
    } on Object catch (error) {
      return TransactionResult.failure(
        reason: error.toString().replaceFirst('Invalid argument(s): ', ''),
        amount: data.amount,
        transactionReference: data.transactionReference ?? data.id,
        createdAt: DateTime.now(),
        status: TransactionStatus.failedReview,
      );
    } finally {
      _inFlightKeys.remove(data.idempotencyKey);
    }
  }
}

Future<TransactionResult?> openTransactionConfirmation(
  BuildContext context,
  TransactionConfirmationData data,
  TransactionConfirmCallback onConfirm,
) {
  return Navigator.of(context).push<TransactionResult>(
    MaterialPageRoute<TransactionResult>(
      builder: (_) =>
          TransactionConfirmationScreen(data: data, onConfirm: onConfirm),
    ),
  );
}

Future<void> showTransactionResult(
  BuildContext context,
  TransactionResult result,
  VoidCallback onRetry,
) {
  if (result.isSuccess) {
    return Navigator.of(context).pushReplacement<TransactionResult, void>(
      MaterialPageRoute<TransactionResult>(
        builder: (_) => TransactionSuccessScreen(result: result),
      ),
    );
  }
  return Navigator.of(context).pushReplacement<TransactionResult, void>(
    MaterialPageRoute<TransactionResult>(
      builder: (_) =>
          TransactionFailureScreen(result: result, onRetry: onRetry),
    ),
  );
}
