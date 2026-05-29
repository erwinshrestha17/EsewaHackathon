import 'package:flutter/material.dart';

import '../../src/app_state.dart';
import '../../src/finance.dart';
import '../../src/models.dart';
import 'home_models.dart';
import 'mock_home_data.dart';

class HomeController {
  const HomeController({required this.store});

  final AppStore store;

  HomeDashboardData loadDashboard() {
    try {
      return HomeDashboardData(
        userProfile: store.currentUser,
        balanceSummary: HomeBalanceSummary(
          totalYouOwe: store.totalOwedByCurrentUser,
          totalOwedToYou: store.totalOwedToCurrentUser,
          pendingAmount: _pendingAmount(),
        ),
        pendingSettlements: _pendingSettlements(),
        upcomingDhukutiDues: _dhukutiDues(),
        activeGroups: _activeGroups(),
        recentActivities: _recentActivities(),
        suggestedActions: mockHomeDashboardData().suggestedActions,
      );
    } catch (_) {
      return mockHomeDashboardData();
    }
  }

  int _pendingAmount() {
    return store.pendingSettlementsForCurrentUser.fold<int>(
      0,
      (sum, item) => sum + item.amountMinor,
    );
  }

  List<HomePendingSettlement> _pendingSettlements() {
    return [
      for (final settlement in store.pendingSettlementsForCurrentUser.take(3))
        HomePendingSettlement(
          id: settlement.id,
          payerName: store.nameOf(settlement.payerId),
          payeeName: store.nameOf(settlement.payeeId),
          counterpartyName: settlement.payerId == store.currentUserId
              ? store.nameOf(settlement.payeeId)
              : store.nameOf(settlement.payerId),
          counterpartyAvatar: settlement.payerId == store.currentUserId
              ? store.userById(settlement.payeeId).avatar
              : store.userById(settlement.payerId).avatar,
          groupName: store.groupById(settlement.groupId).name,
          amount: settlement.amountMinor,
          status: enumLabel(settlement.status),
        ),
    ];
  }

  List<HomeDhukutiDue> _dhukutiDues() {
    final dues = <HomeDhukutiDue>[];
    for (final pool in store.visibleDhukutiPools) {
      final cycles =
          store.dhukutiCycles.where((cycle) => cycle.poolId == pool.id).toList()
            ..sort((a, b) => a.cycleNumber.compareTo(b.cycleNumber));
      for (final contribution in store.contributionsForPool(pool.id)) {
        if (contribution.userId != store.currentUserId) {
          continue;
        }
        final cycle = cycles.where((item) => item.id == contribution.cycleId);
        if (cycle.isEmpty) {
          continue;
        }
        final status = contribution.status == ContributionStatus.paid
            ? 'Paid'
            : cycle.first.status == DhukutiCycleStatus.atRisk
            ? 'At Risk'
            : 'Due Soon';
        dues.add(
          HomeDhukutiDue(
            contributionId: contribution.id,
            poolId: pool.id,
            poolName: pool.name,
            amount: contribution.amountMinor,
            dueLabel: _dueLabel(contribution.dueDate),
            cycleLabel: 'Cycle ${contribution.cycleNumber} of ${cycles.length}',
            payoutRecipientName: store.nameOf(cycle.first.payoutRecipientId),
            status: status,
            isPayable:
                contribution.status != ContributionStatus.paid &&
                contribution.status != ContributionStatus.pending &&
                pool.status == DhukutiPoolStatus.active &&
                cycle.first.status != DhukutiCycleStatus.cancelled &&
                cycle.first.status != DhukutiCycleStatus.closed &&
                cycle.first.status != DhukutiCycleStatus.paidOut,
          ),
        );
        if (dues.length >= 2) {
          return dues;
        }
      }
    }
    return dues;
  }

  List<HomeGroupSummary> _activeGroups() {
    return [
      for (final group in store.visibleGroups.take(5))
        HomeGroupSummary(
          id: group.id,
          name: group.name,
          category: enumLabel(group.category),
          icon: _iconForCategory(group.category),
          memberCount: store.membersForGroup(group.id, activeOnly: true).length,
          userBalance: store.balanceForUserInGroup(
            group.id,
            store.currentUserId,
          ),
          dueStatus: _balanceStatus(
            store.balanceForUserInGroup(group.id, store.currentUserId),
          ),
          recentText: _groupRecentText(group.id),
        ),
    ];
  }

