import 'package:flutter_test/flutter_test.dart';
import 'package:sajha_kharcha/src/app_state.dart';
import 'package:sajha_kharcha/src/finance.dart';
import 'package:sajha_kharcha/src/models.dart';

void main() {
  test('production AppStore starts without local dummy data', () {
    final store = AppStore();

    expect(store.users, isEmpty);
    expect(store.groups, isEmpty);
    expect(store.expenses, isEmpty);
  });

  test('AppStore hydrates visible data from backend snapshot', () {
    final store = AppStore()
      ..loadBackendSnapshot({
        'currentUserId': 'u-sita',
        'users': [
          {
            'id': 'u-sita',
            'displayName': 'Sita Shrestha',
            'phone': '9800000001',
            'avatar': 'SS',
            'district': 'Kathmandu',
            'privacyMode': 'everyone',
            'createdAt': '2026-05-01T00:00:00Z',
          },
        ],
        'groups': [
          {
            'id': 'g-dashain',
            'name': 'Dashain Khasi Split',
            'category': 'festival',
            'template': 'Dashain Khasi Split',
            'kind': 'expense',
            'createdBy': 'u-sita',
            'createdAt': '2026-05-10T00:00:00Z',
          },
        ],
        'groupMembers': [
          {
            'id': 'gm-1',
            'groupId': 'g-dashain',
            'userId': 'u-sita',
            'role': 'admin',
            'status': 'active',
            'joinedAt': '2026-05-10T00:00:00Z',
          },
        ],
        'expenses': [
          {
            'id': 'expense-1',
            'groupId': 'g-dashain',
            'title': 'Khasi purchase',
            'subtotalMinor': 600000,
            'totalMinor': 600000,
            'payerId': 'u-sita',
            'category': 'festival',
            'splitMode': 'equal',
            'status': 'active',
            'expenseDate': '2026-05-18',
            'createdBy': 'u-sita',
            'createdAt': '2026-05-18T10:00:00Z',
          },
        ],
      });

    expect(store.currentUser.displayName, 'Sita Shrestha');
    expect(store.visibleExpenseGroups.single.name, 'Dashain Khasi Split');
    expect(store.expenses.single.title, 'Khasi purchase');
  });

  test('AppStore hydrates connection safety records from backend snapshot', () {
    final store = AppStore()
      ..loadBackendSnapshot({
        'currentUserId': 'u-sita',
        'users': [
          {
            'id': 'u-sita',
            'displayName': 'Sita Shrestha',
            'phone': '9800000001',
            'avatar': 'SS',
            'district': 'Kathmandu',
            'privacyMode': 'everyone',
            'createdAt': '2026-05-01T00:00:00Z',
          },
          {
            'id': 'u-utsav',
            'displayName': 'Utsav Shrestha',
            'phone': '9800000010',
            'avatar': 'US',
            'district': 'Kathmandu',
            'privacyMode': 'everyone',
            'createdAt': '2026-05-01T00:00:00Z',
          },
        ],
        'connections': [
          {
            'id': 'conn-1',
            'requesterId': 'u-sita',
            'recipientId': 'u-utsav',
            'userLowId': 'u-sita',
            'userHighId': 'u-utsav',
            'status': 'approved',
            'createdAt': '2026-05-10T00:00:00Z',
            'updatedAt': '2026-05-10T00:00:00Z',
            'expiresAt': '2026-06-10T00:00:00Z',
          },
        ],
        'connectionEvents': [
          {
            'id': 'event-1',
            'connectionId': 'conn-1',
            'actorId': 'u-sita',
            'eventType': 'blocked',
            'previousStatus': 'approved',
            'nextStatus': 'approved',
            'createdAt': '2026-05-11T00:00:00Z',
          },
        ],
        'connectionBlocks': [
          {
            'id': 'block-1',
            'connectionId': 'conn-1',
            'blockerId': 'u-sita',
            'blockedUserId': 'u-utsav',
            'active': true,
            'createdAt': '2026-05-11T00:00:00Z',
          },
        ],
        'connectionReports': [
          {
            'id': 'report-1',
            'connectionId': 'conn-1',
            'reporterId': 'u-sita',
            'reportedUserId': 'u-utsav',
            'reasonCode': 'safety_review',
            'details': 'Repeated messages',
            'status': 'open',
            'createdAt': '2026-05-11T00:00:00Z',
          },
        ],
      });

    final connection = store.connectionByIdOrNull('conn-1')!;

    expect(connection.events.single.eventType, 'blocked');
    expect(connection.isBlockedBy('u-sita', 'u-utsav'), isTrue);
    expect(connection.hasReportFrom('u-sita', 'u-utsav'), isTrue);
    expect(connection.reports.single.details, 'Repeated messages');
  });

  test('AppStore upserts backend search users and normalizes phone search', () {
    final store = AppStore.seeded();
    store.upsertUser(
      AppUser(
        id: 'u-new',
        displayName: 'Naya Shrestha',
        phone: '+977 980-123-4567',
        avatar: 'NS',
        district: 'Kathmandu',
        createdAt: DateTime(2026, 5, 31),
      ),
    );

    expect(
      store.searchUsers('980123').map((user) => user.id),
      contains('u-new'),
    );
    expect(
      store.searchUsers('kathmandu').map((user) => user.id),
      contains('u-new'),
    );
  });

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
    final store = AppStore.seeded();
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

  test('service charge is stored and included in total math', () {
    final store = AppStore.seeded();
    final groupId = store.createGroup(
      name: 'Service charge test',
      category: GroupCategory.custom,
      memberIds: const ['u-arjun'],
    );

    final expenseId = store.addExpense(
      groupId: groupId,
      title: 'VAT plus service metadata',
      totalMinor: npr(113),
      payerId: 'u-sita',
      category: 'custom',
      splitMode: SplitMode.equal,
      participantIds: const ['u-sita', 'u-arjun'],
      taxMinor: npr(13),
      serviceChargeMinor: npr(10),
    );

    final expense = store.expenses.firstWhere((item) => item.id == expenseId);
    expect(expense.subtotalMinor, npr(90));
    expect(expense.totalMinor, npr(113));
    expect(expense.billServiceChargeMinor, npr(10));
    expect(
      expense.shares.fold<int>(0, (sum, share) => sum + share.amountMinor),
      npr(113),
    );
  });

  test(
    'multiple payer equal split gives rounding to largest included payer',
    () {
      final store = AppStore.seeded();
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
      final store = AppStore.seeded();
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
    final store = AppStore.seeded();
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
    final store = AppStore.seeded();
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
    final store = AppStore.seeded();
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
    final store = AppStore.seeded();
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
    final store = AppStore.seeded();
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

  test('active expense group members can rename groups', () {
    final store = AppStore.seeded();
    final groupId = store.createGroup(
      name: 'Member editable name',
      category: GroupCategory.custom,
      memberIds: const ['u-arjun'],
    );

    store.switchUser('u-arjun');
    expect(store.renameGroup(groupId, 'Member renamed'), isNull);

    expect(store.groupById(groupId).name, 'Member renamed');
  });

  test('Community Savings Tracker admins can rename groups', () {
    final store = AppStore.seeded();

    expect(
      store.renameDhukutiPool('d-family-dashain', 'Family Community Fund'),
      isNull,
    );

    expect(store.poolById('d-family-dashain').name, 'Family Community Fund');
    expect(
      store.activityForGroup('g-shrestha-family').map((item) => item.eventType),
      contains('dhukuti_renamed'),
    );
  });

  test('non-admin members cannot rename Community Savings Tracker groups', () {
    final store = AppStore.seeded()..switchUser('u-arjun');

    expect(
      store.renameDhukutiPool('d-family-dashain', 'Member Community Fund Name'),
      'Only the Community Savings Tracker admin can rename this group.',
    );

    expect(
      store.poolById('d-family-dashain').name,
      'Family Dashain Community Fund',
    );
  });

  test('seeded store keeps group balances zero-sum after settlement', () {
    final store = AppStore.seeded();
    final balances = store.balancesForGroup('g-dashain');

    expect(balances.values.fold<int>(0, (sum, item) => sum + item), 0);
    expect(
      store.expenses
          .where((expense) => expense.groupId == 'g-dashain')
          .every((expense) => expense.lockedAt != null),
      isTrue,
    );
  });

  test(
    'external settlements update balances only after recipient approval',
    () {
      final store = AppStore.seeded();
      final groupId = store.createGroup(
        name: 'Cash settlement test',
        category: GroupCategory.custom,
        memberIds: const ['u-arjun'],
      );
      store.addExpense(
        groupId: groupId,
        title: 'Cash lunch',
        totalMinor: npr(200),
        payerId: 'u-sita',
        category: 'custom',
        splitMode: SplitMode.equal,
        participantIds: const ['u-sita', 'u-arjun'],
      );
      final suggestion = store.suggestionsForGroup(groupId).single;

      store.switchUser('u-arjun');
      final request = store.createOrReuseExternalSettlement(suggestion);

      expect(request.isExternal, isTrue);
      expect(request.status, PaymentStatus.pending);
      expect(store.balanceForUserInGroup(groupId, 'u-arjun'), -npr(100));
      expect(
        store.approveExternalSettlement(request.id),
        'Only the settlement recipient can approve this request.',
      );

      store.switchUser('u-sita');
      expect(store.approveExternalSettlement(request.id), isNull);

      expect(request.status, PaymentStatus.paid);
      expect(store.balancesForGroup(groupId), isEmpty);
      final payment = store.payments.firstWhere(
        (item) => item.id == request.paymentTransactionId,
      );
      expect(payment.paymentProvider, 'external');
      expect(
        store.activityForGroup(groupId).map((item) => item.eventType),
        containsAll([
          'external_settlement_requested',
          'external_settlement_approved',
        ]),
      );
    },
  );

  test('item receipt expenses create auditable item shares', () {
    final store = AppStore.seeded();
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

  test(
    'expense reviews track acceptance correction requests and item disputes',
    () {
      final store = AppStore.seeded();
      final expenseId = store.addExpense(
        groupId: 'g-dashain',
        title: 'Reviewable receipt',
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
          0: ['u-sita', 'u-arjun'],
          1: ['u-arjun'],
        },
      );
      final expense = store.expenses.firstWhere((item) => item.id == expenseId);

      var summary = store.reviewSummaryForExpense(expense);
      expect(summary.accepted, 1); // creator is implicitly accepted
      expect(summary.pending, 1);
      expect(summary.isFinal, isFalse);

      store.currentUserId = 'u-arjun';
      expect(store.acceptExpenseSplit(expenseId), isNull);
      summary = store.reviewSummaryForExpense(expense);
      expect(summary.isFinal, isTrue);

      expect(
        store.requestExpenseCorrection(expenseId, 'Tea should be Sita only'),
        isNull,
      );
      summary = store.reviewSummaryForExpense(expense);
      expect(summary.correctionRequested, 1);
      expect(summary.hasConcerns, isTrue);

      expect(
        store.disputeExpenseItem(
          expenseId: expenseId,
          expenseItemId: expense.items.first.id,
          note: 'I did not eat momo',
        ),
        isNull,
      );
      summary = store.reviewSummaryForExpense(expense);
      expect(summary.itemDisputed, 1);
      expect(
        store.activity.map((item) => item.eventType),
        containsAll([
          'expense_split_accepted',
          'expense_correction_requested',
          'expense_item_disputed',
        ]),
      );
    },
  );

  test(
    'recurring expenses feed smart settlements insights and group ledger',
    () {
      final store = AppStore.seeded();
      final groupId = store.createGroup(
        name: 'Recurring lunch test',
        category: GroupCategory.custom,
        memberIds: const ['u-arjun'],
      );
      store.addExpense(
        groupId: groupId,
        title: 'Shared lunch',
        totalMinor: npr(400),
        payerId: 'u-sita',
        category: 'custom',
        splitMode: SplitMode.equal,
        participantIds: const ['u-sita', 'u-arjun'],
      );

      var plan = store.smartSettlementPlanForGroup(groupId);
      expect(plan.hasRoutes, isTrue);
      expect(plan.blockedExpenseCount, 1);
      expect(plan.statusLabel, 'Review pending');

      store.switchUser('u-arjun');
      final expense = store.expenses.last;
      expect(store.acceptExpenseSplit(expense.id), isNull);
      plan = store.smartSettlementPlanForGroup(groupId);
      expect(plan.isReady, isTrue);

      store.switchUser('u-sita');
      final beforeExpenseCount = store.expenses.length;
      final scheduleId = store.createRecurringExpense(
        groupId: groupId,
        title: 'Monthly internet',
        amountMinor: npr(1800),
        payerId: 'u-sita',
        category: 'household',
        splitMode: SplitMode.equal,
        participantIds: const ['u-sita', 'u-arjun'],
        frequency: RecurringExpenseFrequency.monthly,
        nextDueAt: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(store.dueRecurringExpensesForGroup(groupId), hasLength(1));
      expect(store.postRecurringExpense(scheduleId), isNull);
      expect(store.expenses.length, beforeExpenseCount + 1);

      final schedule = store.recurringExpenses.singleWhere(
        (item) => item.id == scheduleId,
      );
      expect(schedule.lastPostedAt, isNotNull);
      expect(schedule.nextDueAt.isAfter(DateTime.now()), isTrue);

      final ledgerTypes = store
          .groupLedgerEntries(groupId)
          .map((entry) => entry.type)
          .toSet();
      expect(ledgerTypes, containsAll(<String>{'Expense', 'Recurring'}));
      expect(
        store.groupInsights(groupId).map((insight) => insight.title),
        containsAll(<String>{'Settlement readiness', 'Recurring rhythm'}),
      );
      expect(store.groupStatementCsv(groupId), contains('recurring,'));
    },
  );

  test('templates seed recurring schedules and group invite codes', () {
    final store = AppStore.seeded();
    final groupId = store.createGroupFromTemplate('apartment-monthly');

    expect(store.groupById(groupId).template, 'Apartment Monthly');
    expect(
      store.recurringExpensesForGroup(groupId).single.title,
      'Monthly rent and utilities',
    );

    final invite = store.groupInviteCodeFor(groupId);
    store.switchUser('u-pasang');

    expect(store.groupInviteValidationError(invite), isNull);
    expect(store.acceptGroupInvite(invite), 'Joined Apartment Monthly.');
    expect(store.isActiveGroupMember(groupId, 'u-pasang'), isTrue);
    expect(
      store.activityForGroup(groupId).map((item) => item.eventType),
      contains('group_invite_accepted'),
    );
  });

  test('item receipt expenses support item-level share units', () {
    final store = AppStore.seeded();
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
    final store = AppStore.seeded();
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

  test(
    'community savings exit decisions distinguish before-start and obligations',
    () {
      final store = AppStore.seeded();
      final groupId = store.createGroup(
        name: 'Family Community Fund group',
        category: GroupCategory.custom,
        memberIds: const ['u-arjun', 'u-maya'],
      );
      final poolId = store.createDhukutiPool(
        groupId: groupId,
        name: 'Family Community Fund',
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
      expect(
        remainingDecision.type,
        DhukutiExitDecisionType.pendingContribution,
      );
      expect(remainingDecision.amountMinor, npr(10000));
      expect(store.payRemainingDhukutiExitContributions(poolId), npr(10000));
      expect(
        store.dhukutiExitDecision(poolId).type,
        DhukutiExitDecisionType.requiresApproval,
      );
    },
  );

  test('mid-month community savings exit requires all remaining records', () {
    final store = AppStore.seeded();
    final groupId = store.createGroup(
      name: 'Six member Community Fund group',
      category: GroupCategory.custom,
      memberIds: const ['u-arjun', 'u-maya', 'u-nabin', 'u-laxmi', 'u-rina'],
      kind: GroupKind.dhukuti,
    );
    final poolId = store.createDhukutiPool(
      groupId: groupId,
      name: 'Six Month Community Fund',
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
    expect(decision.message, contains('month 3'));
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
    final store = AppStore.seeded();

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

  test('connection reports require a note and block duplicate reports', () {
    final store = AppStore.seeded();
    final connection = store.connectionBetween('u-sita', 'u-maya')!;

    expect(
      store.reportConnection(
        connection.id,
        'u-maya',
        'safety_review',
        note: ' ',
      ),
      contains('note'),
    );
    expect(connection.reports, isEmpty);

    expect(
      store.reportConnection(
        connection.id,
        'u-maya',
        'safety_review',
        note: 'Harassing payment messages',
      ),
      isNull,
    );
    expect(connection.reports, hasLength(1));
    expect(connection.reports.single.details, 'Harassing payment messages');

    expect(
      store.reportConnection(
        connection.id,
        'u-maya',
        'safety_review',
        note: 'Second report for same user',
      ),
      contains('already reported'),
    );
    expect(connection.reports, hasLength(1));
  });

  test('zero-value gifts are rejected', () {
    final store = AppStore.seeded();

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
    final store = AppStore.seeded();
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

  test('gift pools enforce equal amount or min max contribution rules', () {
    final store = AppStore.seeded();

    final equalPoolId = store.createGiftPool(
      groupId: 'g-dashain',
      recipientId: 'u-laxmi',
      title: 'Equal birthday pool',
      template: 'Birthday',
      targetAmountMinor: npr(1000),
      contributionRule: GiftPoolContributionRule.equal,
      allowOverTarget: false,
      equalContributionAmountMinor: npr(500),
      message: 'Equal gift',
    );

    expect(
      store.contributeToGiftPool(equalPoolId, npr(250)),
      contains('equal contribution'),
    );
    expect(
      store.contributeToGiftPool(equalPoolId, npr(500)),
      startsWith('Added'),
    );
    expect(
      store.contributeToGiftPool(equalPoolId, npr(500)),
      contains('already contributed'),
    );

    final thresholdPoolId = store.createGiftPool(
      groupId: 'g-dashain',
      recipientId: 'u-laxmi',
      title: 'Flexible wedding pool',
      template: 'Wedding',
      targetAmountMinor: npr(3000),
      contributionRule: GiftPoolContributionRule.threshold,
      allowOverTarget: false,
      minContributionAmountMinor: npr(250),
      maxContributionAmountMinor: npr(1100),
      message: 'Flexible gift',
    );

    expect(
      store.contributeToGiftPool(thresholdPoolId, npr(100)),
      contains('at least'),
    );
    expect(
      store.contributeToGiftPool(thresholdPoolId, npr(1500)),
      contains('cannot exceed'),
    );
    expect(
      store.contributeToGiftPool(thresholdPoolId, npr(500)),
      startsWith('Added'),
    );

    final uncappedPoolId = store.createGiftPool(
      groupId: 'g-dashain',
      recipientId: 'u-laxmi',
      title: 'Uncapped group pool',
      template: 'Festival',
      targetAmountMinor: npr(500),
      contributionRule: GiftPoolContributionRule.threshold,
      allowOverTarget: true,
      minContributionAmountMinor: npr(250),
      maxContributionAmountMinor: npr(1100),
      message: 'Keep contributing',
    );

    expect(
      store.contributeToGiftPool(uncappedPoolId, npr(500)),
      startsWith('Added'),
    );
    expect(
      store.giftPools.firstWhere((pool) => pool.id == uncappedPoolId).status,
      GiftPoolStatus.open,
    );
    expect(
      store.contributeToGiftPool(uncappedPoolId, npr(250)),
      startsWith('Added'),
    );
    expect(store.giftPoolTotal(uncappedPoolId), npr(750));
  });

  test('QR invites preserve hyphenated user IDs', () {
    final store = AppStore.seeded()..switchUser('u-arjun');
    final code = store.qrInviteCodeFor(
      store.userById('u-kabir'),
      issuedAt: DateTime.now().subtract(const Duration(minutes: 4)),
    );

    expect(code, startsWith('SAJHA-KHARCHA-QR-u-kabir-'));
    expect(store.qrInviteValidationError(code), isNull);
    expect(store.acceptQrInvite(code), 'Request sent to Kabir Lama.');
    expect(
      store.connectionBetween('u-arjun', 'u-kabir')?.status,
      ConnectionStatus.pending,
    );

    final expiredCode = store.qrInviteCodeFor(
      store.userById('u-kabir'),
      issuedAt: DateTime.now().subtract(const Duration(minutes: 6)),
    );
    expect(
      store.qrInviteValidationError(expiredCode),
      'This QR invite expired. Ask for a new QR.',
    );
  });

  test('account deletion is blocked by unsettled balances', () {
    final store = AppStore.seeded();

    expect(store.canDeleteCurrentAccount, isFalse);
    expect(
      store.accountDeletionBlockers,
      containsAll(['You still owe NPR 4020.', 'You are still owed NPR 3400.']),
    );

    store.switchUser('u-kabir');

    expect(store.accountDeletionBlockers, isEmpty);
    expect(store.canDeleteCurrentAccount, isTrue);
  });
}
