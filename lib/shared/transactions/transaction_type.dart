enum TransactionType {
  groupExpense,
  settlement,
  gift,
  savingsCircleContribution,
  savingsCirclePayout,
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
      TransactionType.savingsCircleContribution =>
        'Savings Circle Contribution',
      TransactionType.savingsCirclePayout => 'Savings Circle Payout',
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
      TransactionType.savingsCircleContribution =>
        'Confirm Savings Circle Contribution',
      TransactionType.savingsCirclePayout => 'Confirm Payout',
      TransactionType.giftPoolContribution => 'Confirm Gift Pool',
      TransactionType.adjustment => 'Confirm Adjustment',
    };
  }
}
