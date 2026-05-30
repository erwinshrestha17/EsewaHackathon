import 'dart:async';

import 'package:flutter/material.dart';

import '../../src/app_state.dart';
import '../../src/finance.dart';
import '../savings_circle/widgets/savings_circle_payment_bottom_sheet.dart';
import 'home_controller.dart';
import 'home_models.dart';
import 'widgets/active_group_card.dart';
import 'widgets/balance_summary_card.dart';
import 'widgets/festival_mode_card.dart';
import 'widgets/home_empty_state.dart';
import 'widgets/home_error_state.dart';
import 'widgets/home_header.dart';
import 'widgets/home_loading_skeleton.dart';
import 'widgets/pending_settlement_card.dart';
import 'widgets/prototype_mode_banner.dart';
import 'widgets/quick_action_grid.dart';
import 'widgets/recent_activity_list.dart';
import 'widgets/upcoming_savings_circle_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.store,
    required this.onNavigate,
    required this.onOpenNotifications,
    required this.onCreateGroup,
    required this.onSettle,
    required this.onScanBill,
    required this.onSendGift,
    required this.onOpenSavingsCircle,
    required this.onOpenFriends,
    required this.onViewActivity,
    required this.onExploreTemplates,
    super.key,
  });

  final AppStore store;
  final ValueChanged<int> onNavigate;
  final VoidCallback onOpenNotifications;
  final VoidCallback onCreateGroup;
  final VoidCallback onSettle;
  final VoidCallback onScanBill;
  final VoidCallback onSendGift;
  final VoidCallback onOpenSavingsCircle;
  final VoidCallback onOpenFriends;
  final VoidCallback onViewActivity;
  final VoidCallback onExploreTemplates;

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
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                    const PrototypeModeBanner(),
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
                    if (data.upcomingSavingsCircleDues.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      UpcomingSavingsCircleCard(
                        due: data.upcomingSavingsCircleDues.first,
                        onPay: () => unawaited(
                          _paySavingsCircleDue(
                            data.upcomingSavingsCircleDues.first,
                          ),
                        ),
                        onViewLedger: widget.onOpenSavingsCircle,
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
                    const SizedBox(height: 18),
                    FestivalModeCard(onExplore: widget.onExploreTemplates),
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
      case 'savings_circle':
        widget.onOpenSavingsCircle();
      case 'connect_friend':
        widget.onOpenFriends();
      default:
        widget.onNavigate(0);
    }
  }

  void _openGroup(HomeGroupSummary group) {
    widget.store.selectedGroupId = group.id;
    widget.onNavigate(1);
  }

  Future<void> _paySavingsCircleDue(HomeSavingsCircleDue due) async {
    final pool = widget.store.poolById(due.poolId);
    final contribution = widget.store.savingsCircleContributions.firstWhere(
      (item) => item.id == due.contributionId,
    );
    final paid = await showSavingsCirclePaymentBottomSheet(
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
