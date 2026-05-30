import 'package:flutter/material.dart';

import '../../src/app_state.dart';
import '../../src/finance.dart';
import '../../src/models.dart';
import 'home_models.dart';
import 'seeded_home_data.dart';

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
        suggestedActions: seededHomeDashboardData().suggestedActions,
      );
    } catch (_) {
      return seededHomeDashboardData();
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
    final candidates =
        <
          ({
            DhukutiContribution contribution,
            DhukutiCycle cycle,
            DhukutiPool pool,
          })
        >[];
    final now = DateTime.now();
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
        final currentCycle = cycle.first;
        if (_shouldHideDhukutiContribution(contribution, currentCycle)) {
          continue;
        }
        candidates.add((
          contribution: contribution,
          cycle: currentCycle,
          pool: pool,
        ));
      }
    }
    candidates.sort((a, b) {
      final byDueDate = a.contribution.dueDate.compareTo(
        b.contribution.dueDate,
      );
      if (byDueDate != 0) {
        return byDueDate;
      }
      return a.contribution.cycleNumber.compareTo(b.contribution.cycleNumber);
    });

    final futureOrToday = candidates
        .where((item) => !_isPastDue(item.contribution.dueDate, now))
        .toList();
    final visible = futureOrToday.isNotEmpty ? futureOrToday : candidates;

    return [
      for (final item in visible.take(2))
        HomeDhukutiDue(
          contributionId: item.contribution.id,
          poolId: item.pool.id,
          poolName: item.pool.name,
          amount: item.contribution.amountMinor,
          dueLabel: _dueLabel(item.contribution.dueDate),
          cycleLabel: 'Monthly contribution',
          status: _dhukutiDueStatus(item.contribution, item.cycle, now),
          isPayable: _isDhukutiContributionPayable(
            item.pool,
            item.contribution,
            item.cycle,
            now,
          ),
        ),
    ];
  }

  List<HomeGroupSummary> _activeGroups() {
    return [
      for (final group in store.visibleExpenseGroups.take(5))
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

bool _shouldHideDhukutiContribution(
  DhukutiContribution contribution,
  DhukutiCycle cycle,
) {
  if (contribution.status == ContributionStatus.paid ||
      contribution.status == ContributionStatus.cancelled ||
      contribution.status == ContributionStatus.expired) {
    return true;
  }
  return cycle.status == DhukutiCycleStatus.cancelled ||
      cycle.status == DhukutiCycleStatus.closed ||
      cycle.status == DhukutiCycleStatus.paidOut;
}

String _dhukutiDueStatus(
  DhukutiContribution contribution,
  DhukutiCycle cycle,
  DateTime now,
) {
  if (cycle.status == DhukutiCycleStatus.atRisk) {
    return 'At Risk';
  }
  if (contribution.status == ContributionStatus.late ||
      contribution.status == ContributionStatus.missed ||
      _isPastDue(contribution.dueDate, now)) {
    return 'Due Late';
  }
  if (cycle.status == DhukutiCycleStatus.upcoming ||
      contribution.status == ContributionStatus.pending ||
      contribution.dueDate.isAfter(now)) {
    return 'Upcoming';
  }
  return 'Due Soon';
}

bool _isDhukutiContributionPayable(
  DhukutiPool pool,
  DhukutiContribution contribution,
  DhukutiCycle cycle,
  DateTime now,
) {
  return pool.status == DhukutiPoolStatus.active &&
      contribution.status != ContributionStatus.pending &&
      !_isFutureDue(contribution.dueDate, now) &&
      cycle.status != DhukutiCycleStatus.upcoming &&
      cycle.status != DhukutiCycleStatus.cancelled &&
      cycle.status != DhukutiCycleStatus.closed &&
      cycle.status != DhukutiCycleStatus.paidOut;
}

bool _isPastDue(DateTime dueDate, DateTime now) {
  final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final today = DateTime(now.year, now.month, now.day);
  return dueDay.isBefore(today);
}

bool _isFutureDue(DateTime dueDate, DateTime now) {
  final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final today = DateTime(now.year, now.month, now.day);
  return dueDay.isAfter(today);
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
