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

  test('equal split assigns rounding remainder to included payer', () {
    final shares = equalShares(npr(100), const [
      'u-sita',
      'u-arjun',
      'u-maya',
    ], payerId: 'u-arjun');

    expect(shares, [3333, 3334, 3333]);
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
    'multiple payer equal split gives rounding to largest included payer',
    () {
      final store = AppStore();
      final groupId = store.createGroup(
        name: 'Rounding payer test',
        category: GroupCategory.custom,
        memberIds: const ['u-arjun', 'u-maya'],
      );

      final expenseId = store.addExpense(
        groupId: groupId,
        title: 'Rs 100 split',
        totalMinor: npr(100),
        payerId: 'u-sita',
        payerAmounts: {'u-sita': npr(40), 'u-arjun': npr(60)},
        category: 'custom',
        splitMode: SplitMode.equal,
        participantIds: const ['u-sita', 'u-arjun', 'u-maya'],
      );
      final expense = store.expenses.firstWhere((item) => item.id == expenseId);
      final shares = {
        for (final share in expense.shares) share.userId: share.amountMinor,
      };

      expect(shares['u-arjun'], 3334);
      expect(shares.values.fold<int>(0, (sum, item) => sum + item), npr(100));
    },
  );

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

  test('members can leave active groups without deleting history', () {
    final store = AppStore();
    final groupId = store.createGroup(
      name: 'Leave test',
      category: GroupCategory.custom,
      memberIds: const ['u-arjun'],
    );

    store.switchUser('u-arjun');
    expect(store.visibleGroups.map((group) => group.id), contains(groupId));
    expect(store.leaveGroup(groupId), isNull);

    expect(store.isActiveGroupMember(groupId, 'u-arjun'), isFalse);
    expect(
      store.visibleGroups.map((group) => group.id),
      isNot(contains(groupId)),
    );
    expect(store.groupById(groupId).isDisbanded, isFalse);
  });

  test('members who owe money are blocked from leaving until settled', () {
    final store = AppStore();
    final groupId = store.createGroup(
      name: 'Leave balance test',
      category: GroupCategory.custom,
      memberIds: const ['u-arjun'],
    );
    store.addExpense(
      groupId: groupId,
      title: 'Lunch',
      totalMinor: npr(200),
      payerId: 'u-sita',
      category: 'custom',
      splitMode: SplitMode.equal,
      participantIds: const ['u-sita', 'u-arjun'],
    );

    store.switchUser('u-arjun');
    final decision = store.groupLeaveDecision(groupId);
    expect(decision.type, GroupLeaveDecisionType.owesMoney);
    expect(store.leaveGroup(groupId), contains('settle'));
    expect(store.isActiveGroupMember(groupId, 'u-arjun'), isTrue);

    expect(store.settleCurrentUserInGroup(groupId), 1);
    expect(store.leaveGroup(groupId), isNull);
    expect(store.isActiveGroupMember(groupId, 'u-arjun'), isFalse);
  });

  test('members who are owed can leave with receivables active', () {
    final store = AppStore();
    final groupId = store.createGroup(
      name: 'Receivable leave test',
      category: GroupCategory.custom,
      memberIds: const ['u-arjun'],
    );
    store.addExpense(
      groupId: groupId,
      title: 'Lunch',
      totalMinor: npr(200),
      payerId: 'u-arjun',
      category: 'custom',
      splitMode: SplitMode.equal,
      participantIds: const ['u-sita', 'u-arjun'],
    );

    store.switchUser('u-arjun');
    final decision = store.groupLeaveDecision(groupId);
    expect(decision.type, GroupLeaveDecisionType.receivableActive);
    expect(store.leaveGroup(groupId), isNull);
    expect(store.isActiveGroupMember(groupId, 'u-arjun'), isFalse);
    expect(store.suggestionsForGroup(groupId), isNotEmpty);
  });

  test('admins can disband groups and deactivate all members', () {
    final store = AppStore();
    final groupId = store.createGroup(
      name: 'Disband test',
      category: GroupCategory.custom,
      memberIds: const ['u-arjun', 'u-rina'],
    );

    expect(store.disbandGroup(groupId), isNull);

    expect(store.groupById(groupId).isDisbanded, isTrue);
    expect(store.membersForGroup(groupId, activeOnly: true), isEmpty);
    expect(
      store.visibleGroups.map((group) => group.id),
      isNot(contains(groupId)),
    );
  });

  test('admins can rename groups after creation', () {
    final store = AppStore();
    final groupId = store.createGroup(
      name: 'Old trip name',
      category: GroupCategory.custom,
      memberIds: const ['u-arjun'],
    );

    expect(store.renameGroup(groupId, 'Pokhara Trip'), isNull);

    expect(store.groupById(groupId).name, 'Pokhara Trip');
    expect(
      store.activityForGroup(groupId).map((item) => item.eventType),
      contains('group_renamed'),
    );
  });

  test('non-admin members cannot rename groups', () {
    final store = AppStore();
    final groupId = store.createGroup(
      name: 'Admin only name',
      category: GroupCategory.custom,
      memberIds: const ['u-arjun'],
    );

    store.switchUser('u-arjun');
    expect(
      store.renameGroup(groupId, 'Member renamed'),
      'Only group admins can rename this group.',
    );

    expect(store.groupById(groupId).name, 'Admin only name');
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

  test('item receipt expenses support item-level share units', () {
    final store = AppStore();
    final expenseId = store.addExpense(
      groupId: 'g-dashain',
      title: 'Momo shares',
      totalMinor: npr(300),
      payerId: 'u-sita',
      category: 'festival',
      splitMode: SplitMode.item,
      participantIds: const ['u-sita', 'u-arjun', 'u-maya'],
      receiptItems: [
        ParsedReceiptItem(label: 'Chicken Momo', amountMinor: npr(300)),
      ],
      itemSplitInputs: const {
        0: ItemSplitInput(
          userIds: ['u-sita', 'u-arjun', 'u-maya'],
          shareUnits: {'u-sita': 2, 'u-arjun': 1, 'u-maya': 1},
        ),
      },
    );

    final expense = store.expenses.firstWhere((item) => item.id == expenseId);
    final shares = {
      for (final share in expense.shares) share.userId: share.amountMinor,
    };

    expect(shares['u-sita'], npr(150));
    expect(shares['u-arjun'], npr(75));
    expect(shares['u-maya'], npr(75));
    expect(expense.items.single.assignments.first.splitUnits, 2);
  });

  test('item receipt bill adjustments can be allocated equally', () {
    final store = AppStore();
    final expenseId = store.addExpense(
      groupId: 'g-dashain',
      title: 'Momo with VAT',
      totalMinor: npr(303),
      payerId: 'u-sita',
      category: 'festival',
      splitMode: SplitMode.item,
      participantIds: const ['u-sita', 'u-arjun', 'u-maya'],
      receiptItems: [
        ParsedReceiptItem(label: 'Chicken Momo', amountMinor: npr(300)),
      ],
      itemAssignments: const {
        0: ['u-sita', 'u-arjun', 'u-maya'],
      },
      taxMinor: npr(3),
      equalBillAdjustmentAllocation: true,
    );

    final expense = store.expenses.firstWhere((item) => item.id == expenseId);
    final shares = {
      for (final share in expense.shares) share.userId: share.amountMinor,
    };

    expect(shares.values.toSet(), {npr(101)});
    expect(expense.billTaxMinor, npr(3));
  });

  test('Dhukuti exit decisions distinguish before-start and obligations', () {
    final store = AppStore();
    final groupId = store.createGroup(
      name: 'Family Dhukuti group',
      category: GroupCategory.custom,
      memberIds: const ['u-arjun', 'u-maya'],
    );
    final poolId = store.createDhukutiPool(
      groupId: groupId,
      name: 'Family Dhukuti',
      contributionAmountMinor: npr(5000),
      frequency: 'monthly',
      startDate: DateTime(2026, 6, 1),
      memberIds: const ['u-arjun', 'u-maya'],
    );

    expect(
      store.dhukutiExitDecision(poolId).type,
      DhukutiExitDecisionType.canLeaveBeforeStart,
    );

    store.switchUser('u-arjun');
    store.acceptDhukuti(poolId);
    store.switchUser('u-maya');
    store.acceptDhukuti(poolId);
    store.switchUser('u-sita');

    expect(
      store.dhukutiExitDecision(poolId).type,
      DhukutiExitDecisionType.pendingContribution,
    );

    final contribution = store.dhukutiContributions.firstWhere(
      (item) => item.poolId == poolId && item.userId == 'u-sita',
    );
    store.payDhukutiContribution(contribution.id);
    final remainingDecision = store.dhukutiExitDecision(poolId);
    expect(remainingDecision.type, DhukutiExitDecisionType.pendingContribution);
    expect(remainingDecision.amountMinor, npr(10000));
    expect(store.payRemainingDhukutiExitContributions(poolId), npr(10000));
    expect(
      store.dhukutiExitDecision(poolId).type,
      DhukutiExitDecisionType.requiresApproval,
    );
  });

  test('mid-cycle Dhukuti exit requires all remaining cycle payments', () {
    final store = AppStore();
    final groupId = store.createGroup(
      name: 'Six member Dhukuti group',
      category: GroupCategory.custom,
      memberIds: const ['u-arjun', 'u-maya', 'u-nabin', 'u-laxmi', 'u-rina'],
      kind: GroupKind.dhukuti,
    );
    final poolId = store.createDhukutiPool(
      groupId: groupId,
      name: 'Six Month Dhukuti',
      contributionAmountMinor: npr(5000),
      frequency: 'monthly',
      startDate: DateTime(2026, 6, 1),
      memberIds: const ['u-arjun', 'u-maya', 'u-nabin', 'u-laxmi', 'u-rina'],
    );

    for (final userId in const [
      'u-arjun',
      'u-maya',
      'u-nabin',
      'u-laxmi',
      'u-rina',
    ]) {
      store.switchUser(userId);
      store.acceptDhukuti(poolId);
    }
    store.switchUser('u-sita');

    for (final cycle in store.dhukutiCycles.where(
      (item) => item.poolId == poolId,
    )) {
      cycle.status = switch (cycle.cycleNumber) {
        1 || 2 => DhukutiCycleStatus.paidOut,
        3 => DhukutiCycleStatus.open,
        _ => DhukutiCycleStatus.upcoming,
      };
    }
    for (final contribution in store.dhukutiContributions.where(
      (item) =>
          item.poolId == poolId &&
          item.userId == 'u-sita' &&
          item.cycleNumber < 3,
    )) {
      contribution.status = ContributionStatus.paid;
    }

    final decision = store.dhukutiExitDecision(poolId);
    expect(decision.type, DhukutiExitDecisionType.pendingContribution);
    expect(decision.amountMinor, npr(20000));
    expect(decision.message, contains('Cycle 3'));
    expect(decision.message, contains('Cycles 3-6'));

    expect(store.payRemainingDhukutiExitContributions(poolId), npr(20000));
    expect(
      store.remainingDhukutiExitContributions(poolId, userId: 'u-sita').length,
      0,
    );
    expect(
      store.dhukutiExitDecision(poolId).type,
      DhukutiExitDecisionType.requiresApproval,
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

  test('zero-value gifts are rejected', () {
    final store = AppStore();

    expect(
      store.sendGift(
        recipientId: 'u-maya',
        template: 'Dashain',
        amountMinor: 0,
        message: 'Hello',
      ),
      contains('greater than zero'),
    );
    expect(store.gifts.where((g) => g.amountMinor == 0), isEmpty);
  });

  test('a sent gift is final and can only be opened by the recipient', () {
    final store = AppStore();
    store.sendGift(
      recipientId: 'u-maya',
      template: 'Birthday',
      amountMinor: npr(200),
      message: 'Happy birthday',
    );
    final gift = store.gifts.firstWhere((g) => g.template == 'Birthday');
    expect(gift.status, GiftStatus.sent);

    // The sender cannot open their own gift.
    expect(store.openGift(gift.id), isFalse);
    expect(gift.status, GiftStatus.sent);

    // The recipient can open it once.
    store.switchUser('u-maya');
    expect(store.openGift(gift.id), isTrue);
    expect(gift.status, GiftStatus.opened);
    expect(store.openGift(gift.id), isFalse);
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
