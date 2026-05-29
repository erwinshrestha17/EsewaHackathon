enum TransactionType {
  groupExpense,
  settlement,
  gift,
  dhukutiContribution,
  dhukutiPayout,
  giftPoolContribution,
  adjustment,
  manualItemExpense,
  ocrExpense,
}

extension TransactionTypeLabel on TransactionType {
  String get label {
    return switch (this) {
      TransactionType.groupExpense => 'Group Expense',
      TransactionType.settlement => 'Settlement',
      TransactionType.gift => 'Gift',
      TransactionType.dhukutiContribution => 'Dhukuti Contribution',
      TransactionType.dhukutiPayout => 'Dhukuti Payout',
      TransactionType.giftPoolContribution => 'Gift Pool Contribution',
      TransactionType.adjustment => 'Adjustment',
      TransactionType.manualItemExpense => 'Manual Item Expense',
      TransactionType.ocrExpense => 'OCR Bill Expense',
    };
  }

  String get confirmationTitle {
    return switch (this) {
      TransactionType.groupExpense ||
      TransactionType.manualItemExpense ||
      TransactionType.ocrExpense => 'Confirm Expense',
      TransactionType.settlement => 'Confirm Settlement',
      TransactionType.gift => 'Confirm Gift',
      TransactionType.dhukutiContribution => 'Confirm Dhukuti Contribution',
      TransactionType.dhukutiPayout => 'Confirm Payout',
      TransactionType.giftPoolContribution => 'Confirm Gift Pool',
      TransactionType.adjustment => 'Confirm Adjustment',
    };
  }
}
