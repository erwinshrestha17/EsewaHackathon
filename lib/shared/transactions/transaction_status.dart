enum TransactionStatus {
  draft,
  pending,
  paid,
  sent,
  failed,
  failedReview,
  expired,
  cancelled,
  refunded,
}

extension TransactionStatusLabel on TransactionStatus {
  String get label {
    return switch (this) {
      TransactionStatus.draft => 'Draft',
      TransactionStatus.pending => 'Pending',
      TransactionStatus.paid => 'Paid',
      TransactionStatus.sent => 'Sent',
      TransactionStatus.failed => 'Failed',
      TransactionStatus.failedReview => 'Review Failed',
      TransactionStatus.expired => 'Expired',
      TransactionStatus.cancelled => 'Cancelled',
      TransactionStatus.refunded => 'Refunded',
    };
  }

  bool get isSuccessful {
    return this == TransactionStatus.paid || this == TransactionStatus.sent;
  }
}

class TransactionResult {
  const TransactionResult({
    required this.status,
    required this.title,
    required this.message,
    required this.amount,
    required this.transactionReference,
    required this.createdAt,
    this.reason,
  });

  factory TransactionResult.success({
    required String title,
    required String message,
    required int amount,
    required String transactionReference,
    required DateTime createdAt,
    TransactionStatus status = TransactionStatus.paid,
  }) {
    return TransactionResult(
      status: status,
      title: title,
      message: message,
      amount: amount,
      transactionReference: transactionReference,
      createdAt: createdAt,
    );
  }

  factory TransactionResult.failure({
    required String reason,
    required int amount,
    required String transactionReference,
    required DateTime createdAt,
    TransactionStatus status = TransactionStatus.failed,
  }) {
    return TransactionResult(
      status: status,
      title: 'Transaction Failed',
      message: reason,
      reason: reason,
      amount: amount,
      transactionReference: transactionReference,
      createdAt: createdAt,
    );
  }

  final TransactionStatus status;
  final String title;
  final String message;
  final String? reason;
  final int amount;
  final String transactionReference;
  final DateTime createdAt;

  bool get isSuccess => status.isSuccessful;
}
