import 'transaction_type.dart';

class TransactionConfirmationData {
  const TransactionConfirmationData({
    required this.id,
    required this.transactionType,
    required this.title,
    required this.subtitle,
    required this.amount,
    this.currency = 'NPR',
    required this.payerName,
    required this.payerAvatarUrl,
    this.recipientName,
    this.recipientAvatarUrl,
    this.groupName,
    this.poolName,
    this.category,
    this.splitMode,
    this.participants = const <TransactionParticipant>[],
    this.items,
    this.note,
    this.paymentMethod = 'eSewa Wallet',
    this.isMockPayment = true,
    this.warningMessage,
    this.complianceNote,
    required this.confirmationButtonText,
    required this.createdAt,
    required this.idempotencyKey,
    required this.operationType,
    this.transactionReference,
    this.details = const <TransactionDetail>[],
    this.statusLabel,
  });

  final String id;
  final TransactionType transactionType;
  final String title;
  final String subtitle;
  final int amount;
  final String currency;
  final String payerName;
  final String payerAvatarUrl;
  final String? recipientName;
  final String? recipientAvatarUrl;
  final String? groupName;
  final String? poolName;
  final String? category;
  final String? splitMode;
  final List<TransactionParticipant> participants;
  final List<TransactionItem>? items;
  final String? note;
  final String paymentMethod;
  final bool isMockPayment;
  final String? warningMessage;
  final String? complianceNote;
  final String confirmationButtonText;
  final DateTime createdAt;
  final String idempotencyKey;
  final String operationType;
  final String? transactionReference;
  final List<TransactionDetail> details;
  final String? statusLabel;

  bool get requiresRecipient {
    return switch (transactionType) {
      TransactionType.settlement ||
      TransactionType.gift ||
      TransactionType.savingsCirclePayout => true,
      _ => false,
    };
  }

  bool get validatesParticipantTotal {
    return switch (transactionType) {
      TransactionType.groupExpense ||
      TransactionType.manualItemExpense ||
      TransactionType.ocrExpense ||
      TransactionType.adjustment => true,
      _ => false,
    };
  }

  int get participantTotal {
    return participants.fold<int>(
      0,
      (total, participant) => total + participant.amountShare,
    );
  }

  String? get validationError {
    if (amount <= 0) {
      return 'Amount must be greater than zero.';
    }
    if (payerName.trim().isEmpty) {
      return 'Payer is required.';
    }
    if (requiresRecipient &&
        (recipientName == null || recipientName!.trim().isEmpty)) {
      return 'Recipient is required.';
    }
    if (transactionType == TransactionType.adjustment &&
        participants.isNotEmpty &&
        participantTotal != 0) {
      return 'Adjustment credits and debits must balance to zero.';
    }
    if (validatesParticipantTotal &&
        transactionType != TransactionType.adjustment &&
        participants.isNotEmpty &&
        participantTotal != amount) {
      return 'Participant shares must add up to the transaction amount.';
    }
    if ((statusLabel ?? '').toLowerCase() == 'pending') {
      return 'This transaction is already pending.';
    }
    return null;
  }
}

class TransactionParticipant {
  const TransactionParticipant({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.amountShare,
    required this.roleLabel,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final int amountShare;
  final String roleLabel;
}

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.title,
    required this.quantity,
    required this.amount,
    required this.assignedMembers,
  });

  final String id;
  final String title;
  final int quantity;
  final int amount;
  final List<String> assignedMembers;
}

class TransactionDetail {
  const TransactionDetail(this.label, this.value);

  final String label;
  final String value;
}
