import 'dart:async';

import 'package:flutter/material.dart';

import '../../src/app_state.dart';
import '../../src/finance.dart';
import '../../shared/spending/spending_habits.dart';
import '../dhukuti/widgets/dhukuti_payment_bottom_sheet.dart';
import 'home_controller.dart';
import 'home_models.dart';
import 'widgets/active_group_card.dart';
import 'widgets/balance_summary_card.dart';
import 'widgets/home_empty_state.dart';
import 'widgets/home_error_state.dart';
import 'widgets/home_header.dart';
import 'widgets/home_loading_skeleton.dart';
import 'widgets/pending_settlement_card.dart';
import 'widgets/quick_action_grid.dart';
import 'widgets/recent_activity_list.dart';
import 'widgets/upcoming_dhukuti_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.store,
    required this.onNavigate,
    required this.onOpenNotifications,
    required this.onCreateGroup,
    required this.onSettle,
    required this.onScanBill,
    required this.onSendGift,
    required this.onOpenDhukuti,
    required this.onOpenFriends,
    required this.onViewActivity,
    super.key,
  });

  final AppStore store;
  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenNotifications;
  final VoidCallback onCreateGroup;
  final VoidCallback onSettle;
  final VoidCallback onScanBill;
  final VoidCallback onSendGift;
  final VoidCallback onOpenDhukuti;
  final VoidCallback onOpenFriends;
  final VoidCallback onViewActivity;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const HomeLoadingSkeleton();
    }
    if (_error != null) {
      return HomeErrorState(onRetry: () => setState(() => _error = null));
    }

    final data = HomeController(store: widget.store).loadDashboard();
    final unread = widget.store.currentNotifications.any((item) => !item.read);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth > 760 ? 720.0 : double.infinity;
        final safePadding = MediaQuery.paddingOf(context);
        return ListView(
          padding: EdgeInsets.fromLTRB(
            16 + safePadding.left,
            16,
            16 + safePadding.right,
            24 + safePadding.bottom,
          ),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    HomeHeader(
                      displayName: data.userProfile.displayName,
                      hasUnreadNotifications: unread,
                      onNotifications: widget.onOpenNotifications,
                    ),
                    const SizedBox(height: 14),
                    BalanceSummaryCard(
                      summary: data.balanceSummary,
                      groupCount: data.activeGroups.length,
                      pendingCount: data.pendingSettlements.length,
                    ),
                    const SizedBox(height: 18),
                    QuickActionGrid(
                      actions: data.suggestedActions,
                      onAction: _handleQuickAction,
                    ),
                    const SizedBox(height: 18),
                    SpendingHabitsPanel(
                      title: 'Personal spending habits',
                      subtitle:
                          'Your share across all active Sajha Kharcha groups.',
                      expenses: widget.store.expenses,
                      userId: widget.store.currentUserId,
                      scope: SpendingInsightScope.personal,
                    ),
                    if (data.isEmpty) ...[
                      const SizedBox(height: 18),
                      HomeEmptyState(
                        onCreateGroup: widget.onCreateGroup,
                        onConnectFriend: widget.onOpenFriends,
                      ),
                    ],
                    if (data.pendingSettlements.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      PendingSettlementCard(
                        items: data.pendingSettlements,
                        onView: _showPendingSettlement,
                      ),
                    ],
                    if (data.upcomingDhukutiDues.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      UpcomingDhukutiCard(
                        due: data.upcomingDhukutiDues.first,
                        onPay: () => unawaited(
                          _payDhukutiDue(data.upcomingDhukutiDues.first),
                        ),
                        onViewLedger: widget.onOpenDhukuti,
                      ),
                    ],
                    const SizedBox(height: 18),
                    ActiveGroupSection(
                      groups: data.activeGroups,
                      onViewAll: () => widget.onNavigate(1),
                      onGroupTap: _openGroup,
                    ),
                    const SizedBox(height: 18),
                    RecentActivityList(
                      items: data.recentActivities,
                      onViewAll: widget.onViewActivity,
                      onItemTap: (_) => widget.onViewActivity(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleQuickAction(String id) {
    switch (id) {
      case 'settle':
        widget.onSettle();
      case 'send_gift':
        widget.onSendGift();
      case 'dhukuti':
        widget.onOpenDhukuti();
      case 'connect_friend':
        widget.onOpenFriends();
      case 'create_group':
        widget.onCreateGroup();
      case 'add_expense':
        widget.onNavigate(1);
      default:
        widget.onNavigate(0);
    }
  }

  void _openGroup(HomeGroupSummary group) {
    widget.store.selectedGroupId = group.id;
    widget.onNavigate(1);
  }

  Future<void> _payDhukutiDue(HomeDhukutiDue due) async {
    final pool = widget.store.poolById(due.poolId);
    final contribution = widget.store.dhukutiContributions.firstWhere(
      (item) => item.id == due.contributionId,
    );
    final paid = await showDhukutiPaymentBottomSheet(
      context: context,
      store: widget.store,
      pool: pool,
      contribution: contribution,
    );
    if (paid && mounted) {
      setState(() {});
    }
  }

  void _showPendingSettlement(HomePendingSettlement settlement) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settlement status',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                _StatusLine('Payee', settlement.payeeName),
                _StatusLine('Group', settlement.groupName),
                _StatusLine('Amount', money(settlement.amount)),
                _StatusLine('Status', settlement.status),
                const SizedBox(height: 12),
                const Text(
                  'This pending payment does not reduce open balance until it is marked paid.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
