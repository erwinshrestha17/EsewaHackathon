import 'package:flutter/foundation.dart';

import 'finance.dart';
import 'models.dart';

class AppStore extends ChangeNotifier {
  AppStore() {
    _seed();
  }

  final List<AppUser> users = <AppUser>[];
  final List<Connection> connections = <Connection>[];
  final List<Group> groups = <Group>[];
  final List<GroupMember> groupMembers = <GroupMember>[];
  final List<Expense> expenses = <Expense>[];
  final List<Settlement> settlements = <Settlement>[];
  final List<Adjustment> adjustments = <Adjustment>[];
  final List<PaymentTransaction> payments = <PaymentTransaction>[];
  final List<GiftCard> gifts = <GiftCard>[];
  final List<GiftPool> giftPools = <GiftPool>[];
  final List<GiftPoolContribution> giftPoolContributions =
      <GiftPoolContribution>[];
  final List<DhukutiPool> dhukutiPools = <DhukutiPool>[];
  final List<DhukutiMember> dhukutiMembers = <DhukutiMember>[];
  final List<DhukutiCycle> dhukutiCycles = <DhukutiCycle>[];
  final List<DhukutiContribution> dhukutiContributions =
      <DhukutiContribution>[];
  final List<DhukutiPayout> dhukutiPayouts = <DhukutiPayout>[];
  final List<EmergencyExitRequest> emergencyExitRequests =
      <EmergencyExitRequest>[];
  final List<ActivityLog> activity = <ActivityLog>[];
  final List<NotificationItem> notifications = <NotificationItem>[];

  var currentUserId = 'u-sita';
  String? selectedGroupId;
  String? selectedDhukutiPoolId;
  var pushPreviewEnabled = true;
  var cacheWarm = true;

  int _sequence = 1000;

  AppUser get currentUser => userById(currentUserId);

  AppUser userById(String id) => users.firstWhere((user) => user.id == id);

  Group groupById(String id) => groups.firstWhere((group) => group.id == id);

  Group? groupByIdOrNull(String? id) {
    if (id == null) {
      return null;
    }
    for (final group in groups) {
      if (group.id == id) {
        return group;
      }
    }
    return null;
  }

  DhukutiPool poolById(String id) =>
      dhukutiPools.firstWhere((pool) => pool.id == id);

  String nameOf(String userId) => userById(userId).displayName;

  String _id(String prefix) => '$prefix-${_sequence++}';

  DateTime get _now => DateTime.now();

  void switchUser(String userId) {
    currentUserId = userId;
    selectedGroupId = visibleGroups.isEmpty ? null : visibleGroups.first.id;
    selectedDhukutiPoolId = visibleDhukutiPools.isEmpty
        ? null
        : visibleDhukutiPools.first.id;
    notifyListeners();
  }

