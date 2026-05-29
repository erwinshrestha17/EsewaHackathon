import 'package:flutter_test/flutter_test.dart';
import 'package:sangai/src/app_state.dart';
import 'package:sangai/src/finance.dart';
import 'package:sangai/src/models.dart';

void main() {
  test('equal shares keep integer paisa totals exact', () {
    final shares = equalShares(npr(100), const ['a', 'b', 'c']);

    expect(shares.fold<int>(0, (sum, item) => sum + item), npr(100));
    expect(shares.where((share) => share == 3334).length, 1);
    expect(shares.where((share) => share == 3333).length, 2);
  });

  test('custom shares must match total', () {
    expect(
      () => validateCustomShares(npr(100), [npr(40), npr(59)]),
      throwsArgumentError,
    );
  });

  test('multiple payer amounts must match total and affect balances', () {
    final store = AppStore();
    final groupId = store.createGroup(
      name: 'Multi payer test',
      category: GroupCategory.custom,
      memberIds: const ['u-arjun'],
    );

    store.addExpense(
      groupId: groupId,
      title: 'Shared lunch',
      totalMinor: npr(300),
      payerId: 'u-sita',
      payerAmounts: {'u-sita': npr(200), 'u-arjun': npr(100)},
      category: 'custom',
      splitMode: SplitMode.equal,
      participantIds: const ['u-sita', 'u-arjun'],
      equalAmounts: {'u-sita': npr(150), 'u-arjun': npr(150)},
    );

    final balances = store.balancesForGroup(groupId);
    expect(balances['u-sita'], npr(50));
    expect(balances['u-arjun'], -npr(50));
    expect(
      () => store.addExpense(
        groupId: groupId,
        title: 'Invalid payers',
        totalMinor: npr(300),
        payerId: 'u-sita',
        payerAmounts: {'u-sita': npr(200)},
        category: 'custom',
        splitMode: SplitMode.equal,
        participantIds: const ['u-sita', 'u-arjun'],
      ),
      throwsArgumentError,
    );
  });

  test(
    're-adding a removed member creates a new period only for future use',
    () {
      final store = AppStore();
      final historical = store.expenses.firstWhere(
        (expense) => expense.groupId == 'g-dashain',
      );
      final historicalShares = {
        for (final share in historical.shares) share.userId: share.amountMinor,
      };

      store.removeGroupMember('g-dashain', 'u-rina');
      expect(store.isActiveGroupMember('g-dashain', 'u-rina'), isFalse);

      store.addGroupMember('g-dashain', 'u-rina', MemberRole.treasurer);
      expect(store.isActiveGroupMember('g-dashain', 'u-rina'), isTrue);
      expect(
        store
            .membersForGroup('g-dashain')
            .where((member) => member.userId == 'u-rina')
            .length,
        2,
      );

      final futureExpenseId = store.addExpense(
        groupId: 'g-dashain',
        title: 'Future tea',
        totalMinor: npr(60),
        payerId: 'u-sita',
        category: 'festival',
        splitMode: SplitMode.custom,
        participantIds: const ['u-sita', 'u-rina'],
        customAmounts: {'u-sita': npr(30), 'u-rina': npr(30)},
      );
      final futureExpense = store.expenses.firstWhere(
        (expense) => expense.id == futureExpenseId,
      );

      expect({
        for (final share in historical.shares) share.userId: share.amountMinor,
      }, historicalShares);
      expect(
        futureExpense.shares.map((share) => share.userId),
        contains('u-rina'),
      );
    },
  );

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
