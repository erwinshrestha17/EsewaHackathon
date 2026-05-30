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
      TransactionType.dhukutiContribution => 'Saving Circle Contribution',
      TransactionType.dhukutiPayout => 'Saving Circle Payout',
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
      TransactionType.dhukutiContribution =>
        'Confirm Saving Circle Contribution',
      TransactionType.dhukutiPayout => 'Confirm Payout',
      TransactionType.giftPoolContribution => 'Confirm Gift Pool',
      TransactionType.adjustment => 'Confirm Adjustment',
    };
  }
}
