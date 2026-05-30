import 'package:flutter/material.dart';

import '../../src/finance.dart';
import '../../src/models.dart';
import 'home_models.dart';

HomeDashboardData seededHomeDashboardData() {
  final user = AppUser(
    id: 'seed-user',
    displayName: 'Erwin Shrestha',
    phone: '98XXXXXXXX',
    avatar: 'ES',
    district: 'Bharatpur',
    createdAt: DateTime(2026, 5, 29),
  );

  return HomeDashboardData(
    userProfile: user,
    balanceSummary: HomeBalanceSummary(
      totalYouOwe: npr(1800),
      totalOwedToYou: npr(5050),
      pendingAmount: npr(750),
    ),
    pendingSettlements: [
      HomePendingSettlement(
        id: 'seed-settlement',
        payerName: 'Erwin Shrestha',
        payeeName: 'Sita Shrestha',
        counterpartyName: 'Sita Shrestha',
        counterpartyAvatar: 'SS',
        groupName: 'Dashain Khasi Group',
        amount: npr(750),
        status: 'Pending',
      ),
    ],
    upcomingDhukutiDues: [
      HomeDhukutiDue(
        contributionId: 'seed-dhukuti-contribution',
        poolId: 'seed-dhukuti',
        poolName: 'Family Dashain Community Fund',
        amount: npr(5000),
        dueLabel: '3 days left',
        cycleLabel: 'Monthly contribution',
        status: 'Due Soon',
        isPayable: true,
      ),
    ],
    activeGroups: [
      HomeGroupSummary(
        id: 'seed-dashain',
        name: 'Dashain Khasi Group',
        category: 'Festival',
        icon: Icons.celebration_outlined,
        memberCount: 6,
        userBalance: -npr(1000),
        dueStatus: 'You owe',
        recentText: 'Khasi expense added',
      ),
      HomeGroupSummary(
        id: 'seed-picnic',
        name: 'College Picnic',
        category: 'Event',
        icon: Icons.event_outlined,
        memberCount: 5,
        userBalance: npr(850),
        dueStatus: 'To receive',
        recentText: 'Ramesh paid settlement',
      ),
      HomeGroupSummary(
        id: 'seed-apartment',
        name: 'Apartment Monthly',
        category: 'Household',
        icon: Icons.home_work_outlined,
        memberCount: 4,
        userBalance: 0,
        dueStatus: 'All settled',
        recentText: 'Electricity bill added',
      ),
    ],
    recentActivities: [
      HomeActivityItem(
        id: 'activity-1',
        title: 'Expense added',
        subtitle: 'Dashain Khasi Group',
        amount: npr(6000),
        timestamp: '2h ago',
        icon: Icons.receipt_long_outlined,
        status: 'Active',
      ),
      HomeActivityItem(
        id: 'activity-2',
        title: 'Settlement paid',
        subtitle: 'You paid Sita',
        amount: npr(750),
        timestamp: 'Yesterday',
        icon: Icons.payments_outlined,
        status: 'Paid',
      ),
      HomeActivityItem(
        id: 'activity-3',
        title: 'Gift sent',
        subtitle: 'Dashain gift to Aama',
        amount: npr(1000),
        timestamp: 'Yesterday',
        icon: Icons.card_giftcard_outlined,
        status: 'Sent',
      ),
      HomeActivityItem(
        id: 'activity-4',
        title: 'Contribution confirmed',
        subtitle: 'Family Dashain Community Fund',
        amount: npr(5000),
        timestamp: '2 days ago',
        icon: Icons.savings_outlined,
        status: 'Confirmed',
      ),
      HomeActivityItem(
        id: 'activity-5',
        title: 'Connection approved',
        subtitle: 'Ramesh is now connected',
        timestamp: '3 days ago',
        icon: Icons.person_add_alt_1_outlined,
      ),
    ],
    suggestedActions: const [
      HomeQuickAction(
        id: 'settle',
        label: 'Settle',
        helper: 'Pay open dues',
        icon: Icons.payments_outlined,
      ),
      HomeQuickAction(
        id: 'send_gift',
        label: 'Send Gift',
        helper: 'Money envelope',
        icon: Icons.card_giftcard_outlined,
      ),
      HomeQuickAction(
        id: 'dhukuti',
        label: 'Savings Tracker',
        helper: 'View fund',
        icon: Icons.account_balance_wallet_outlined,
      ),
      HomeQuickAction(
        id: 'connect_friend',
        label: 'Friends',
        helper: 'Trusted contacts',
        icon: Icons.qr_code_2_outlined,
      ),
    ],
  );
}
