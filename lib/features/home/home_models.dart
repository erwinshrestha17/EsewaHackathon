import 'package:flutter/material.dart';

import '../../src/models.dart';

class HomeDashboardData {
  const HomeDashboardData({
    required this.userProfile,
    required this.balanceSummary,
    required this.pendingSettlements,
    required this.upcomingDhukutiDues,
    required this.activeGroups,
    required this.recentActivities,
    required this.suggestedActions,
  });

  final AppUser userProfile;
  final HomeBalanceSummary balanceSummary;
  final List<HomePendingSettlement> pendingSettlements;
  final List<HomeDhukutiDue> upcomingDhukutiDues;
  final List<HomeGroupSummary> activeGroups;
  final List<HomeActivityItem> recentActivities;
  final List<HomeQuickAction> suggestedActions;

  bool get isEmpty =>
      activeGroups.isEmpty &&
      recentActivities.isEmpty &&
      pendingSettlements.isEmpty &&
      upcomingDhukutiDues.isEmpty;
}

class HomeBalanceSummary {
  const HomeBalanceSummary({
    required this.totalYouOwe,
    required this.totalOwedToYou,
    required this.pendingAmount,
  });

  final int totalYouOwe;
  final int totalOwedToYou;
  final int pendingAmount;

  int get netBalance => totalOwedToYou - totalYouOwe;
}

class HomePendingSettlement {
  const HomePendingSettlement({
    required this.id,
    required this.payerName,
    required this.payeeName,
    required this.counterpartyName,
    required this.counterpartyAvatar,
    required this.groupName,
    required this.amount,
    required this.status,
  });

  final String id;
  final String payerName;
  final String payeeName;
  final String counterpartyName;
  final String counterpartyAvatar;
  final String groupName;
  final int amount;
  final String status;
}

class HomeDhukutiDue {
  const HomeDhukutiDue({
    required this.contributionId,
    required this.poolId,
    required this.poolName,
    required this.amount,
    required this.dueLabel,
    required this.cycleLabel,
    required this.status,
    required this.isPayable,
  });

  final String contributionId;
  final String poolId;
  final String poolName;
  final int amount;
  final String dueLabel;
  final String cycleLabel;
  final String status;
  final bool isPayable;
}

class HomeGroupSummary {
  const HomeGroupSummary({
    required this.id,
    required this.name,
    required this.category,
    required this.icon,
    required this.memberCount,
    required this.userBalance,
    required this.dueStatus,
    required this.recentText,
  });

  final String id;
  final String name;
  final String category;
  final IconData icon;
  final int memberCount;
  final int userBalance;
  final String dueStatus;
  final String recentText;
}

class HomeActivityItem {
  const HomeActivityItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
    this.amount,
    this.status,
  });

  final String id;
  final String title;
  final String subtitle;
  final String timestamp;
  final IconData icon;
  final int? amount;
  final String? status;
}

class HomeQuickAction {
  const HomeQuickAction({
    required this.id,
    required this.label,
    required this.helper,
    required this.icon,
  });

  final String id;
  final String label;
  final String helper;
  final IconData icon;
}
