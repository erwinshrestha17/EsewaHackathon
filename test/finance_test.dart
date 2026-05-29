import 'package:flutter_test/flutter_test.dart';
import 'package:sangai/src/app_state.dart';
import 'package:sangai/src/finance.dart';
import 'package:sangai/src/models.dart';

void main() {
  test('equal shares keep integer paisa totals exact', () {
    final shares = equalShares(npr(100), const ['a', 'b', 'c']);

    expect(shares.fold<int>(0, (sum, item) => sum + item), npr(100));
    expect(shares, [3334, 3333, 3333]);
  });

  test('exact shares must match total', () {
    expect(
      () => validateExactShares(npr(100), [npr(40), npr(59)]),
      throwsArgumentError,
    );
  });

  test('seeded store keeps group balances zero-sum after settlement', () {
    final store = AppStore();
    final balances = store.balancesForGroup('g-dashain');

    expect(balances.values.fold<int>(0, (sum, item) => sum + item), 0);
    expect(
      store.expenses
          .where((expense) => expense.groupId == 'g-dashain')
          .every((expense) => expense.lockedAt != null),
      isTrue,
    );
  });

  test('item receipt expenses create auditable item shares', () {
    final store = AppStore();
    final expenseId = store.addExpense(
      groupId: 'g-dashain',
      title: 'Receipt test',
      totalMinor: npr(300),
      payerId: 'u-sita',
      category: 'festival',
      splitMode: SplitMode.item,
      participantIds: const ['u-sita', 'u-arjun'],
      receiptItems: [
        ParsedReceiptItem(label: 'Momo', amountMinor: npr(200)),
        ParsedReceiptItem(label: 'Tea', amountMinor: npr(100)),
      ],
      itemAssignments: const {
        0: ['u-sita'],
        1: ['u-sita', 'u-arjun'],
      },
    );

    final expense = store.expenses.firstWhere((item) => item.id == expenseId);
    expect(expense.items.length, 2);
    expect(
      expense.shares.fold<int>(0, (sum, item) => sum + item.amountMinor),
      npr(300),
    );
  });

  test('gifts require active unblocked connections', () {
    final store = AppStore();

    expect(
      store.sendGift(
        recipientId: 'u-kabir',
        template: 'Dashain',
        amountMinor: npr(100),
        message: 'Hello',
      ),
      contains('active'),
    );
  });

  test('QR invites preserve hyphenated user IDs', () {
    final store = AppStore()..switchUser('u-arjun');
    final code = store.qrInviteCodeFor(store.userById('u-kabir'));

    expect(code, 'SANGAI-QR-u-kabir');
    expect(store.qrInviteValidationError(code), isNull);
    expect(store.acceptQrInvite(code), 'Request sent to Kabir Lama.');
    expect(
      store.connectionBetween('u-arjun', 'u-kabir')?.status,
      ConnectionStatus.pending,
    );
  });
}