  List<HomeActivityItem> _recentActivities() {
    return [
      for (final item in store.visibleActivity.take(5))
        HomeActivityItem(
          id: item.id,
          title: item.title,
          subtitle: _activitySubtitle(item),
          timestamp: _relativeTime(item.createdAt),
          icon: _activityIcon(item),
          amount: _activityAmount(item),
          status: _activityStatus(item),
        ),
    ];
  }

  String _groupRecentText(String groupId) {
    final items = store.activityForGroup(groupId);
    if (items.isEmpty) {
      return 'No recent activity';
    }
    return items.first.title;
  }

  String _activitySubtitle(ActivityLog item) {
    final group = store.groupByIdOrNull(item.groupId);
    if (group != null) {
      final amount = _activityAmount(item);
      return amount == null ? group.name : '${group.name} · ${money(amount)}';
    }
    return item.body;
  }

  int? _activityAmount(ActivityLog item) {
    if (item.entityType == 'expense') {
      for (final expense in store.expenses) {
        if (expense.id == item.entityId) {
          return expense.totalMinor;
        }
      }
    }
    if (item.entityType == 'settlement') {
      for (final settlement in store.settlements) {
        if (settlement.id == item.entityId) {
          return settlement.amountMinor;
        }
      }
    }
    if (item.entityType == 'gift_card') {
      for (final gift in store.gifts) {
        if (gift.id == item.entityId) {
          return gift.amountMinor;
        }
      }
    }
    if (item.entityType == 'dhukuti_contribution') {
      for (final contribution in store.dhukutiContributions) {
        if (contribution.id == item.entityId) {
          return contribution.amountMinor;
        }
      }
    }
    return null;
  }

  String? _activityStatus(ActivityLog item) {
    if (item.eventType.contains('paid')) {
      return 'Paid';
    }
    if (item.eventType.contains('pending')) {
      return 'Pending';
    }
    if (item.eventType.contains('sent')) {
      return 'Sent';
    }
    if (item.eventType.contains('failed')) {
      return 'Failed';
    }
    return null;
  }
}

String _balanceStatus(int amount) {
  if (amount > 0) {
    return 'To receive';
  }
  if (amount < 0) {
    return 'You owe';
  }
  return 'All settled';
}

String _dueLabel(DateTime dueDate) {
  final days = dueDate.difference(DateTime.now()).inDays;
  if (days < 0) {
    return '${days.abs()} day${days.abs() == 1 ? '' : 's'} late';
  }
  if (days == 0) {
    return 'Due today';
  }
  return '$days day${days == 1 ? '' : 's'} left';
}

String _relativeTime(DateTime createdAt) {
  final difference = DateTime.now().difference(createdAt);
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes.clamp(1, 59);
    return '${minutes}m ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  }
  if (difference.inDays == 1) {
    return 'Yesterday';
  }
  return '${difference.inDays} days ago';
}

IconData _iconForCategory(GroupCategory category) {
  return switch (category) {
    GroupCategory.festival => Icons.celebration_outlined,
    GroupCategory.trek || GroupCategory.travel => Icons.hiking_outlined,
    GroupCategory.bhoj => Icons.restaurant_outlined,
    GroupCategory.event => Icons.event_outlined,
    GroupCategory.household ||
    GroupCategory.apartment => Icons.home_work_outlined,
    GroupCategory.custom => Icons.groups_outlined,
  };
}

IconData _activityIcon(ActivityLog item) {
  if (item.entityType.contains('expense')) {
    return Icons.receipt_long_outlined;
  }
  if (item.entityType.contains('settlement')) {
    return Icons.payments_outlined;
  }
  if (item.entityType.contains('gift')) {
    return Icons.card_giftcard_outlined;
  }
  if (item.entityType.contains('dhukuti')) {
    return Icons.account_balance_wallet_outlined;
  }
  if (item.entityType.contains('connection')) {
    return Icons.person_add_alt_1_outlined;
  }
  return Icons.timeline_outlined;
}
