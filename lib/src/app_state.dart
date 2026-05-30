import 'package:flutter/foundation.dart';

import '../features/auth/models/user_profile.dart';
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
  final List<SavingsCirclePool> savingsCirclePools = <SavingsCirclePool>[];
  final List<SavingsCircleMember> savingsCircleMembers =
      <SavingsCircleMember>[];
  final List<SavingsCircleCycle> savingsCircleCycles = <SavingsCircleCycle>[];
  final List<SavingsCircleContribution> savingsCircleContributions =
      <SavingsCircleContribution>[];
  final List<SavingsCirclePayout> savingsCirclePayouts =
      <SavingsCirclePayout>[];
  final List<EmergencyExitRequest> emergencyExitRequests =
      <EmergencyExitRequest>[];
  final List<ActivityLog> activity = <ActivityLog>[];
  final List<NotificationItem> notifications = <NotificationItem>[];

  var currentUserId = 'u-sita';
  String? selectedGroupId;
  String? selectedSavingsCirclePoolId;
  var pushPreviewEnabled = true;
  var cacheWarm = true;

  int _sequence = 1000;

  AppUser get currentUser => userById(currentUserId);

  AppUser userById(String id) => users.firstWhere((user) => user.id == id);

  void applyActiveUserProfile(UserProfile profile) {
    final index = users.indexWhere((user) => user.id == profile.id);
    final existing = index == -1 ? null : users[index];
    final updated = AppUser(
      id: profile.id,
      displayName: profile.displayName,
      phone: profile.phone,
      avatar: profile.initials,
      district: profile.district,
      createdAt: profile.createdAt,
      privacyMode: existing?.privacyMode ?? PrivacyMode.everyone,
    );
    final changed =
        existing == null ||
        existing.displayName != updated.displayName ||
        existing.phone != updated.phone ||
        existing.avatar != updated.avatar ||
        existing.district != updated.district ||
        currentUserId != profile.id;
    if (!changed) {
      return;
    }
    if (index == -1) {
      users.add(updated);
    } else {
      users[index] = updated;
    }
    currentUserId = profile.id;
    selectedGroupId = null;
    selectedSavingsCirclePoolId = visibleSavingsCirclePools.isEmpty
        ? null
        : visibleSavingsCirclePools.first.id;
    notifyListeners();
  }

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

  SavingsCirclePool poolById(String id) =>
      savingsCirclePools.firstWhere((pool) => pool.id == id);

  SavingsCirclePool? poolByIdOrNull(String? id) {
    if (id == null) {
      return null;
    }
    for (final pool in savingsCirclePools) {
      if (pool.id == id) {
        return pool;
      }
    }
    return null;
  }

  String nameOf(String userId) => userById(userId).displayName;

  String _id(String prefix) => '$prefix-${_sequence++}';

  DateTime get _now => DateTime.now();

  void switchUser(String userId) {
    currentUserId = userId;
    selectedGroupId = null;
    selectedSavingsCirclePoolId = visibleSavingsCirclePools.isEmpty
        ? null
        : visibleSavingsCirclePools.first.id;
    notifyListeners();
  }

  List<Group> get visibleGroups {
    final ids = groupMembers
        .where(
          (member) =>
              member.userId == currentUserId &&
              member.status == MemberStatus.active,
        )
        .map((member) => member.groupId)
        .toSet();
    return groups
        .where((group) => ids.contains(group.id) && !group.isDisbanded)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<Group> get visibleExpenseGroups {
    return visibleGroups
        .where((group) => group.kind == GroupKind.expense)
        .toList();
  }

  List<Group> get visibleSavingsCircleGroups {
    return visibleGroups
        .where((group) => group.kind == GroupKind.savingsCircle)
        .toList();
  }

  List<SavingsCirclePool> get visibleSavingsCirclePools {
    final ids = savingsCircleMembers
        .where((member) => member.userId == currentUserId)
        .map((member) => member.poolId)
        .toSet();
    return savingsCirclePools.where((pool) => ids.contains(pool.id)).toList()
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
        'New Sajha Kharcha request',
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
      'New Sajha Kharcha request',
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
    GroupKind kind = GroupKind.expense,
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
      kind: kind,
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
    if (kind == GroupKind.expense) {
      selectedGroupId = group.id;
    }
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

  bool isGroupAdmin(String groupId, String userId) {
    return groupMembers.any(
      (member) =>
          member.groupId == groupId &&
          member.userId == userId &&
          member.role == MemberRole.admin &&
          member.status == MemberStatus.active,
    );
  }

  String? renameGroup(String groupId, String name) {
    final group = groupByIdOrNull(groupId);
    if (group == null || group.isDisbanded) {
      return 'Group is no longer available.';
    }
    if (!isGroupAdmin(groupId, currentUserId)) {
      return 'Only group admins can rename this group.';
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'Group name cannot be empty.';
    }
    if (trimmed == group.name) {
      return null;
    }
    final previousName = group.name;
    group.name = trimmed;
    _activity(
      actorId: currentUserId,
      groupId: group.id,
      eventType: 'group_renamed',
      entityType: 'group',
      entityId: group.id,
      title: 'Group renamed',
      body: '${nameOf(currentUserId)} renamed $previousName to ${group.name}.',
    );
    notifyListeners();
    return null;
  }

  List<GroupMember> activeAdminsForGroup(String groupId) {
    return membersForGroup(
      groupId,
      activeOnly: true,
    ).where((member) => member.role == MemberRole.admin).toList();
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
    if (!isGroupAdmin(groupId, currentUserId) && userId != currentUserId) {
      return;
    }
    if (memberForGroup(groupId, userId)?.role == MemberRole.admin &&
        activeAdminsForGroup(groupId).length <= 1) {
      return;
    }
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

  String? leaveGroup(String groupId) {
    final decision = groupLeaveDecision(groupId);
    if (!decision.canLeaveNow) {
      return decision.message;
    }
    removeGroupMember(groupId, currentUserId);
    if (selectedGroupId == groupId) {
      selectedGroupId = null;
    }
    notifyListeners();
    return null;
  }

  GroupLeaveDecision groupLeaveDecision(String groupId) {
    final group = groupByIdOrNull(groupId);
    if (group == null || group.isDisbanded) {
      return const GroupLeaveDecision(
        type: GroupLeaveDecisionType.unavailable,
        title: 'Group unavailable',
        message: 'Group is no longer available.',
      );
    }
    final member = memberForGroup(groupId, currentUserId);
    if (member == null || member.status != MemberStatus.active) {
      return const GroupLeaveDecision(
        type: GroupLeaveDecisionType.unavailable,
        title: 'Not an active member',
        message: 'You are not an active member of this group.',
      );
    }
    if (member.role == MemberRole.admin &&
        activeAdminsForGroup(groupId).length <= 1) {
      return GroupLeaveDecision(
        type: GroupLeaveDecisionType.needsNewAdmin,
        title: 'Choose a new admin first',
        message:
            'Assign another admin or disband ${group.name} before leaving.',
        primaryAction: 'Choose New Admin',
        secondaryAction: 'Disband Group',
      );
    }
    final balance = balanceForUserInGroup(groupId, currentUserId);
    if (balance < 0) {
      return GroupLeaveDecision(
        type: GroupLeaveDecisionType.owesMoney,
        title: 'Settle before leaving',
        message:
            'You still owe ${money(balance.abs())} in ${group.name}. Please settle your balance before leaving.',
        amountMinor: balance.abs(),
        primaryAction: 'Pay ${money(balance.abs())} & Leave',
        secondaryAction: 'View Balance Details',
      );
    }
    if (balance > 0) {
      return GroupLeaveDecision(
        type: GroupLeaveDecisionType.receivableActive,
        title: 'You are still owed ${money(balance)}',
        message:
            'You can leave ${group.name} now. Your pending receivables remain visible, and members can still pay you.',
        amountMinor: balance,
        primaryAction: 'Leave & Keep Receivables Active',
        secondaryAction: 'Send Reminder First',
      );
    }
    return GroupLeaveDecision(
      type: GroupLeaveDecisionType.zeroBalance,
      title: 'Leave ${group.name}?',
      message:
          'You have no pending balance. Past records will remain visible to group members.',
      primaryAction: 'Leave Group',
    );
  }

  String? disbandGroup(String groupId) {
    final group = groupByIdOrNull(groupId);
    if (group == null) {
      return 'Group is no longer available.';
    }
    if (group.isDisbanded) {
      return 'Group is already disbanded.';
    }
    if (!isGroupAdmin(groupId, currentUserId)) {
      return 'Only group admins can disband this group.';
    }
    group
      ..disbandedAt = _now
      ..disbandedBy = currentUserId;
    for (final member in groupMembers.where(
      (member) =>
          member.groupId == groupId && member.status == MemberStatus.active,
    )) {
      member
        ..status = MemberStatus.removed
        ..removedAt = _now;
    }
    _activity(
      actorId: currentUserId,
      groupId: groupId,
      eventType: 'group_disbanded',
      entityType: 'group',
      entityId: groupId,
      title: 'Group disbanded',
      body: '${group.name} was disbanded by ${nameOf(currentUserId)}.',
    );
    if (selectedGroupId == groupId) {
      selectedGroupId = null;
    }
    notifyListeners();
    return null;
  }

  void updateMemberRole(String groupId, String userId, MemberRole role) {
    if (!isGroupAdmin(groupId, currentUserId)) {
      return;
    }
    final member = memberForGroup(groupId, userId);
    if (member == null) {
      return;
    }
    if (member.role == MemberRole.admin &&
        role != MemberRole.admin &&
        activeAdminsForGroup(groupId).length <= 1) {
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
    Map<int, ItemSplitInput>? itemSplitInputs,
    bool equalBillAdjustmentAllocation = false,
    int taxMinor = 0,
    int serviceChargeMinor = 0,
    int discountMinor = 0,
    int tipMinor = 0,
    int roundingAdjustmentMinor = 0,
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
            ? equalShares(
                finalTotal,
                participants,
                payerId: payerId,
                payerAmounts: paidBy,
              )
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
      case SplitMode.item:
        final parsed = receiptItems ?? parseControlledReceipt('');
        var itemIndex = 0;
        for (final parsedItem in parsed) {
          final itemId = _id('item');
          final itemSplitInput = itemSplitInputs?[itemIndex];
          final assignedUsers =
              itemSplitInput?.userIds ??
              itemAssignments?[itemIndex] ??
              participants;
          final safeUsers = assignedUsers.isEmpty
              ? participants
              : assignedUsers;
          final units = itemSplitInput?.shareUnits;
          final itemSplits = units == null
              ? equalShares(
                  parsedItem.amountMinor,
                  safeUsers,
                  payerId: payerId,
                  payerAmounts: paidBy,
                )
              : unitShares(
                  parsedItem.amountMinor,
                  safeUsers.map((id) => units[id] ?? 1).toList(),
                );
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
                splitUnits: units?[safeUsers[i]] ?? 1,
              ),
            );
          }
          items.add(
            ExpenseItem(
              id: itemId,
              expenseId: expenseId,
              label: parsedItem.label,
              quantity: parsedItem.quantity,
              unitAmountMinor: parsedItem.unitAmountMinor,
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
          final adjustmentsForDelta = equalBillAdjustmentAllocation
              ? equalShares(delta.abs(), participants)
              : distributeByWeights(
                  delta.abs(),
                  participants
                      .map((id) => maxInt(shareAmounts[id]?.abs() ?? 0, 1))
                      .toList(),
                );
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
        billRoundingAdjustmentMinor: roundingAdjustmentMinor,
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
    for (final group in visibleExpenseGroups) {
      final balance = balanceForUserInGroup(group.id, currentUserId);
      if (balance < 0) {
        total += balance.abs();
      }
    }
    return total;
  }

  int get totalOwedToCurrentUser {
    var total = 0;
    for (final group in visibleExpenseGroups) {
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
    for (final group in visibleExpenseGroups) {
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

  int settleCurrentUserInGroup(String groupId) {
    var count = 0;
    for (final suggestion in suggestionsForGroup(groupId)) {
      if (suggestion.payerId == currentUserId) {
        final settlement = createOrReuseSettlement(suggestion);
        confirmSettlement(settlement.id);
        count += 1;
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

  String contributeToGiftPool(String giftPoolId, int amountMinor) {
    final pool = giftPools.firstWhere((item) => item.id == giftPoolId);
    final remaining = pool.targetAmountMinor - giftPoolTotal(giftPoolId);
    if (amountMinor <= 0) {
      return 'Enter a contribution amount greater than zero.';
    }
    // A pool can never collect more than its target.
    if (remaining <= 0) {
      return 'This gift pool has already reached its target.';
    }
    if (amountMinor > remaining) {
      return 'Contribution cannot exceed the ${money(remaining)} remaining.';
    }
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
    return 'Added ${money(amountMinor)} to ${pool.title}.';
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

  /// All contributions to a pool, newest first, for the contribution history.
  List<GiftPoolContribution> contributionsForGiftPool(String giftPoolId) {
    return giftPoolContributions
        .where((item) => item.giftPoolId == giftPoolId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  String createSavingsCirclePool({
    required String groupId,
    required String name,
    required int contributionAmountMinor,
    required String frequency,
    required DateTime startDate,
    required List<String> memberIds,
  }) {
    final pool = SavingsCirclePool(
      id: _id('savings-circle'),
      groupId: groupId,
      name: name,
      contributionAmountMinor: contributionAmountMinor,
      frequency: frequency,
      startDate: startDate,
      createdBy: currentUserId,
      status: SavingsCirclePoolStatus.active,
      createdAt: _now,
    );
    savingsCirclePools.add(pool);
    final members = <String>{currentUserId, ...memberIds};
    var order = 1;
    for (final memberId in members) {
      savingsCircleMembers.add(
        SavingsCircleMember(
          id: _id('savings-circle-member'),
          poolId: pool.id,
          userId: memberId,
          payoutOrder: order,
          status: memberId == currentUserId
              ? SavingsCircleMemberStatus.active
              : SavingsCircleMemberStatus.invited,
        ),
      );
      order += 1;
    }
    _generateSavingsCircleSchedule(pool.id);
    selectedSavingsCirclePoolId = pool.id;
    _activity(
      actorId: currentUserId,
      groupId: groupId,
      eventType: 'savings_circle_created',
      entityType: 'savings_circle_pool',
      entityId: pool.id,
      title: 'Savings Circle created',
      body: '$name now has a transparent schedule and ledger.',
    );
    notifyListeners();
    return pool.id;
  }

  List<SavingsCircleMember> membersForPool(String poolId) {
    return savingsCircleMembers
        .where((member) => member.poolId == poolId)
        .toList()
      ..sort((a, b) => a.payoutOrder.compareTo(b.payoutOrder));
  }

  bool canManageSavingsCirclePool(String poolId, String userId) {
    final pool = poolByIdOrNull(poolId);
    if (pool == null) {
      return false;
    }
    return pool.createdBy == userId || isGroupAdmin(pool.groupId, userId);
  }

  String? renameSavingsCirclePool(String poolId, String name) {
    final pool = poolByIdOrNull(poolId);
    if (pool == null) {
      return 'Savings Circle group is no longer available.';
    }
    if (!canManageSavingsCirclePool(poolId, currentUserId)) {
      return 'Only the Savings Circle admin can rename this group.';
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'Savings Circle group name cannot be empty.';
    }
    if (trimmed == pool.name) {
      return null;
    }
    final previousName = pool.name;
    pool.name = trimmed;
    _activity(
      actorId: currentUserId,
      groupId: pool.groupId,
      eventType: 'savings_circle_renamed',
      entityType: 'savings_circle_pool',
      entityId: pool.id,
      title: 'Savings Circle group renamed',
      body: '${nameOf(currentUserId)} renamed $previousName to ${pool.name}.',
    );
    notifyListeners();
    return null;
  }

  void acceptSavingsCircle(String poolId) {
    final member = savingsCircleMembers.firstWhere(
      (item) => item.poolId == poolId && item.userId == currentUserId,
    );
    member.status = SavingsCircleMemberStatus.active;
    _activity(
      actorId: currentUserId,
      groupId: poolById(poolId).groupId,
      eventType: 'savings_circle_accepted',
      entityType: 'savings_circle_member',
      entityId: member.id,
      title: 'Savings Circle participation accepted',
      body: '${nameOf(currentUserId)} accepted the Savings Circle invite.',
    );
    notifyListeners();
  }

  void declineSavingsCircle(String poolId) {
    final member = savingsCircleMembers.firstWhere(
      (item) => item.poolId == poolId && item.userId == currentUserId,
    );
    member.status = SavingsCircleMemberStatus.declined;
    _activity(
      actorId: currentUserId,
      groupId: poolById(poolId).groupId,
      eventType: 'savings_circle_declined',
      entityType: 'savings_circle_member',
      entityId: member.id,
      title: 'Savings Circle invite declined',
      body: '${nameOf(currentUserId)} declined the Savings Circle invite.',
    );
    notifyListeners();
  }

  void paySavingsCircleContribution(String contributionId) {
    final contribution = savingsCircleContributions.firstWhere(
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
      entityType: 'savings_circle_contribution',
      operationType: contribution.operationType,
      amountMinor: contribution.amountMinor,
      status: PaymentStatus.paid,
    );
    contribution
      ..status = ContributionStatus.paid
      ..paymentTransactionId = payment.id
      ..paidAt = _now;
    _refreshSavingsCircleCycles(contribution.poolId);
    _activity(
      actorId: currentUserId,
      groupId: poolById(contribution.poolId).groupId,
      eventType: 'savings_circle_contribution_paid',
      entityType: 'savings_circle_contribution',
      entityId: contribution.id,
      title: 'Savings Circle contribution paid',
      body:
          '${nameOf(currentUserId)} paid ${money(contribution.amountMinor)} for cycle ${contribution.cycleNumber}.',
    );
    notifyListeners();
  }

  int payRemainingSavingsCircleExitContributions(String poolId) {
    final contributions = remainingSavingsCircleExitContributions(poolId);
    var total = 0;
    for (final contribution in contributions) {
      final existing = payments.any(
        (payment) =>
            payment.actorId == currentUserId &&
            payment.operationType == contribution.operationType &&
            payment.entityId == contribution.id &&
            payment.status == PaymentStatus.paid,
      );
      if (existing) {
        continue;
      }
      final payment = _payment(
        actorId: currentUserId,
        entityId: contribution.id,
        entityType: 'savings_circle_contribution',
        operationType: contribution.operationType,
        amountMinor: contribution.amountMinor,
        status: PaymentStatus.paid,
      );
      contribution
        ..status = ContributionStatus.paid
        ..paymentTransactionId = payment.id
        ..paidAt = _now;
      total += contribution.amountMinor;
      _activity(
        actorId: currentUserId,
        groupId: poolById(contribution.poolId).groupId,
        eventType: 'savings_circle_exit_contribution_paid',
        entityType: 'savings_circle_contribution',
        entityId: contribution.id,
        title: 'Savings Circle exit contribution paid',
        body:
            '${nameOf(currentUserId)} prepaid ${money(contribution.amountMinor)} for cycle ${contribution.cycleNumber} before exit review.',
      );
    }
    _refreshSavingsCircleCycles(poolId);
    notifyListeners();
    return total;
  }

  String confirmSavingsCirclePayoutReview(String cycleId) {
    final cycle = savingsCircleCycles.firstWhere((item) => item.id == cycleId);
    final payout = savingsCirclePayouts.firstWhere(
      (item) => item.cycleId == cycleId,
    );
    if (cycle.status == SavingsCircleCycleStatus.readyForPayout) {
      payout
        ..status = PayoutStatus.paid
        ..paidAt = _now;
      cycle.status = SavingsCircleCycleStatus.paidOut;
      _activity(
        actorId: currentUserId,
        groupId: poolById(cycle.poolId).groupId,
        eventType: 'savings_circle_payout_completed',
        entityType: 'savings_circle_payout',
        entityId: payout.id,
        title: 'Savings Circle payout recorded',
        body:
            'Cycle ${cycle.cycleNumber} payout was recorded in the transparent ledger.',
      );
    } else {
      _activity(
        actorId: currentUserId,
        groupId: poolById(cycle.poolId).groupId,
        eventType: 'savings_circle_payout_reviewed',
        entityType: 'savings_circle_payout',
        entityId: payout.id,
        title: 'Savings Circle payout reviewed',
        body:
            'Cycle ${cycle.cycleNumber} payout was reviewed without changing ledger balances.',
      );
    }
    notifyListeners();
    return payout.id;
  }

  void requestEmergencyExit(String poolId, String reason) {
    final decision = savingsCircleExitDecision(poolId);
    if (decision.type == SavingsCircleExitDecisionType.unavailable) {
      _notify(
        currentUserId,
        'savings_circle_exit',
        decision.title,
        decision.message,
      );
      notifyListeners();
      return;
    }
    if (decision.canLeaveNow) {
      leaveSavingsCircleBeforeStart(poolId);
      return;
    }
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
      eventType: 'savings_circle_exit_requested',
      entityType: 'savings_circle_exit',
      entityId: poolId,
      title: 'Emergency exit requested',
      body: '${nameOf(currentUserId)} requested organizer review.',
    );
    notifyListeners();
  }

  String? leaveSavingsCircleBeforeStart(String poolId) {
    final decision = savingsCircleExitDecision(poolId);
    if (!decision.canLeaveNow) {
      return decision.message;
    }
    final member = savingsCircleMembers.firstWhere(
      (item) => item.poolId == poolId && item.userId == currentUserId,
    );
    member.status = SavingsCircleMemberStatus.exited;
    _activity(
      actorId: currentUserId,
      groupId: poolById(poolId).groupId,
      eventType: 'savings_circle_left_before_start',
      entityType: 'savings_circle_member',
      entityId: member.id,
      title: 'Savings Circle member left',
      body:
          '${nameOf(currentUserId)} left before the Savings Circle started. The schedule needs member review.',
    );
    _regenerateSavingsCircleSchedule(poolId);
    notifyListeners();
    return null;
  }

  SavingsCircleExitDecision savingsCircleExitDecision(String poolId) {
    final pool = savingsCirclePools
        .where((item) => item.id == poolId)
        .cast<SavingsCirclePool?>()
        .firstOrNull;
    if (pool == null || pool.status == SavingsCirclePoolStatus.cancelled) {
      return const SavingsCircleExitDecision(
        type: SavingsCircleExitDecisionType.unavailable,
        title: 'Savings Circle unavailable',
        message: 'This Savings Circle pool is no longer available.',
      );
    }
    final member = savingsCircleMembers
        .where((item) => item.poolId == poolId && item.userId == currentUserId)
        .cast<SavingsCircleMember?>()
        .firstOrNull;
    if (member == null || member.status == SavingsCircleMemberStatus.exited) {
      return const SavingsCircleExitDecision(
        type: SavingsCircleExitDecisionType.unavailable,
        title: 'No active participation',
        message: 'You are not an active participant in this Savings Circle.',
      );
    }
    final members = membersForPool(poolId);
    final contributions =
        savingsCircleContributions
            .where(
              (item) => item.poolId == poolId && item.userId == currentUserId,
            )
            .toList()
          ..sort((a, b) => a.cycleNumber.compareTo(b.cycleNumber));
    final payouts = savingsCirclePayouts
        .where(
          (item) => item.poolId == poolId && item.recipientId == currentUserId,
        )
        .toList();
    final hasPaidAnyContribution = contributions.any(
      (item) => item.status == ContributionStatus.paid,
    );
    final hasReceivedPayout = payouts.any(
      (item) => item.status == PayoutStatus.paid,
    );
    final hasPendingInvite = members.any(
      (item) => item.status == SavingsCircleMemberStatus.invited,
    );
    if (pool.status == SavingsCirclePoolStatus.draft ||
        (hasPendingInvite && !hasPaidAnyContribution && !hasReceivedPayout)) {
      return SavingsCircleExitDecision(
        type: SavingsCircleExitDecisionType.canLeaveBeforeStart,
        title: 'Leave before Savings Circle starts?',
        message:
            'You can leave before all members accept. Contribution amount and payout schedule will be recalculated.',
        primaryAction: 'Leave Savings Circle',
      );
    }
    final remainingExitContributions = remainingSavingsCircleExitContributions(
      poolId,
      userId: currentUserId,
    );
    final remainingExitTotal = remainingExitContributions.fold<int>(
      0,
      (sum, item) => sum + item.amountMinor,
    );
    if (remainingExitTotal > 0) {
      final currentCycle = currentSavingsCircleCycleNumber(poolId);
      final cycleText = remainingExitContributions.length == 1
          ? 'Cycle ${remainingExitContributions.first.cycleNumber}'
          : 'Cycles $currentCycle-${remainingExitContributions.last.cycleNumber}';
      return SavingsCircleExitDecision(
        type: SavingsCircleExitDecisionType.pendingContribution,
        title: 'Remaining contributions required',
        message:
            'You are in Cycle $currentCycle. To leave this Savings Circle, you must first pay ${money(remainingExitTotal)} for your remaining contribution obligations ($cycleText).',
        amountMinor: remainingExitTotal,
        primaryAction: 'Pay Remaining Contributions',
        secondaryAction: 'View Agreement',
      );
    }
    if (hasReceivedPayout) {
      return SavingsCircleExitDecision(
        type: SavingsCircleExitDecisionType.receivedPayout,
        title: 'Payout already received',
        message:
            'You already received the community pot. Your remaining cycle contributions are paid, so the exit still needs admin and member approval.',
        amountMinor: 0,
        primaryAction: 'Request Exit Approval',
        secondaryAction: 'Request Exit Approval',
      );
    }
    final paid = contributions
        .where((item) => item.status == ContributionStatus.paid)
        .fold<int>(0, (sum, item) => sum + item.amountMinor);
    return SavingsCircleExitDecision(
      type: SavingsCircleExitDecisionType.requiresApproval,
      title: 'Contributions already paid',
      message:
          'You can request exit, but members must approve the updated payout order, pot amount, service fee, and refund treatment.',
      amountMinor: paid,
      primaryAction: 'Request Exit',
      secondaryAction: 'View Agreement',
    );
  }

  int currentSavingsCircleCycleNumber(String poolId) {
    final active =
        savingsCircleCycles
            .where(
              (item) =>
                  item.poolId == poolId &&
                  (item.status == SavingsCircleCycleStatus.open ||
                      item.status == SavingsCircleCycleStatus.atRisk ||
                      item.status == SavingsCircleCycleStatus.readyForPayout),
            )
            .toList()
          ..sort((a, b) => a.cycleNumber.compareTo(b.cycleNumber));
    if (active.isNotEmpty) {
      return active.first.cycleNumber;
    }
    final upcoming =
        savingsCircleCycles
            .where(
              (item) =>
                  item.poolId == poolId &&
                  item.status == SavingsCircleCycleStatus.upcoming,
            )
            .toList()
          ..sort((a, b) => a.cycleNumber.compareTo(b.cycleNumber));
    if (upcoming.isNotEmpty) {
      return upcoming.first.cycleNumber;
    }
    final cycles = savingsCircleCycles
        .where((item) => item.poolId == poolId)
        .map((item) => item.cycleNumber)
        .toList();
    if (cycles.isEmpty) {
      return 1;
    }
    cycles.sort();
    return cycles.last;
  }

  List<SavingsCircleContribution> remainingSavingsCircleExitContributions(
    String poolId, {
    String? userId,
  }) {
    final actorId = userId ?? currentUserId;
    final currentCycle = currentSavingsCircleCycleNumber(poolId);
    return savingsCircleContributions
        .where(
          (item) =>
              item.poolId == poolId &&
              item.userId == actorId &&
              item.cycleNumber >= currentCycle &&
              item.status != ContributionStatus.paid &&
              item.status != ContributionStatus.cancelled,
        )
        .toList()
      ..sort((a, b) => a.cycleNumber.compareTo(b.cycleNumber));
  }

  void approveEmergencyExit(String requestId) {
    final request = emergencyExitRequests.firstWhere(
      (item) => item.id == requestId,
    );
    request.status = 'approved';
    final member = savingsCircleMembers.firstWhere(
      (item) => item.poolId == request.poolId && item.userId == request.userId,
    );
    member.status = SavingsCircleMemberStatus.exited;
    notifyListeners();
  }

  List<SavingsCircleContribution> contributionsForPool(String poolId) {
    return savingsCircleContributions
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
      'savingsCircleContributions': savingsCircleContributions
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

  void _generateSavingsCircleSchedule(String poolId) {
    final pool = poolById(poolId);
    final activeMembers = membersForPool(poolId)
        .where(
          (member) =>
              member.status == SavingsCircleMemberStatus.active ||
              member.status == SavingsCircleMemberStatus.invited,
        )
        .toList();
    final memberIds = activeMembers.map((member) => member.userId).toList();
    for (var i = 0; i < memberIds.length; i++) {
      final cycleId = _id('savings-circle-cycle');
      final dueDate = DateTime(
        pool.startDate.year,
        pool.startDate.month + i,
        15,
      );
      savingsCircleCycles.add(
        SavingsCircleCycle(
          id: cycleId,
          poolId: poolId,
          cycleNumber: i + 1,
          dueDate: dueDate,
          payoutRecipientId: memberIds[i],
          expectedContributionTotalMinor:
              pool.contributionAmountMinor * memberIds.length,
          paidContributionTotalMinor: 0,
          status: i == 0
              ? SavingsCircleCycleStatus.open
              : SavingsCircleCycleStatus.upcoming,
        ),
      );
      for (final memberId in memberIds) {
        savingsCircleContributions.add(
          SavingsCircleContribution(
            id: _id('savings-circle-contribution'),
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
            operationType: 'savings_circle_contribution',
          ),
        );
      }
      savingsCirclePayouts.add(
        SavingsCirclePayout(
          id: _id('savings-circle-payout'),
          poolId: poolId,
          cycleId: cycleId,
          recipientId: memberIds[i],
          amountMinor: pool.contributionAmountMinor * memberIds.length,
          status: PayoutStatus.pending,
          idempotencyKey: '$poolId-payout-${i + 1}',
          idempotencyScope: poolId,
          operationType: 'savings_circle_payout',
        ),
      );
    }
  }

  void _regenerateSavingsCircleSchedule(String poolId) {
    savingsCircleCycles.removeWhere((item) => item.poolId == poolId);
    savingsCircleContributions.removeWhere((item) => item.poolId == poolId);
    savingsCirclePayouts.removeWhere((item) => item.poolId == poolId);
    _generateSavingsCircleSchedule(poolId);
  }

  void _refreshSavingsCircleCycles(String poolId) {
    for (final cycle in savingsCircleCycles.where(
      (cycle) => cycle.poolId == poolId,
    )) {
      if (cycle.status == SavingsCircleCycleStatus.paidOut ||
          cycle.status == SavingsCircleCycleStatus.closed ||
          cycle.status == SavingsCircleCycleStatus.cancelled) {
        continue;
      }
      final contributions = savingsCircleContributions.where(
        (item) => item.cycleId == cycle.id,
      );
      final paid = contributions
          .where((item) => item.status == ContributionStatus.paid)
          .fold<int>(0, (sum, item) => sum + item.amountMinor);
      cycle.paidContributionTotalMinor = paid;
      if (paid == cycle.expectedContributionTotalMinor) {
        cycle.status = SavingsCircleCycleStatus.readyForPayout;
      } else if (contributions.any(
        (item) =>
            item.status == ContributionStatus.late ||
            item.status == ContributionStatus.missed,
      )) {
        cycle.status = SavingsCircleCycleStatus.atRisk;
      } else if (!cycle.dueDate.isAfter(_now)) {
        cycle.status = SavingsCircleCycleStatus.open;
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
    final family = Group(
      id: 'g-shrestha-family',
      name: 'Shrestha Family',
      category: GroupCategory.festival,
      template: 'Family Savings Circle',
      kind: GroupKind.savingsCircle,
      createdBy: 'u-sita',
      createdAt: DateTime(2026, 5, 14),
    );
    final college = Group(
      id: 'g-college-friends',
      name: 'College Friends',
      category: GroupCategory.custom,
      template: 'Friends Circle',
      createdBy: 'u-maya',
      createdAt: DateTime(2026, 5, 15),
    );
    final office = Group(
      id: 'g-office-circle',
      name: 'Office Savings Circle',
      category: GroupCategory.custom,
      template: 'Work Circle',
      createdBy: 'u-arjun',
      createdAt: DateTime(2026, 5, 16),
    );
    groups.addAll(<Group>[dashain, trek, apartment, family, college, office]);
    selectedGroupId = null;

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
    for (final memberId in <String>[
      'u-sita',
      'u-arjun',
      'u-maya',
      'u-nabin',
      'u-laxmi',
      'u-rina',
    ]) {
      member(
        family.id,
        memberId,
        memberId == 'u-sita' ? MemberRole.admin : MemberRole.member,
      );
    }
    for (final memberId in <String>[
      'u-sita',
      'u-arjun',
      'u-maya',
      'u-nabin',
      'u-pasang',
    ]) {
      member(
        college.id,
        memberId,
        memberId == 'u-maya' ? MemberRole.admin : MemberRole.member,
      );
    }
    for (final memberId in <String>[
      'u-sita',
      'u-arjun',
      'u-maya',
      'u-nabin',
      'u-laxmi',
      'u-rina',
      'u-pasang',
      'u-kabir',
    ]) {
      member(
        office.id,
        memberId,
        memberId == 'u-arjun' ? MemberRole.admin : MemberRole.member,
      );
    }

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
      splitMode: SplitMode.custom,
      participantIds: <String>['u-sita', 'u-maya', 'u-pasang', 'u-arjun'],
      customAmounts: <String, int>{
        'u-sita': npr(2400),
        'u-maya': npr(2400),
        'u-pasang': npr(4800),
        'u-arjun': npr(2400),
      },
    );
    addExpense(
      groupId: apartment.id,
      title: 'May utilities',
      totalMinor: npr(5400),
      payerId: 'u-laxmi',
      category: 'household',
      splitMode: SplitMode.custom,
      participantIds: <String>['u-sita', 'u-arjun', 'u-laxmi'],
      customAmounts: <String, int>{
        'u-sita': npr(1620),
        'u-arjun': npr(1890),
        'u-laxmi': npr(1890),
      },
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

    SavingsCirclePool seedSavingsCirclePool({
      required String id,
      required Group group,
      required String name,
      required int amountMinor,
      required DateTime startDate,
      required String createdBy,
      required List<String> memberIds,
    }) {
      final pool = SavingsCirclePool(
        id: id,
        groupId: group.id,
        name: name,
        contributionAmountMinor: amountMinor,
        frequency: 'monthly',
        startDate: startDate,
        createdBy: createdBy,
        status: SavingsCirclePoolStatus.active,
        createdAt: startDate,
      );
      savingsCirclePools.add(pool);
      for (var i = 0; i < memberIds.length; i++) {
        savingsCircleMembers.add(
          SavingsCircleMember(
            id: _id('savings-circle-member'),
            poolId: pool.id,
            userId: memberIds[i],
            payoutOrder: i + 1,
            status: SavingsCircleMemberStatus.active,
          ),
        );
      }
      _generateSavingsCircleSchedule(pool.id);
      return pool;
    }

    void markContributionPaid(
      SavingsCircleContribution contribution,
      DateTime paidAt,
    ) {
      final payment = _payment(
        actorId: contribution.userId,
        entityId: contribution.id,
        entityType: 'savings_circle_contribution',
        operationType: 'savings_circle_contribution',
        amountMinor: contribution.amountMinor,
        status: PaymentStatus.paid,
      );
      contribution
        ..status = ContributionStatus.paid
        ..paidAt = paidAt
        ..paymentTransactionId = payment.id;
    }

    void setCycleState(
      String poolId,
      int cycleNumber,
      SavingsCircleCycleStatus status, {
      List<String> paidMembers = const <String>[],
      List<String> lateMembers = const <String>[],
      List<String> missedMembers = const <String>[],
    }) {
      final cycle = savingsCircleCycles.firstWhere(
        (item) => item.poolId == poolId && item.cycleNumber == cycleNumber,
      );
      cycle.status = status;
      final contributions = savingsCircleContributions.where(
        (item) => item.cycleId == cycle.id,
      );
      for (final contribution in contributions) {
        if (paidMembers.contains(contribution.userId)) {
          markContributionPaid(contribution, cycle.dueDate);
        } else if (lateMembers.contains(contribution.userId)) {
          contribution.status = ContributionStatus.late;
        } else if (missedMembers.contains(contribution.userId)) {
          contribution.status = ContributionStatus.missed;
        } else {
          contribution.status = status == SavingsCircleCycleStatus.upcoming
              ? ContributionStatus.pending
              : ContributionStatus.due;
        }
      }
      cycle.paidContributionTotalMinor = contributions
          .where((item) => item.status == ContributionStatus.paid)
          .fold<int>(0, (sum, item) => sum + item.amountMinor);
      if (status == SavingsCircleCycleStatus.paidOut ||
          status == SavingsCircleCycleStatus.closed) {
        final payout = savingsCirclePayouts.firstWhere(
          (item) => item.cycleId == cycle.id,
        );
        payout
          ..status = PayoutStatus.paid
          ..paidAt = cycle.dueDate.add(const Duration(days: 1));
      }
    }

    void addSavingsCircleLedger({
      required SavingsCirclePool pool,
      required String eventType,
      required String entityType,
      required String entityId,
      required String title,
      required String body,
      String? actorId,
    }) {
      _activity(
        actorId: actorId,
        actorType: actorId == null ? 'system' : 'user',
        groupId: pool.groupId,
        eventType: eventType,
        entityType: entityType,
        entityId: entityId,
        title: title,
        body: body,
      );
    }

    final familySavingsCircle = seedSavingsCirclePool(
      id: 'd-family-dashain',
      group: family,
      name: 'Family Dashain Savings Circle',
      amountMinor: npr(5000),
      startDate: DateTime(2026, 3, 15),
      createdBy: 'u-sita',
      memberIds: <String>[
        'u-arjun',
        'u-maya',
        'u-sita',
        'u-nabin',
        'u-laxmi',
        'u-rina',
      ],
    );
    familySavingsCircle.createdAt = DateTime(2026, 5, 28);
    selectedSavingsCirclePoolId = familySavingsCircle.id;
    setCycleState(
      familySavingsCircle.id,
      1,
      SavingsCircleCycleStatus.paidOut,
      paidMembers: <String>[
        'u-arjun',
        'u-maya',
        'u-sita',
        'u-nabin',
        'u-laxmi',
        'u-rina',
      ],
    );
    setCycleState(
      familySavingsCircle.id,
      2,
      SavingsCircleCycleStatus.paidOut,
      paidMembers: <String>[
        'u-arjun',
        'u-maya',
        'u-sita',
        'u-nabin',
        'u-laxmi',
        'u-rina',
      ],
    );
    setCycleState(
      familySavingsCircle.id,
      3,
      SavingsCircleCycleStatus.open,
      paidMembers: <String>['u-arjun', 'u-maya', 'u-nabin', 'u-rina'],
    );
    addSavingsCircleLedger(
      pool: familySavingsCircle,
      actorId: 'u-arjun',
      eventType: 'savings_circle_contribution_paid',
      entityType: 'savings_circle_contribution',
      entityId: savingsCircleContributions
          .firstWhere(
            (item) =>
                item.poolId == familySavingsCircle.id &&
                item.cycleNumber == 3 &&
                item.userId == 'u-arjun',
          )
          .id,
      title: 'Arjun paid contribution',
      body: 'Cycle 3 contribution recorded through mock eSewa confirmation.',
    );
    addSavingsCircleLedger(
      pool: familySavingsCircle,
      eventType: 'savings_circle_cycle_opened',
      entityType: 'savings_circle_pool',
      entityId: familySavingsCircle.id,
      title: 'Cycle 3 opened',
      body: 'Monthly contribution schedule is open for the current cycle.',
    );
    addSavingsCircleLedger(
      pool: familySavingsCircle,
      actorId: 'u-sita',
      eventType: 'savings_circle_recipient_current',
      entityType: 'savings_circle_pool',
      entityId: familySavingsCircle.id,
      title: 'Sita is current payout recipient',
      body: 'Payout turn follows the visible rotation order.',
    );
    addSavingsCircleLedger(
      pool: familySavingsCircle,
      actorId: 'u-maya',
      eventType: 'savings_circle_member_accepted',
      entityType: 'savings_circle_member',
      entityId: familySavingsCircle.id,
      title: 'Member accepted Savings Circle invitation',
      body: 'Maya joined the transparent contribution schedule.',
    );

    final collegeSavingsCircle = seedSavingsCirclePool(
      id: 'd-college-friends',
      group: college,
      name: 'College Friends Savings Circle',
      amountMinor: npr(2000),
      startDate: DateTime(2026, 4, 15),
      createdBy: 'u-maya',
      memberIds: <String>['u-sita', 'u-maya', 'u-arjun', 'u-nabin', 'u-pasang'],
    );
    collegeSavingsCircle.createdAt = DateTime(2026, 5, 27);
    setCycleState(
      collegeSavingsCircle.id,
      1,
      SavingsCircleCycleStatus.paidOut,
      paidMembers: <String>[
        'u-sita',
        'u-maya',
        'u-arjun',
        'u-nabin',
        'u-pasang',
      ],
    );
    setCycleState(
      collegeSavingsCircle.id,
      2,
      SavingsCircleCycleStatus.atRisk,
      paidMembers: <String>['u-sita', 'u-maya'],
      lateMembers: <String>['u-arjun'],
      missedMembers: <String>['u-pasang'],
    );
    addSavingsCircleLedger(
      pool: collegeSavingsCircle,
      actorId: 'u-arjun',
      eventType: 'savings_circle_contribution_late',
      entityType: 'savings_circle_contribution',
      entityId: collegeSavingsCircle.id,
      title: 'Arjun contribution marked late',
      body: 'Cycle 2 remains visible as at risk until pending statuses clear.',
    );

    final officeSavingsCircle = seedSavingsCirclePool(
      id: 'd-office-circle',
      group: office,
      name: 'Office Savings Circle',
      amountMinor: npr(3000),
      startDate: DateTime(2026, 6, 15),
      createdBy: 'u-arjun',
      memberIds: <String>[
        'u-sita',
        'u-arjun',
        'u-maya',
        'u-nabin',
        'u-laxmi',
        'u-rina',
        'u-pasang',
        'u-kabir',
      ],
    );
    officeSavingsCircle.createdAt = DateTime(2026, 5, 26);
    setCycleState(officeSavingsCircle.id, 1, SavingsCircleCycleStatus.upcoming);
    addSavingsCircleLedger(
      pool: officeSavingsCircle,
      eventType: 'savings_circle_created',
      entityType: 'savings_circle_pool',
      entityId: officeSavingsCircle.id,
      title: 'Office Savings Circle scheduled',
      body: 'First contribution cycle is upcoming.',
    );

    addSavingsCircleLedger(
      pool: familySavingsCircle,
      eventType: 'savings_circle_payout_completed',
      entityType: 'savings_circle_payout',
      entityId: savingsCirclePayouts
          .firstWhere((item) => item.poolId == familySavingsCircle.id)
          .id,
      title: 'Cycle 2 payout completed',
      body: 'The previous cycle was settled in the mock ledger.',
    );
    _notify(
      'u-sita',
      'nudge',
      'Gentle settlement nudge',
      'Arjun and Maya still have open Dashain balances. Send a neutral reminder after 3 days.',
    );
    _notify(
      'u-sita',
      'savings_circle',
      'Savings Circle cycle at risk',
      'One contribution is late before this cycle can be ready for payout.',
    );
  }
}