  List<Group> get visibleGroups {
    final ids = groupMembers
        .where((member) => member.userId == currentUserId)
        .map((member) => member.groupId)
        .toSet();
    return groups.where((group) => ids.contains(group.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<DhukutiPool> get visibleDhukutiPools {
    final ids = dhukutiMembers
        .where((member) => member.userId == currentUserId)
        .map((member) => member.poolId)
        .toSet();
    return dhukutiPools.where((pool) => ids.contains(pool.id)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<AppUser> activeConnectionUsers([String? userId]) {
    final actorId = userId ?? currentUserId;
    return connections
        .where(
          (connection) =>
              connection.hasUser(actorId) &&
              connection.status == ConnectionStatus.approved &&
              !connection.isBlockedBetween(
                actorId,
                connection.otherUserId(actorId),
              ),
        )
        .map((connection) => userById(connection.otherUserId(actorId)))
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  List<Connection> connectionsFor(String userId) {
    return connections
        .where((connection) => connection.hasUser(userId))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Connection? connectionBetween(String a, String b) {
    final pair = _pair(a, b);
    for (final connection in connections) {
      if (connection.userLowId == pair.$1 && connection.userHighId == pair.$2) {
        return connection;
      }
    }
    return null;
  }

  bool canInviteOrGift(String actorId, String otherId) {
    final connection = connectionBetween(actorId, otherId);
    return connection != null &&
        connection.status == ConnectionStatus.approved &&
        !connection.isBlockedBetween(actorId, otherId);
  }

  List<AppUser> searchUsers(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return users.where((user) => user.id != currentUserId).where((user) {
        final connection = connectionBetween(currentUserId, user.id);
        return connection == null ||
            connection.status != ConnectionStatus.approved;
      }).toList()..sort((a, b) => a.displayName.compareTo(b.displayName));
    }
    return users
        .where(
          (user) =>
              user.id != currentUserId &&
              (user.displayName.toLowerCase().contains(normalized) ||
                  user.phone.contains(normalized)),
        )
        .toList();
  }

  String sendConnectionRequest(String targetUserId, {bool viaQr = false}) {
    if (targetUserId == currentUserId) {
      return 'You cannot connect to yourself.';
    }
    final target = userById(targetUserId);
    if (target.privacyMode == PrivacyMode.qrInviteOnly && !viaQr) {
      return '${target.displayName} accepts QR invites only.';
    }
    if (target.privacyMode == PrivacyMode.contactsOnly &&
        connectionBetween(currentUserId, targetUserId) == null) {
      return '${target.displayName} is limiting requests to known contacts.';
    }
    final pair = _pair(currentUserId, targetUserId);
    final existing = connectionBetween(currentUserId, targetUserId);
    if (existing != null) {
      if (existing.isBlockedBetween(currentUserId, targetUserId)) {
        return 'A block is active for this connection.';
      }
      if (existing.status == ConnectionStatus.pending ||
          existing.status == ConnectionStatus.approved) {
        return 'Connection already ${enumLabel(existing.status).toLowerCase()}.';
      }
      final previous = existing.status;
      existing
        ..requesterId = currentUserId
        ..recipientId = targetUserId
        ..status = ConnectionStatus.pending
        ..updatedAt = _now
        ..expiresAt = _now.add(const Duration(days: 14));
      _connectionEvent(existing, 'requested', previous, existing.status);
      _activity(
        actorId: currentUserId,
        eventType: 'connection_requested',
        entityType: 'connection',
        entityId: existing.id,
        title: 'Connection request sent',
        body: '${nameOf(currentUserId)} sent ${target.displayName} a request.',
      );
      _notify(
        targetUserId,
        'connection',
        'New Sangai request',
        '${nameOf(currentUserId)} wants to connect.',
      );
      notifyListeners();
      return 'Request sent to ${target.displayName}.';
    }

    final connection = Connection(
      id: _id('conn'),
      requesterId: currentUserId,
      recipientId: targetUserId,
      userLowId: pair.$1,
      userHighId: pair.$2,
      status: ConnectionStatus.pending,
      createdAt: _now,
      updatedAt: _now,
      expiresAt: _now.add(const Duration(days: 14)),
    );
    connections.add(connection);
    _connectionEvent(connection, 'requested', null, connection.status);
    _activity(
      actorId: currentUserId,
      eventType: 'connection_requested',
      entityType: 'connection',
      entityId: connection.id,
      title: 'Connection request sent',
      body: '${nameOf(currentUserId)} sent ${target.displayName} a request.',
    );
    _notify(
      targetUserId,
      'connection',
      'New Sangai request',
      '${nameOf(currentUserId)} wants to connect.',
    );
    notifyListeners();
    return 'Request sent to ${target.displayName}.';
  }

  void approveConnection(String connectionId) {
    _transitionConnection(connectionId, ConnectionStatus.approved, 'approved');
  }

  void declineConnection(String connectionId) {
    _transitionConnection(connectionId, ConnectionStatus.declined, 'declined');
  }

  void removeConnection(String connectionId) {
    _transitionConnection(connectionId, ConnectionStatus.removed, 'removed');
  }

  void blockConnection(String connectionId, String blockedUserId) {
    final connection = connections.firstWhere(
      (item) => item.id == connectionId,
    );
    connection.blocks.add(
      ConnectionBlock(
        id: _id('block'),
        connectionId: connectionId,
        blockerId: currentUserId,
        blockedUserId: blockedUserId,
        createdAt: _now,
      ),
    );
    _connectionEvent(
      connection,
      'blocked',
      connection.status,
      connection.status,
    );
    _activity(
      actorId: currentUserId,
      eventType: 'connection_blocked',
      entityType: 'connection',
      entityId: connectionId,
      title: 'Connection blocked',
      body: '${nameOf(currentUserId)} blocked ${nameOf(blockedUserId)}.',
    );
    notifyListeners();
  }

  void unblockConnection(String connectionId, String blockedUserId) {
    final connection = connections.firstWhere(
      (item) => item.id == connectionId,
    );
    for (final block in connection.blocks.where(
      (block) =>
          block.active &&
          block.blockerId == currentUserId &&
          block.blockedUserId == blockedUserId,
    )) {
      block
        ..active = false
        ..liftedAt = _now;
    }
    _connectionEvent(
      connection,
      'unblocked',
      connection.status,
      connection.status,
    );
    notifyListeners();
  }

  void reportConnection(
    String connectionId,
    String reportedUserId,
    String reason,
  ) {
    final connection = connections.firstWhere(
      (item) => item.id == connectionId,
    );
    connection.reports.add(
      ConnectionReport(
        id: _id('report'),
        connectionId: connectionId,
        reporterId: currentUserId,
        reportedUserId: reportedUserId,
        reasonCode: reason,
        createdAt: _now,
      ),
    );
    _connectionEvent(
      connection,
      'reported',
      connection.status,
      connection.status,
    );
    _activity(
      actorId: currentUserId,
      eventType: 'connection_reported',
      entityType: 'connection_report',
      entityId: connectionId,
      title: 'Safety report opened',
      body: '${nameOf(currentUserId)} opened a lightweight safety report.',
    );
    notifyListeners();
  }

  void updatePrivacy(PrivacyMode mode) {
    currentUser.privacyMode = mode;
    notifyListeners();
  }

  static const _qrInvitePrefix = 'SANGAI-QR-';

  String qrInviteCodeFor(AppUser user) => '$_qrInvitePrefix${user.id}';

  String? qrInviteValidationError(String code) {
    final targetId = _qrInviteTargetId(code);
    if (targetId == null) {
      return 'That QR invite code is not valid.';
    }
    if (users.every((user) => user.id != targetId)) {
      return 'No demo user matched that invite.';
    }
    return null;
  }

  String acceptQrInvite(String code) {
    final validationError = qrInviteValidationError(code);
    if (validationError != null) {
      return validationError;
    }
    final targetId = _qrInviteTargetId(code)!;
    return sendConnectionRequest(targetId, viaQr: true);
  }

  String? _qrInviteTargetId(String code) {
    final value = code.trim();
    if (!value.startsWith(_qrInvitePrefix)) {
      return null;
    }
    final targetId = value.substring(_qrInvitePrefix.length);
    return targetId.isEmpty ? null : targetId;
  }

  String createGroup({
    required String name,
    required GroupCategory category,
    required List<String> memberIds,
    String template = 'Custom',
  }) {
    final allMembers = <String>{
      currentUserId,
      ...memberIds.where((memberId) {
        return memberId == currentUserId ||
            canInviteOrGift(currentUserId, memberId);
      }),
    };
    final group = Group(
      id: _id('group'),
      name: name,
      category: category,
      template: template,
      createdBy: currentUserId,
      createdAt: _now,
    );
    groups.add(group);
    for (final memberId in allMembers) {
      groupMembers.add(
        GroupMember(
          id: _id('gm'),
          groupId: group.id,
          userId: memberId,
          role: memberId == currentUserId
              ? MemberRole.admin
              : MemberRole.member,
          status: MemberStatus.active,
          joinedAt: _now,
        ),
      );
    }
    selectedGroupId = group.id;
    _activity(
      actorId: currentUserId,
      groupId: group.id,
      eventType: 'group_created',
      entityType: 'group',
      entityId: group.id,
      title: 'Group created',
      body:
          '${nameOf(currentUserId)} created $name with ${allMembers.length} members.',
    );
    notifyListeners();
    return group.id;
  }

  String createFestivalTemplate(String template) {
    final members = activeConnectionUsers()
        .take(template == 'Dashain Khasi Split' ? 5 : 4)
        .map((user) => user.id)
        .toList();
    final groupId = createGroup(
      name: template,
      category: template.contains('Trek')
          ? GroupCategory.trek
          : template.contains('Apartment')
          ? GroupCategory.apartment
          : GroupCategory.festival,
      memberIds: members,
      template: template,
    );
    if (template == 'Dashain Khasi Split') {
      addExpense(
        groupId: groupId,
        title: 'Khasi, masala, transport, and cooking',
        totalMinor: npr(8450),
        payerId: currentUserId,
        category: 'festival',
        splitMode: SplitMode.equal,
        participantIds: members.followedBy(<String>[currentUserId]).toList(),
        note: 'Festival Mode seeded split for a 90-second demo.',
      );
    }
    if (template == 'Tihar Gift Pool' && members.isNotEmpty) {
      createGiftPool(
        groupId: groupId,
        recipientId: members.first,
        title: 'Tihar tika envelope',
        template: 'Tihar',
        targetAmountMinor: npr(5000),
        message: 'For a bright Tihar together.',
      );
    }
    notifyListeners();
    return groupId;
  }

  List<GroupMember> membersForGroup(String groupId, {bool activeOnly = false}) {
    final members = groupMembers.where((member) => member.groupId == groupId);
    if (!activeOnly) {
      return members.toList();
    }
    final activeMembers = members
        .where((member) => member.status == MemberStatus.active)
        .toList();
    final latestByUser = <String, GroupMember>{};
    for (final member in activeMembers) {
      final existing = latestByUser[member.userId];
      if (existing == null || existing.joinedAt.isBefore(member.joinedAt)) {
        latestByUser[member.userId] = member;
      }
    }
    return latestByUser.values.toList()
      ..sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
  }

  GroupMember? memberForGroup(String groupId, String userId) {
    final matches =
        groupMembers
            .where(
              (member) => member.groupId == groupId && member.userId == userId,
            )
            .toList()
          ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
    if (matches.isEmpty) {
      return null;
    }
    return matches.first;
  }

  bool isActiveGroupMember(String groupId, String userId) {
    return groupMembers.any(
      (member) =>
          member.groupId == groupId &&
          member.userId == userId &&
          member.status == MemberStatus.active,
    );
  }

  void addGroupMember(String groupId, String userId, MemberRole role) {
    if (!canInviteOrGift(currentUserId, userId)) {
      return;
    }
    final activeExisting = groupMembers.where(
      (member) =>
          member.groupId == groupId &&
          member.userId == userId &&
          member.status == MemberStatus.active,
    );
    if (activeExisting.isNotEmpty) {
      activeExisting.first.role = role;
    } else {
      groupMembers.add(
        GroupMember(
          id: _id('gm'),
          groupId: groupId,
          userId: userId,
          role: role,
          status: MemberStatus.active,
          joinedAt: _now,
        ),
      );
    }
    _activity(
      actorId: currentUserId,
      groupId: groupId,
      eventType: 'member_added',
      entityType: 'group_member',
      entityId: userId,
      title: 'Member added',
      body: '${nameOf(userId)} joined ${groupById(groupId).name}.',
    );
    notifyListeners();
  }

  void removeGroupMember(String groupId, String userId) {
    final member =
        groupMembers
            .where(
              (member) =>
                  member.groupId == groupId &&
                  member.userId == userId &&
                  member.status == MemberStatus.active,
            )
            .toList()
          ..sort((a, b) => b.joinedAt.compareTo(a.joinedAt));
    if (member.isEmpty) {
      return;
    }
    final activePeriod = member.first;
    activePeriod
      ..status = MemberStatus.removed
      ..removedAt = _now;
    _activity(
      actorId: currentUserId,
      groupId: groupId,
      eventType: 'member_removed',
      entityType: 'group_member',
      entityId: userId,
      title: 'Member removed',
      body:
          '${nameOf(userId)} is inactive for new expenses in ${groupById(groupId).name}.',
    );
    notifyListeners();
  }

  void updateMemberRole(String groupId, String userId, MemberRole role) {
    final member = memberForGroup(groupId, userId);
    if (member == null) {
      return;
    }
    member.role = role;
    _activity(
      actorId: currentUserId,
      groupId: groupId,
      eventType: 'role_changed',
      entityType: 'group_member',
      entityId: userId,
      title: 'Role changed',
      body: '${nameOf(userId)} is now ${enumLabel(role)}.',
    );
    notifyListeners();
  }

  String addExpense({
    required String groupId,
    required String title,
    required int totalMinor,
    required String payerId,
    required String category,
    required SplitMode splitMode,
    required List<String> participantIds,
    String note = '',
    Map<String, int>? payerAmounts,
    Map<String, int>? equalAmounts,
    Map<String, int>? customAmounts,
    Map<String, double>? percentages,
    Map<String, int>? shareUnits,
    List<ParsedReceiptItem>? receiptItems,
    Map<int, List<String>>? itemAssignments,
    int taxMinor = 0,
    int serviceChargeMinor = 0,
    int discountMinor = 0,
    int tipMinor = 0,
  }) {
    final participants = participantIds.toSet().toList();
    if (participants.isEmpty) {
      throw ArgumentError('Choose at least one participant.');
    }
    final paidBy = payerAmounts ?? <String, int>{payerId: totalMinor};
    if (paidBy.isEmpty) {
      throw ArgumentError('Choose at least one payer.');
    }
    validatePayerAmounts(totalMinor, paidBy.values);
    final activeIds = membersForGroup(
      groupId,
      activeOnly: true,
    ).map((member) => member.userId);
    if (!participants.every(activeIds.contains) ||
        !paidBy.keys.every(activeIds.contains)) {
      throw ArgumentError(
        'Payers and participants must be active group members.',
      );
    }

    final expenseId = _id('expense');
    final payers = <ExpensePayer>[
      for (final entry in paidBy.entries)
        if (entry.value > 0)
          ExpensePayer(
            id: _id('expense-payer'),
            expenseId: expenseId,
            userId: entry.key,
            amountMinor: entry.value,
          ),
    ];
    final shares = <ExpenseShare>[];
    final items = <ExpenseItem>[];
    final shareAmounts = <String, int>{};
    final subtotal = receiptItems == null || receiptItems.isEmpty
        ? totalMinor - taxMinor - serviceChargeMinor - tipMinor + discountMinor
        : receiptItems.fold<int>(0, (sum, item) => sum + item.amountMinor);
    final finalTotal = totalMinor;

    switch (splitMode) {
      case SplitMode.equal:
        final amounts = equalAmounts == null
            ? equalShares(finalTotal, participants)
            : participants.map((id) => equalAmounts[id] ?? 0).toList();
        validateCustomShares(finalTotal, amounts);
        for (var i = 0; i < participants.length; i++) {
          shareAmounts[participants[i]] = amounts[i];
        }
      case SplitMode.custom:
        final amounts = participants
            .map((id) => customAmounts?[id] ?? 0)
            .toList();
        validateCustomShares(finalTotal, amounts);
        for (var i = 0; i < participants.length; i++) {
          shareAmounts[participants[i]] = amounts[i];
        }
      case SplitMode.percentage:
        final values = participants.map((id) => percentages?[id] ?? 0).toList();
        final amounts = percentageShares(finalTotal, values);
        for (var i = 0; i < participants.length; i++) {
          shareAmounts[participants[i]] = amounts[i];
        }
      case SplitMode.shares:
        final units = participants.map((id) => shareUnits?[id] ?? 1).toList();
        final amounts = unitShares(finalTotal, units);
        for (var i = 0; i < participants.length; i++) {
          shareAmounts[participants[i]] = amounts[i];
        }
      case SplitMode.item:
        final parsed = receiptItems ?? parseControlledReceipt('');
        var itemIndex = 0;
        for (final parsedItem in parsed) {
          final itemId = _id('item');
          final assignedUsers = itemAssignments?[itemIndex] ?? participants;
          final safeUsers = assignedUsers.isEmpty
              ? participants
              : assignedUsers;
          final itemSplits = equalShares(parsedItem.amountMinor, safeUsers);
          final assignments = <ExpenseItemAssignment>[];
          for (var i = 0; i < safeUsers.length; i++) {
            shareAmounts[safeUsers[i]] =
                (shareAmounts[safeUsers[i]] ?? 0) + itemSplits[i];
            assignments.add(
              ExpenseItemAssignment(
                id: _id('item-assignment'),
                expenseItemId: itemId,
                userId: safeUsers[i],
                assignedAmountMinor: itemSplits[i],
              ),
            );
          }
          items.add(
            ExpenseItem(
              id: itemId,
              expenseId: expenseId,
              label: parsedItem.label,
              quantity: 1,
              unitAmountMinor: parsedItem.amountMinor,
              totalAmountMinor: parsedItem.amountMinor,
              ocrConfidence: parsedItem.confidence,
              sortOrder: itemIndex,
              assignments: assignments,
            ),
          );
          itemIndex += 1;
        }
        final delta =
            finalTotal -
            shareAmounts.values.fold<int>(0, (sum, value) => sum + value);
        if (delta != 0) {
          final weights = participants
              .map((id) => maxInt(shareAmounts[id]?.abs() ?? 0, 1))
              .toList();
          final adjustmentsForDelta = distributeByWeights(delta.abs(), weights);
          for (var i = 0; i < participants.length; i++) {
            final signed = delta.isNegative
                ? -adjustmentsForDelta[i]
                : adjustmentsForDelta[i];
            shareAmounts[participants[i]] =
                (shareAmounts[participants[i]] ?? 0) + signed;
          }
        }
    }

    for (var index = 0; index < participants.length; index++) {
      final participantId = participants[index];
      shares.add(
        ExpenseShare(
          id: _id('share'),
          expenseId: expenseId,
          userId: participantId,
          amountMinor: shareAmounts[participantId] ?? 0,
          percentage: percentages?[participantId],
          shareUnits: shareUnits?[participantId],
          sourceType: splitMode == SplitMode.item ? 'item' : 'manual',
        ),
      );
    }
    validateCustomShares(finalTotal, shares.map((share) => share.amountMinor));

    expenses.add(
      Expense(
        id: expenseId,
        groupId: groupId,
        title: title,
        subtotalMinor: subtotal,
        totalMinor: finalTotal,
        payerId: payerId,
        category: category,
        splitMode: splitMode,
        status: ExpenseStatus.active,
        expenseDate: _now,
        createdBy: currentUserId,
        createdAt: _now,
        note: note,
        billTaxMinor: taxMinor,
        billServiceChargeMinor: serviceChargeMinor,
        billDiscountMinor: discountMinor,
        billTipMinor: tipMinor,
        payers: payers,
        shares: shares,
        items: items,
      ),
    );
    _activity(
      actorId: currentUserId,
      groupId: groupId,
      eventType: 'expense_added',
      entityType: 'expense',
      entityId: expenseId,
      title: 'Expense added',
      body:
          '$title was split ${enumLabel(splitMode).toLowerCase()} for ${money(finalTotal)}.',
    );
    notifyListeners();
    return expenseId;
  }

  bool editExpenseTitle(String expenseId, String title, String note) {
    final expense = expenses.firstWhere((item) => item.id == expenseId);
    if (expense.lockedAt != null) {
      _notify(
        currentUserId,
        'expense_locked',
        'Adjustment required',
        'This expense is locked by a paid settlement. Add a zero-sum adjustment instead.',
      );
      return false;
    }
    expense
      ..title = title
      ..note = note;
    _activity(
      actorId: currentUserId,
      groupId: expense.groupId,
      eventType: 'expense_edited',
      entityType: 'expense',
      entityId: expenseId,
      title: 'Expense edited',
      body: '$title was updated before settlement lock.',
    );
    notifyListeners();
    return true;
  }

  bool voidExpense(String expenseId, String reason) {
    final expense = expenses.firstWhere((item) => item.id == expenseId);
    if (expense.lockedAt != null) {
      _notify(
        currentUserId,
        'expense_locked',
        'Locked expense',
        'Use an adjustment for ${expense.title}; paid settlements already locked it.',
      );
      return false;
    }
    expense
      ..status = ExpenseStatus.voided
      ..voidedAt = _now
      ..voidedBy = currentUserId
      ..voidReason = reason;
    _activity(
      actorId: currentUserId,
      groupId: expense.groupId,
      eventType: 'expense_voided',
      entityType: 'expense',
      entityId: expenseId,
      title: 'Expense voided',
      body: '${expense.title} was voided. Reason: $reason',
    );
    notifyListeners();
    return true;
  }

  String createZeroSumAdjustment({
    required String groupId,
    required String creditUserId,
    required String debitUserId,
    required int amountMinor,
    required String reason,
  }) {
    if (amountMinor <= 0 || creditUserId == debitUserId) {
      throw ArgumentError(
        'Adjustment must move a positive amount between users.',
      );
    }
    final adjustmentId = _id('adjustment');
    adjustments.add(
      Adjustment(
        id: adjustmentId,
        groupId: groupId,
        reason: reason,
        adjustmentType: AdjustmentType.correction,
        createdBy: currentUserId,
        createdAt: _now,
        entries: <AdjustmentEntry>[
          AdjustmentEntry(
            id: _id('adjustment-entry'),
            adjustmentId: adjustmentId,
            userId: creditUserId,
            amountMinor: amountMinor,
            direction: 'credit',
          ),
          AdjustmentEntry(
            id: _id('adjustment-entry'),
            adjustmentId: adjustmentId,
            userId: debitUserId,
            amountMinor: amountMinor,
            direction: 'debit',
          ),
        ],
      ),
    );
    _activity(
      actorId: currentUserId,
      groupId: groupId,
      eventType: 'adjustment_created',
      entityType: 'adjustment',
      entityId: adjustmentId,
      title: 'Zero-sum adjustment',
      body:
          '${nameOf(creditUserId)} credited and ${nameOf(debitUserId)} debited ${money(amountMinor)}.',
    );
    notifyListeners();
    return adjustmentId;
  }

  Map<String, int> balancesForGroup(String groupId) {
    return calculateBalances(
      groupId: groupId,
      members: groupMembers,
      expenses: expenses,
      settlements: settlements,
      adjustments: adjustments,
    );
  }

  int balanceForUserInGroup(String groupId, String userId) {
    return balancesForGroup(groupId)[userId] ?? 0;
  }

  List<SettlementSuggestion> suggestionsForGroup(String groupId) {
    return simplifySettlements(
      groupId: groupId,
      balances: balancesForGroup(groupId),
      settlements: settlements,
    );
  }

  int get totalOwedByCurrentUser {
    var total = 0;
    for (final group in visibleGroups) {
      final balance = balanceForUserInGroup(group.id, currentUserId);
      if (balance < 0) {
        total += balance.abs();
      }
    }
    return total;
  }

  int get totalOwedToCurrentUser {
    var total = 0;
    for (final group in visibleGroups) {
      final balance = balanceForUserInGroup(group.id, currentUserId);
      if (balance > 0) {
        total += balance;
      }
    }
    return total;
  }

  List<Settlement> get pendingSettlementsForCurrentUser {
    return settlements
        .where(
          (settlement) =>
              settlement.status == PaymentStatus.pending &&
              (settlement.payerId == currentUserId ||
                  settlement.payeeId == currentUserId),
        )
        .toList();
  }

  Settlement createOrReuseSettlement(SettlementSuggestion suggestion) {
    final existing = settlements.where(
      (settlement) =>
          settlement.groupId == suggestion.groupId &&
          settlement.payerId == suggestion.payerId &&
          settlement.payeeId == suggestion.payeeId &&
          settlement.amountMinor == suggestion.amountMinor &&
          settlement.status == PaymentStatus.pending,
    );
    if (existing.isNotEmpty) {
      return existing.first;
    }
    final settlement = Settlement(
      id: _id('settlement'),
      groupId: suggestion.groupId,
      payerId: suggestion.payerId,
      payeeId: suggestion.payeeId,
      amountMinor: suggestion.amountMinor,
      status: PaymentStatus.pending,
      idempotencyKey:
          '${suggestion.groupId}-${suggestion.payerId}-${suggestion.payeeId}-${suggestion.amountMinor}',
      idempotencyScope: suggestion.groupId,
      operationType: 'settlement',
      expiresAt: _now.add(const Duration(days: 7)),
      balanceSnapshotHash: balancesForGroup(suggestion.groupId).toString(),
      createdAt: _now,
    );
    settlements.add(settlement);
    _activity(
      actorId: currentUserId,
      groupId: suggestion.groupId,
      eventType: 'settlement_pending',
      entityType: 'settlement',
      entityId: settlement.id,
      title: 'Settlement pending',
      body:
          '${nameOf(suggestion.payerId)} can pay ${nameOf(suggestion.payeeId)} ${money(suggestion.amountMinor)}.',
    );
    notifyListeners();
    return settlement;
  }

  void confirmSettlement(String settlementId, {bool fail = false}) {
    final settlement = settlements.firstWhere(
      (item) => item.id == settlementId,
    );
    final payment = _payment(
      actorId: settlement.payerId,
      entityId: settlement.id,
      entityType: 'settlement',
      operationType: settlement.operationType,
      amountMinor: settlement.amountMinor,
      status: fail ? PaymentStatus.failed : PaymentStatus.paid,
    );
    settlement.paymentTransactionId = payment.id;
    if (fail) {
      settlement
        ..status = PaymentStatus.failed
        ..failureReason = 'Mock provider failure';
      _activity(
        actorId: settlement.payerId,
        groupId: settlement.groupId,
        eventType: 'settlement_failed',
        entityType: 'settlement',
        entityId: settlement.id,
        title: 'Settlement failed',
        body: 'The mock payment was marked as failed.',
      );
    } else {
      settlement
        ..status = PaymentStatus.paid
        ..paidAt = _now;
      final group = groupById(settlement.groupId);
      group.latestSettlementLockAt = settlement.paidAt;
      for (final expense in expenses.where(
        (expense) =>
            expense.groupId == settlement.groupId &&
            expense.status == ExpenseStatus.active &&
            expense.lockedAt == null &&
            !expense.createdAt.isAfter(settlement.paidAt!),
      )) {
        expense.lockedAt = settlement.paidAt;
      }
      _activity(
        actorId: settlement.payerId,
        groupId: settlement.groupId,
        eventType: 'settlement_paid',
        entityType: 'settlement',
        entityId: settlement.id,
        title: 'Settlement paid',
        body:
            '${nameOf(settlement.payerId)} paid ${nameOf(settlement.payeeId)} ${money(settlement.amountMinor)} via Sangai Pay.',
      );
    }
    notifyListeners();
  }

  void cancelSettlement(String settlementId) {
    final settlement = settlements.firstWhere(
      (item) => item.id == settlementId,
    );
    settlement.status = PaymentStatus.cancelled;
    _activity(
      actorId: currentUserId,
      groupId: settlement.groupId,
      eventType: 'settlement_cancelled',
      entityType: 'settlement',
      entityId: settlementId,
      title: 'Settlement cancelled',
      body: 'The pending settlement was cancelled before payment.',
    );
    notifyListeners();
  }

  int settleAllForCurrentUserAcrossGroups() {
    var count = 0;
    for (final group in visibleGroups) {
      for (final suggestion in suggestionsForGroup(group.id)) {
        if (suggestion.payerId == currentUserId) {
          final settlement = createOrReuseSettlement(suggestion);
          confirmSettlement(settlement.id);
          count += 1;
        }
      }
    }
    return count;
  }

  String sendGift({
    required String recipientId,
    required String template,
    required int amountMinor,
    required String message,
  }) {
    if (!canInviteOrGift(currentUserId, recipientId)) {
      return 'Gifts can only be sent to active, unblocked connections.';
    }
    if (amountMinor <= 0) {
      return 'Enter a gift amount greater than zero.';
    }
    final existing = gifts.where(
      (gift) =>
          gift.senderId == currentUserId &&
          gift.idempotencyScope == recipientId &&
          gift.operationType == 'gift' &&
          gift.idempotencyKey == '$recipientId-$amountMinor-$template',
    );
    if (existing.isNotEmpty) {
      return 'Gift already sent with that idempotency key.';
    }
    final gift = GiftCard(
      id: _id('gift'),
      senderId: currentUserId,
      recipientId: recipientId,
      template: template,
      amountMinor: amountMinor,
      message: message,
      status: GiftStatus.sent,
      idempotencyKey: '$recipientId-$amountMinor-$template',
      idempotencyScope: recipientId,
      operationType: 'gift',
      createdAt: _now,
    );
    final payment = _payment(
      actorId: currentUserId,
      entityId: gift.id,
      entityType: 'gift_card',
      operationType: 'gift',
      amountMinor: amountMinor,
      status: PaymentStatus.paid,
    );
    gift.paymentTransactionId = payment.id;
    gifts.add(gift);
    _activity(
      actorId: currentUserId,
      eventType: 'gift_sent',
      entityType: 'gift_card',
      entityId: gift.id,
      title: '$template gift sent',
      body:
          '${nameOf(currentUserId)} sent ${nameOf(recipientId)} ${money(amountMinor)}.',
    );
    _notify(
      recipientId,
      'gift',
      '$template gift received',
      '${nameOf(currentUserId)} sent ${money(amountMinor)}.',
    );
    notifyListeners();
    return 'Gift sent to ${nameOf(recipientId)}.';
  }

  bool openGift(String giftId) {
    final gift = gifts.firstWhere((item) => item.id == giftId);
    if (gift.recipientId == currentUserId && gift.status == GiftStatus.sent) {
      gift
        ..status = GiftStatus.opened
        ..openedAt = _now;
      _activity(
        actorId: currentUserId,
        eventType: 'gift_opened',
        entityType: 'gift_card',
        entityId: giftId,
        title: 'Gift opened',
        body: '${nameOf(currentUserId)} opened a ${gift.template} gift.',
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  // A gift sent to the wrong recipient can be cancelled only while it is still
  // unopened. Cancelling reverses the Sangai Pay payment that delivered it.
  String cancelGift(String giftId) {
    final gift = gifts.firstWhere((item) => item.id == giftId);
    if (gift.senderId != currentUserId) {
      return 'Only the sender can cancel a gift.';
    }
    if (gift.status != GiftStatus.sent) {
      return 'Only an unopened gift can be cancelled.';
    }
    gift
      ..status = GiftStatus.cancelled
      ..refundedAt = _now;
    _reverseGiftPayment(gift);
    _activity(
      actorId: currentUserId,
      eventType: 'gift_cancelled',
      entityType: 'gift_card',
      entityId: giftId,
      title: 'Gift cancelled',
      body: 'The ${gift.template} gift was cancelled before it was opened.',
    );
    _notify(
      gift.recipientId,
      'gift',
      'Gift cancelled',
      'A ${gift.template} gift was cancelled by the sender.',
    );
    notifyListeners();
    return 'Gift cancelled and the Sangai Pay payment was reversed.';
  }

  // Sent gifts cannot be silently deleted; they require a refund. A refund may
  // happen after the recipient has opened the card, in which case the card
  // stays visible with a refunded status and no success celebration.
  String refundGift(String giftId) {
    final gift = gifts.firstWhere((item) => item.id == giftId);
    if (gift.senderId != currentUserId) {
      return 'Only the sender can refund a gift.';
    }
    if (gift.status != GiftStatus.sent && gift.status != GiftStatus.opened) {
      return 'Only a delivered gift can be refunded.';
    }
    gift
      ..status = GiftStatus.refunded
      ..refundedAt = _now;
    _reverseGiftPayment(gift);
    _activity(
      actorId: currentUserId,
      eventType: 'gift_refunded',
      entityType: 'gift_card',
      entityId: giftId,
      title: 'Gift refunded',
      body: 'The ${gift.template} gift was refunded.',
    );
    _notify(
      gift.recipientId,
      'gift',
      'Gift refunded',
      'The ${gift.template} gift was refunded by the sender.',
    );
    notifyListeners();
    return 'Gift refunded through Sangai Pay.';
  }

  void _reverseGiftPayment(GiftCard gift) {
    final payment = payments.firstWhere(
      (item) => item.id == gift.paymentTransactionId,
    );
    payment
      ..status = PaymentStatus.refunded
      ..refundedAt = _now
      ..updatedAt = _now;
  }

  String createGiftPool({
    required String groupId,
    required String recipientId,
    required String title,
    required String template,
    required int targetAmountMinor,
    required String message,
  }) {
    final pool = GiftPool(
      id: _id('gift-pool'),
      groupId: groupId,
      createdBy: currentUserId,
      recipientId: recipientId,
      title: title,
      template: template,
      targetAmountMinor: targetAmountMinor,
      message: message,
      status: GiftPoolStatus.open,
      createdAt: _now,
    );
    giftPools.add(pool);
    _activity(
      actorId: currentUserId,
      groupId: groupId,
      eventType: 'gift_pool_created',
      entityType: 'gift_pool',
      entityId: pool.id,
      title: 'Gift pool created',
      body: '$title opened for ${nameOf(recipientId)}.',
    );
    notifyListeners();
    return pool.id;
  }

  void contributeToGiftPool(String giftPoolId, int amountMinor) {
    final pool = giftPools.firstWhere((item) => item.id == giftPoolId);
    final contribution = GiftPoolContribution(
      id: _id('gift-pool-contribution'),
      giftPoolId: giftPoolId,
      contributorId: currentUserId,
      amountMinor: amountMinor,
      status: PaymentStatus.paid,
      idempotencyKey: '$giftPoolId-$currentUserId-$amountMinor',
      idempotencyScope: giftPoolId,
      operationType: 'gift_pool_contribution',
      createdAt: _now,
      paidAt: _now,
    );
    final payment = _payment(
      actorId: currentUserId,
      entityId: contribution.id,
      entityType: 'gift_pool_contribution',
      operationType: 'gift_pool_contribution',
      amountMinor: amountMinor,
      status: PaymentStatus.paid,
    );
    contribution.paymentTransactionId = payment.id;
    giftPoolContributions.add(contribution);
    if (giftPoolTotal(pool.id) >= pool.targetAmountMinor) {
      pool.status = GiftPoolStatus.completed;
    }
    _activity(
      actorId: currentUserId,
      groupId: pool.groupId,
      eventType: 'gift_pool_contribution',
      entityType: 'gift_pool_contribution',
      entityId: contribution.id,
      title: 'Gift pool contribution',
      body:
          '${nameOf(currentUserId)} added ${money(amountMinor)} to ${pool.title}.',
    );
    notifyListeners();
  }

  int giftPoolTotal(String giftPoolId) {
    return giftPoolContributions
        .where(
          (item) =>
              item.giftPoolId == giftPoolId &&
              item.status == PaymentStatus.paid,
        )
        .fold<int>(0, (sum, item) => sum + item.amountMinor);
  }

  void cancelGiftPool(String giftPoolId) {
    final pool = giftPools.firstWhere((item) => item.id == giftPoolId);
    pool.status = GiftPoolStatus.cancelled;
    _activity(
      actorId: currentUserId,
      groupId: pool.groupId,
      eventType: 'gift_pool_cancelled',
      entityType: 'gift_pool',
      entityId: giftPoolId,
      title: 'Gift pool cancelled',
      body: '${pool.title} was cancelled.',
    );
    notifyListeners();
  }

  String createDhukutiPool({
    required String groupId,
    required String name,
    required int contributionAmountMinor,
    required String frequency,
    required DateTime startDate,
    required List<String> memberIds,
  }) {
    final pool = DhukutiPool(
      id: _id('dhukuti'),
      groupId: groupId,
      name: name,
      contributionAmountMinor: contributionAmountMinor,
      frequency: frequency,
      startDate: startDate,
      createdBy: currentUserId,
      status: DhukutiPoolStatus.active,
      createdAt: _now,
    );
    dhukutiPools.add(pool);
    final members = <String>{currentUserId, ...memberIds};
    var order = 1;
    for (final memberId in members) {
      dhukutiMembers.add(
        DhukutiMember(
          id: _id('dhukuti-member'),
          poolId: pool.id,
          userId: memberId,
          payoutOrder: order,
          status: memberId == currentUserId
              ? DhukutiMemberStatus.active
              : DhukutiMemberStatus.invited,
        ),
      );
      order += 1;
    }
    _generateDhukutiSchedule(pool.id);
    selectedDhukutiPoolId = pool.id;
    _activity(
      actorId: currentUserId,
      groupId: groupId,
      eventType: 'dhukuti_created',
      entityType: 'dhukuti_pool',
      entityId: pool.id,
      title: 'Digital Dhukuti created',
      body: '$name now has a transparent schedule and ledger.',
    );
    notifyListeners();
    return pool.id;
  }

  List<DhukutiMember> membersForPool(String poolId) {
    return dhukutiMembers.where((member) => member.poolId == poolId).toList()
      ..sort((a, b) => a.payoutOrder.compareTo(b.payoutOrder));
  }

  void acceptDhukuti(String poolId) {
    final member = dhukutiMembers.firstWhere(
      (item) => item.poolId == poolId && item.userId == currentUserId,
    );
    member.status = DhukutiMemberStatus.active;
    _activity(
      actorId: currentUserId,
      groupId: poolById(poolId).groupId,
      eventType: 'dhukuti_accepted',
      entityType: 'dhukuti_member',
      entityId: member.id,
      title: 'Dhukuti participation accepted',
      body: '${nameOf(currentUserId)} accepted the Dhukuti invite.',
    );
    notifyListeners();
  }

  void declineDhukuti(String poolId) {
    final member = dhukutiMembers.firstWhere(
      (item) => item.poolId == poolId && item.userId == currentUserId,
    );
    member.status = DhukutiMemberStatus.declined;
    _activity(
      actorId: currentUserId,
      groupId: poolById(poolId).groupId,
      eventType: 'dhukuti_declined',
      entityType: 'dhukuti_member',
      entityId: member.id,
      title: 'Dhukuti invite declined',
      body: '${nameOf(currentUserId)} declined the Dhukuti invite.',
    );
    notifyListeners();
  }

  void payDhukutiContribution(String contributionId) {
    final contribution = dhukutiContributions.firstWhere(
      (item) => item.id == contributionId,
    );
    final existing = payments.where(
      (payment) =>
          payment.actorId == currentUserId &&
          payment.operationType == contribution.operationType &&
          payment.entityId == contribution.id &&
          payment.status == PaymentStatus.paid,
    );
    if (existing.isNotEmpty) {
      return;
    }
    final payment = _payment(
      actorId: currentUserId,
      entityId: contribution.id,
      entityType: 'dhukuti_contribution',
      operationType: contribution.operationType,
      amountMinor: contribution.amountMinor,
      status: PaymentStatus.paid,
    );
    contribution
      ..status = ContributionStatus.paid
      ..paymentTransactionId = payment.id
      ..paidAt = _now;
    _refreshDhukutiCycles(contribution.poolId);
    _activity(
      actorId: currentUserId,
      groupId: poolById(contribution.poolId).groupId,
      eventType: 'dhukuti_contribution_paid',
      entityType: 'dhukuti_contribution',
      entityId: contribution.id,
      title: 'Dhukuti contribution paid',
      body:
          '${nameOf(currentUserId)} paid ${money(contribution.amountMinor)} for cycle ${contribution.cycleNumber}.',
    );
    notifyListeners();
  }

  void requestEmergencyExit(String poolId, String reason) {
    emergencyExitRequests.add(
      EmergencyExitRequest(
        id: _id('exit'),
        poolId: poolId,
        userId: currentUserId,
        reason: reason,
        createdAt: _now,
      ),
    );
    _activity(
      actorId: currentUserId,
      groupId: poolById(poolId).groupId,
      eventType: 'dhukuti_exit_requested',
      entityType: 'dhukuti_exit',
      entityId: poolId,
      title: 'Emergency exit requested',
      body: '${nameOf(currentUserId)} requested organizer review.',
    );
    notifyListeners();
  }

  void approveEmergencyExit(String requestId) {
    final request = emergencyExitRequests.firstWhere(
      (item) => item.id == requestId,
    );
    request.status = 'approved';
    final member = dhukutiMembers.firstWhere(
      (item) => item.poolId == request.poolId && item.userId == request.userId,
    );
    member.status = DhukutiMemberStatus.exited;
    notifyListeners();
  }

  List<DhukutiContribution> contributionsForPool(String poolId) {
    return dhukutiContributions
        .where((contribution) => contribution.poolId == poolId)
        .toList()
      ..sort((a, b) {
        final byCycle = a.cycleNumber.compareTo(b.cycleNumber);
        if (byCycle != 0) {
          return byCycle;
        }
        return a.dueDate.compareTo(b.dueDate);
      });
  }

  List<ActivityLog> activityForGroup(String groupId) {
    return activity.where((item) => item.groupId == groupId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<ActivityLog> get visibleActivity {
    final visibleGroupIds = visibleGroups.map((group) => group.id).toSet();
    return activity.where((item) {
      return item.groupId == null ||
          visibleGroupIds.contains(item.groupId) ||
          item.actorId == currentUserId;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<NotificationItem> get currentNotifications {
    return notifications.where((item) => item.userId == currentUserId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void markNotificationsRead() {
    for (final notification in currentNotifications) {
      notification.read = true;
    }
    notifyListeners();
  }

  void togglePushPreview() {
    pushPreviewEnabled = !pushPreviewEnabled;
    notifyListeners();
  }

  void refreshCache() {
    cacheWarm = true;
    _activity(
      actorId: null,
      actorType: 'system',
      eventType: 'cache_refreshed',
      entityType: 'local_cache',
      entityId: 'demo-cache',
      title: 'Local cache refreshed',
      body:
          'Frontend cache projection refreshed for offline demo responsiveness.',
    );
    notifyListeners();
  }

  String groupStatementCsv(String groupId) {
    final buffer = StringBuffer();
    buffer.writeln('type,date,title,actor,counterparty,amount,status');
    for (final expense in expenses.where((item) => item.groupId == groupId)) {
      final payerNames = expense.payers.isEmpty
          ? nameOf(expense.payerId)
          : expense.payers.map((payer) => nameOf(payer.userId)).join(' + ');
      buffer.writeln(
        'expense,${expense.createdAt.toIso8601String()},${expense.title},$payerNames,,${expense.totalMinor},${enumLabel(expense.status)}',
      );
      for (final payer in expense.payers) {
        buffer.writeln(
          'expense_payer,${expense.createdAt.toIso8601String()},${expense.title},${nameOf(payer.userId)},,${payer.amountMinor},paid',
        );
      }
      for (final share in expense.shares) {
        buffer.writeln(
          'expense_share,${expense.createdAt.toIso8601String()},${expense.title},${nameOf(share.userId)},$payerNames,${share.amountMinor},active',
        );
      }
    }
    for (final settlement in settlements.where(
      (item) => item.groupId == groupId,
    )) {
      buffer.writeln(
        'settlement,${settlement.createdAt.toIso8601String()},Settlement,${nameOf(settlement.payerId)},${nameOf(settlement.payeeId)},${settlement.amountMinor},${enumLabel(settlement.status)}',
      );
    }
    for (final adjustment in adjustments.where(
      (item) => item.groupId == groupId,
    )) {
      for (final entry in adjustment.entries) {
        buffer.writeln(
          'adjustment,${adjustment.createdAt.toIso8601String()},${adjustment.reason},${nameOf(entry.userId)},,${entry.amountMinor},${entry.direction}',
        );
      }
    }
    return buffer.toString();
  }

  Map<String, int> get analytics {
    return <String, int>{
      'connections': connections
          .where((connection) => connection.status == ConnectionStatus.approved)
          .length,
      'groups': groups.length,
      'expenses': expenses.length,
      'settlements': settlements.length,
      'gifts': gifts.length,
      'dhukutiContributions': dhukutiContributions
          .where((item) => item.status == ContributionStatus.paid)
          .length,
      'paymentIntents': payments.length,
    };
  }

  void _transitionConnection(
    String connectionId,
    ConnectionStatus status,
    String eventType,
  ) {
    final connection = connections.firstWhere(
      (item) => item.id == connectionId,
    );
    final previous = connection.status;
    connection
      ..status = status
      ..updatedAt = _now;
    _connectionEvent(connection, eventType, previous, status);
    _activity(
      actorId: currentUserId,
      eventType: 'connection_$eventType',
      entityType: 'connection',
      entityId: connectionId,
      title: 'Connection ${enumLabel(status).toLowerCase()}',
      body:
          '${nameOf(currentUserId)} marked the connection with ${nameOf(connection.otherUserId(currentUserId))} as ${enumLabel(status).toLowerCase()}.',
    );
    notifyListeners();
  }

  void _connectionEvent(
    Connection connection,
    String eventType,
    ConnectionStatus? previous,
    ConnectionStatus? next,
  ) {
    connection.events.add(
      ConnectionEvent(
        id: _id('conn-event'),
        connectionId: connection.id,
        actorId: currentUserId,
        eventType: eventType,
        previousStatus: previous,
        nextStatus: next,
        createdAt: _now,
      ),
    );
  }

  PaymentTransaction _payment({
    required String actorId,
    required String entityId,
    required String entityType,
    required String operationType,
    required int amountMinor,
    required PaymentStatus status,
  }) {
    final payment = PaymentTransaction(
      id: _id('payment'),
      paymentProvider: 'sangai_pay',
      paymentReference: 'TXN-${_sequence + 777}',
      operationType: operationType,
      entityType: entityType,
      entityId: entityId,
      actorId: actorId,
      amountMinor: amountMinor,
      status: status,
      createdAt: _now,
      updatedAt: _now,
      confirmedAt: status == PaymentStatus.paid ? _now : null,
      failedAt: status == PaymentStatus.failed ? _now : null,
      rawPayload:
          '{"provider":"sangai_pay","entity":"$entityType","amount_minor":$amountMinor}',
    );
    payments.add(payment);
    return payment;
  }

  void _notify(String userId, String type, String title, String body) {
    notifications.add(
      NotificationItem(
        id: _id('notification'),
        userId: userId,
        type: type,
        title: title,
        body: body,
        createdAt: _now,
      ),
    );
  }

  void _activity({
    required String? actorId,
    required String eventType,
    required String entityType,
    required String entityId,
    required String title,
    required String body,
    String? groupId,
    String actorType = 'user',
  }) {
    activity.add(
      ActivityLog(
        id: _id('activity'),
        actorId: actorId,
        actorType: actorType,
        eventType: eventType,
        entityType: entityType,
        entityId: entityId,
        groupId: groupId,
        title: title,
        body: body,
        createdAt: _now,
      ),
    );
  }

  void _generateDhukutiSchedule(String poolId) {
    final pool = poolById(poolId);
    final activeMembers = membersForPool(poolId);
    final memberIds = activeMembers.map((member) => member.userId).toList();
    for (var i = 0; i < memberIds.length; i++) {
      final cycleId = _id('dhukuti-cycle');
      final dueDate = DateTime(
        pool.startDate.year,
        pool.startDate.month + i,
        15,
      );
      dhukutiCycles.add(
        DhukutiCycle(
          id: cycleId,
          poolId: poolId,
          cycleNumber: i + 1,
          dueDate: dueDate,
          payoutRecipientId: memberIds[i],
          expectedContributionTotalMinor:
              pool.contributionAmountMinor * memberIds.length,
          paidContributionTotalMinor: 0,
          status: i == 0
              ? DhukutiCycleStatus.open
              : DhukutiCycleStatus.upcoming,
        ),
      );
      for (final memberId in memberIds) {
        dhukutiContributions.add(
          DhukutiContribution(
            id: _id('dhukuti-contribution'),
            poolId: poolId,
            cycleId: cycleId,
            userId: memberId,
            cycleNumber: i + 1,
            dueDate: dueDate,
            amountMinor: pool.contributionAmountMinor,
            status: i == 0
                ? ContributionStatus.due
                : ContributionStatus.pending,
            idempotencyKey: '$poolId-$memberId-${i + 1}',
            idempotencyScope: poolId,
            operationType: 'dhukuti_contribution',
          ),
        );
      }
      dhukutiPayouts.add(
        DhukutiPayout(
          id: _id('dhukuti-payout'),
          poolId: poolId,
          cycleId: cycleId,
          recipientId: memberIds[i],
          amountMinor: pool.contributionAmountMinor * memberIds.length,
          status: PayoutStatus.pending,
          idempotencyKey: '$poolId-payout-${i + 1}',
          idempotencyScope: poolId,
          operationType: 'dhukuti_payout',
        ),
      );
    }
  }

  void _refreshDhukutiCycles(String poolId) {
    for (final cycle in dhukutiCycles.where(
      (cycle) => cycle.poolId == poolId,
    )) {
      final contributions = dhukutiContributions.where(
        (item) => item.cycleId == cycle.id,
      );
      final paid = contributions
          .where((item) => item.status == ContributionStatus.paid)
          .fold<int>(0, (sum, item) => sum + item.amountMinor);
      cycle.paidContributionTotalMinor = paid;
      if (paid == cycle.expectedContributionTotalMinor) {
        cycle.status = DhukutiCycleStatus.readyForPayout;
      } else if (contributions.any(
        (item) =>
            item.status == ContributionStatus.late ||
            item.status == ContributionStatus.missed,
      )) {
        cycle.status = DhukutiCycleStatus.atRisk;
      } else if (!cycle.dueDate.isAfter(_now)) {
        cycle.status = DhukutiCycleStatus.open;
      }
    }
  }

  (String, String) _pair(String a, String b) {
    return a.compareTo(b) < 0 ? (a, b) : (b, a);
  }

  int maxInt(int a, int b) => a > b ? a : b;

  void _seed() {
    final created = DateTime(2026, 5, 1, 10);
    users.addAll(<AppUser>[
      AppUser(
        id: 'u-sita',
        displayName: 'Sita Shrestha',
        phone: '9800000001',
        avatar: 'SS',
        district: 'Kathmandu',
        createdAt: created,
      ),
      AppUser(
        id: 'u-arjun',
        displayName: 'Arjun Karki',
        phone: '9800000002',
        avatar: 'AK',
        district: 'Lalitpur',
        createdAt: created,
      ),
      AppUser(
        id: 'u-maya',
        displayName: 'Maya Gurung',
        phone: '9800000003',
        avatar: 'MG',
        district: 'Pokhara',
        createdAt: created,
      ),
      AppUser(
        id: 'u-nabin',
        displayName: 'Nabin Rai',
        phone: '9800000004',
        avatar: 'NR',
        district: 'Dharan',
        createdAt: created,
      ),
      AppUser(
        id: 'u-laxmi',
        displayName: 'Laxmi Thapa',
        phone: '9800000005',
        avatar: 'LT',
        district: 'Bhaktapur',
        createdAt: created,
      ),
      AppUser(
        id: 'u-kabir',
        displayName: 'Kabir Lama',
        phone: '9800000006',
        avatar: 'KL',
        district: 'Chitwan',
        createdAt: created,
        privacyMode: PrivacyMode.qrInviteOnly,
      ),
      AppUser(
        id: 'u-rina',
        displayName: 'Rina Basnet',
        phone: '9800000007',
        avatar: 'RB',
        district: 'Butwal',
        createdAt: created,
      ),
      AppUser(
        id: 'u-pasang',
        displayName: 'Pasang Sherpa',
        phone: '9800000008',
        avatar: 'PS',
        district: 'Solukhumbu',
        createdAt: created,
      ),
    ]);

    void approved(String a, String b) {
      final pair = _pair(a, b);
      final connection = Connection(
        id: _id('conn'),
        requesterId: a,
        recipientId: b,
        userLowId: pair.$1,
        userHighId: pair.$2,
        status: ConnectionStatus.approved,
        createdAt: DateTime(2026, 5, 4),
        updatedAt: DateTime(2026, 5, 4),
        expiresAt: DateTime(2026, 6, 4),
      );
      connections.add(connection);
      connection.events.add(
        ConnectionEvent(
          id: _id('conn-event'),
          connectionId: connection.id,
          actorId: b,
          eventType: 'approved',
          previousStatus: ConnectionStatus.pending,
          nextStatus: ConnectionStatus.approved,
          createdAt: DateTime(2026, 5, 4),
        ),
      );
    }

    for (final friend in <String>[
      'u-arjun',
      'u-maya',
      'u-nabin',
      'u-laxmi',
      'u-rina',
      'u-pasang',
    ]) {
      approved('u-sita', friend);
    }
    approved('u-arjun', 'u-maya');
    approved('u-arjun', 'u-nabin');
    approved('u-maya', 'u-laxmi');
    final pendingPair = _pair('u-kabir', 'u-sita');
    connections.add(
      Connection(
        id: _id('conn'),
        requesterId: 'u-kabir',
        recipientId: 'u-sita',
        userLowId: pendingPair.$1,
        userHighId: pendingPair.$2,
        status: ConnectionStatus.pending,
        createdAt: DateTime(2026, 5, 27),
        updatedAt: DateTime(2026, 5, 27),
        expiresAt: DateTime(2026, 6, 10),
      ),
    );

    final dashain = Group(
      id: 'g-dashain',
      name: 'Dashain Khasi Split',
      category: GroupCategory.festival,
      template: 'Dashain Khasi Split',
      createdBy: 'u-sita',
      createdAt: DateTime(2026, 5, 10),
    );
    final trek = Group(
      id: 'g-trek',
      name: 'Mardi Trek Crew',
      category: GroupCategory.trek,
      template: 'New Year Trek',
      createdBy: 'u-maya',
      createdAt: DateTime(2026, 5, 12),
    );
    final apartment = Group(
      id: 'g-apartment',
      name: 'Kupondole Apartment',
      category: GroupCategory.apartment,
      template: 'Apartment Monthly',
      createdBy: 'u-arjun',
      createdAt: DateTime(2026, 5, 13),
    );
    groups.addAll(<Group>[dashain, trek, apartment]);
    selectedGroupId = dashain.id;

    void member(String groupId, String userId, MemberRole role) {
      groupMembers.add(
        GroupMember(
          id: _id('gm'),
          groupId: groupId,
          userId: userId,
          role: role,
          status: MemberStatus.active,
          joinedAt: DateTime(2026, 5, 10),
        ),
      );
    }

    for (final memberId in <String>[
      'u-sita',
      'u-arjun',
      'u-maya',
      'u-nabin',
      'u-laxmi',
      'u-rina',
    ]) {
      member(
        dashain.id,
        memberId,
        memberId == 'u-sita' ? MemberRole.admin : MemberRole.member,
      );
    }
    member(trek.id, 'u-sita', MemberRole.member);
    member(trek.id, 'u-maya', MemberRole.admin);
    member(trek.id, 'u-pasang', MemberRole.treasurer);
    member(trek.id, 'u-arjun', MemberRole.member);
    member(apartment.id, 'u-sita', MemberRole.member);
    member(apartment.id, 'u-arjun', MemberRole.admin);
    member(apartment.id, 'u-laxmi', MemberRole.treasurer);

    addExpense(
      groupId: dashain.id,
      title: 'Khasi purchase',
      totalMinor: npr(6000),
      payerId: 'u-sita',
      category: 'festival',
      splitMode: SplitMode.equal,
      participantIds: <String>[
        'u-sita',
        'u-arjun',
        'u-maya',
        'u-nabin',
        'u-laxmi',
        'u-rina',
      ],
      note: 'Main Dashain khasi bill.',
    );
    addExpense(
      groupId: dashain.id,
      title: 'Masala and cooking',
      totalMinor: npr(1800),
      payerId: 'u-arjun',
      category: 'festival',
      splitMode: SplitMode.custom,
      participantIds: <String>[
        'u-sita',
        'u-arjun',
        'u-maya',
        'u-nabin',
        'u-laxmi',
        'u-rina',
      ],
      customAmounts: <String, int>{
        'u-sita': npr(300),
        'u-arjun': npr(300),
        'u-maya': npr(300),
        'u-nabin': npr(300),
        'u-laxmi': npr(300),
        'u-rina': npr(300),
      },
    );
    addExpense(
      groupId: trek.id,
      title: 'Jeep advance',
      totalMinor: npr(12000),
      payerId: 'u-pasang',
      category: 'travel',
      splitMode: SplitMode.shares,
      participantIds: <String>['u-sita', 'u-maya', 'u-pasang', 'u-arjun'],
      shareUnits: <String, int>{
        'u-sita': 1,
        'u-maya': 1,
        'u-pasang': 2,
        'u-arjun': 1,
      },
    );
    addExpense(
      groupId: apartment.id,
      title: 'May utilities',
      totalMinor: npr(5400),
      payerId: 'u-laxmi',
      category: 'household',
      splitMode: SplitMode.percentage,
      participantIds: <String>['u-sita', 'u-arjun', 'u-laxmi'],
      percentages: <String, double>{'u-sita': 30, 'u-arjun': 35, 'u-laxmi': 35},
    );

    final firstSuggestion = suggestionsForGroup(dashain.id).firstWhere(
      (suggestion) => suggestion.payerId == 'u-nabin',
      orElse: () => suggestionsForGroup(dashain.id).first,
    );
    final pending = createOrReuseSettlement(firstSuggestion);
    confirmSettlement(pending.id);

    sendGift(
      recipientId: 'u-maya',
      template: 'Dashain',
      amountMinor: npr(1000),
      message: 'Happy Dashain, Maya!',
    );
    createGiftPool(
      groupId: dashain.id,
      recipientId: 'u-laxmi',
      title: 'Tihar Gift Pool',
      template: 'Tihar',
      targetAmountMinor: npr(5000),
      message: 'A group envelope for Laxmi.',
    );

    final pool = DhukutiPool(
      id: 'd-maitri',
      groupId: dashain.id,
      name: 'Maitri Digital Dhukuti',
      contributionAmountMinor: npr(2000),
      frequency: 'monthly',
      startDate: DateTime(2026, 5, 15),
      createdBy: 'u-sita',
      status: DhukutiPoolStatus.active,
      createdAt: DateTime(2026, 5, 15),
    );
    dhukutiPools.add(pool);
    selectedDhukutiPoolId = pool.id;
    for (var i = 0; i < 6; i++) {
      final memberId = <String>[
        'u-sita',
        'u-arjun',
        'u-maya',
        'u-nabin',
        'u-laxmi',
        'u-rina',
      ][i];
      dhukutiMembers.add(
        DhukutiMember(
          id: _id('dhukuti-member'),
          poolId: pool.id,
          userId: memberId,
          payoutOrder: i + 1,
          status: DhukutiMemberStatus.active,
        ),
      );
    }
    _generateDhukutiSchedule(pool.id);
    for (final contribution
        in dhukutiContributions
            .where((item) => item.poolId == pool.id && item.cycleNumber == 1)
            .take(4)) {
      final payment = _payment(
        actorId: contribution.userId,
        entityId: contribution.id,
        entityType: 'dhukuti_contribution',
        operationType: 'dhukuti_contribution',
        amountMinor: contribution.amountMinor,
        status: PaymentStatus.paid,
      );
      contribution
        ..status = ContributionStatus.paid
        ..paidAt = DateTime(2026, 5, 22)
        ..paymentTransactionId = payment.id;
    }
    final lateContribution = dhukutiContributions.firstWhere(
      (item) => item.poolId == pool.id && item.userId == 'u-laxmi',
    );
    lateContribution.status = ContributionStatus.late;
    _refreshDhukutiCycles(pool.id);

    _activity(
      actorId: null,
      actorType: 'system',
      groupId: dashain.id,
      eventType: 'dhukuti_seeded',
      entityType: 'dhukuti_pool',
      entityId: pool.id,
      title: 'Seeded Dhukuti ledger ready',
      body:
          'Contribution schedule, payout order, and at-risk cycle are visible.',
    );
    _notify(
      'u-sita',
      'nudge',
      'Gentle settlement nudge',
      'Arjun and Maya still have open Dashain balances. Send a neutral reminder after 3 days.',
    );
    _notify(
      'u-sita',
      'dhukuti',
      'Dhukuti cycle at risk',
      'One contribution is late before this cycle can be ready for payout.',
    );
  }
}
