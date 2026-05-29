import 'package:flutter/material.dart';

import '../../src/app_state.dart';
import '../../src/finance.dart';
import '../../src/models.dart';
import 'widgets/dhukuti_cycle_card.dart';
import 'widgets/dhukuti_ledger_item.dart';
import 'widgets/dhukuti_member_row.dart';
import 'widgets/dhukuti_payment_bottom_sheet.dart';
import 'widgets/dhukuti_pool_card.dart';
import 'widgets/dhukuti_status_badge.dart';
import 'widgets/dhukuti_tokens.dart';

enum _DhukutiTab { overview, members, schedule, ledger }

class DhukutiDetailScreen extends StatefulWidget {
  const DhukutiDetailScreen({
    required this.store,
    required this.pool,
    this.onBack,
    super.key,
  });

  final AppStore store;
  final DhukutiPool pool;
  final VoidCallback? onBack;

  @override
  State<DhukutiDetailScreen> createState() => _DhukutiDetailScreenState();
}

class _DhukutiDetailScreenState extends State<DhukutiDetailScreen> {
  var _tab = _DhukutiTab.overview;
  var _ledgerFilter = DhukutiLedgerFilter.all;

  @override
  Widget build(BuildContext context) {
    final pool = widget.pool;
    final store = widget.store;
    final members = store.membersForPool(pool.id);
    final cycles =
        store.dhukutiCycles.where((cycle) => cycle.poolId == pool.id).toList()
          ..sort((a, b) => a.cycleNumber.compareTo(b.cycleNumber));
    final currentCycle = currentCycleFor(pool, cycles);
    final currentContributions = store.dhukutiContributions
        .where((item) => item.cycleId == currentCycle?.id)
        .toList();
    final statusLabel = poolDisplayStatus(pool, currentCycle);

    return DhukutiScrollView(
      children: [
        if (widget.onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Dhukuti pools'),
            ),
          ),
        DhukutiHeader(
          title: pool.name,
          subtitle:
              '${widget.store.groupById(pool.groupId).name} • ${money(pool.contributionAmountMinor)} ${pool.frequency}',
          action: DhukutiStatusBadge(
            label: statusLabel,
            tone: toneForPoolStatus(statusLabel),
          ),
        ),
        _TopFacts(store: store, pool: pool, members: members, cycles: cycles),
        if (currentCycle != null)
          _HeroCycleCard(
            store: store,
            pool: pool,
            cycle: currentCycle,
            contributions: currentContributions,
          ),
        _Tabs(selected: _tab, onChanged: (tab) => setState(() => _tab = tab)),
        switch (_tab) {
          _DhukutiTab.overview => _OverviewTab(
            store: store,
            pool: pool,
            cycle: currentCycle,
            contributions: currentContributions,
            onPaid: () => setState(() {}),
          ),
          _DhukutiTab.members => _MembersTab(
            store: store,
            pool: pool,
            members: members,
            cycle: currentCycle,
            contributions: currentContributions,
          ),
          _DhukutiTab.schedule => _ScheduleTab(
            store: store,
            pool: pool,
            members: members,
            cycles: cycles,
            currentCycle: currentCycle,
          ),
          _DhukutiTab.ledger => _LedgerTab(
            store: store,
            pool: pool,
            filter: _ledgerFilter,
            onFilterChanged: (value) => setState(() => _ledgerFilter = value),
          ),
        },
      ],
    );
  }
}

class _TopFacts extends StatelessWidget {
  const _TopFacts({
    required this.store,
    required this.pool,
    required this.members,
    required this.cycles,
  });

  final AppStore store;
  final DhukutiPool pool;
  final List<DhukutiMember> members;
  final List<DhukutiCycle> cycles;

  @override
  Widget build(BuildContext context) {
    final currentCycle = currentCycleFor(pool, cycles);
    return DhukutiResponsiveGrid(
      children: [
        DhukutiMetricCard(
          label: 'Contribution',
          value: money(pool.contributionAmountMinor),
          helper: pool.frequency,
          icon: Icons.savings_outlined,
          tone: DhukutiTone.success,
        ),
        DhukutiMetricCard(
          label: 'Start date',
          value: dateLabel(pool.startDate),
          icon: Icons.calendar_today_outlined,
          tone: DhukutiTone.neutral,
        ),
        DhukutiMetricCard(
          label: 'Members',
          value: '${members.length}',
          icon: Icons.groups_outlined,
          tone: DhukutiTone.info,
        ),
        DhukutiMetricCard(
          label: 'Current cycle',
          value: currentCycle == null
              ? 'Pending'
              : '${currentCycle.cycleNumber} of ${cycles.length}',
          icon: Icons.event_repeat,
          tone: currentCycle?.status == DhukutiCycleStatus.atRisk
              ? DhukutiTone.warning
              : DhukutiTone.success,
        ),
      ],
    );
  }
}

class _HeroCycleCard extends StatelessWidget {
  const _HeroCycleCard({
    required this.store,
    required this.pool,
    required this.cycle,
    required this.contributions,
  });

  final AppStore store;
  final DhukutiPool pool;
  final DhukutiCycle cycle;
  final List<DhukutiContribution> contributions;

  @override
  Widget build(BuildContext context) {
    final paidCount = contributions
        .where((item) => item.status == ContributionStatus.paid)
        .length;
    final progress = contributions.isEmpty
        ? 0.0
        : paidCount / contributions.length;
    final recipient = store.userById(cycle.payoutRecipientId);
    final cycleStatus = _friendlyCycleStatus(cycle.status);
    final tone = toneForCycleStatus(cycle.status);
    final color = dhukutiToneColor(context, tone);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cycle ${cycle.cycleNumber} of ${contributions.length}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text('Current payout recipient'),
                  ],
                ),
              ),
              DhukutiStatusBadge(label: cycleStatus, tone: tone),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              DhukutiAvatar(label: recipient.avatar),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipient.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Expected payout amount ${money(cycle.expectedContributionTotalMinor)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: progress,
                    backgroundColor: color.withValues(alpha: 0.14),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$paidCount of ${contributions.length} paid',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Due date: ${dateLabel(cycle.dueDate)}'),
          if (cycle.status == DhukutiCycleStatus.atRisk) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_outlined, color: color),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Some contributions are still unpaid. Payout is not shown as guaranteed.',
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onChanged});

  final _DhukutiTab selected;
  final ValueChanged<_DhukutiTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<_DhukutiTab>(
        selected: {selected},
        onSelectionChanged: (value) => onChanged(value.first),
        segments: const [
          ButtonSegment(
            value: _DhukutiTab.overview,
            label: Text('Overview'),
            icon: Icon(Icons.dashboard_outlined),
          ),
          ButtonSegment(
            value: _DhukutiTab.members,
            label: Text('Members'),
            icon: Icon(Icons.groups_outlined),
          ),
          ButtonSegment(
            value: _DhukutiTab.schedule,
            label: Text('Schedule'),
            icon: Icon(Icons.event_note_outlined),
          ),
          ButtonSegment(
            value: _DhukutiTab.ledger,
            label: Text('Ledger'),
            icon: Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.store,
    required this.pool,
    required this.cycle,
    required this.contributions,
    required this.onPaid,
  });

  final AppStore store;
  final DhukutiPool pool;
  final DhukutiCycle? cycle;
  final List<DhukutiContribution> contributions;
  final VoidCallback onPaid;

  @override
  Widget build(BuildContext context) {
    if (cycle == null) {
      return const DhukutiEmptyState(
        icon: Icons.event_busy_outlined,
        title: 'No cycle schedule',
        message: 'The contribution schedule has not been generated yet.',
      );
    }
    final paidTotal = cycle!.paidContributionTotalMinor;
    final remaining = cycle!.expectedContributionTotalMinor - paidTotal;
    final paidCount = contributions
        .where((item) => item.status == ContributionStatus.paid)
        .length;
    final myContribution = contributions
        .where((item) => item.userId == store.currentUserId)
        .cast<DhukutiContribution?>()
        .firstWhere((item) => item != null, orElse: () => null);
    final canPay =
        myContribution != null &&
        myContribution.status != ContributionStatus.paid &&
        myContribution.status != ContributionStatus.pending &&
        cycle!.status != DhukutiCycleStatus.upcoming;

    return DhukutiSection(
      title: 'Overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DhukutiResponsiveGrid(
            children: [
              DhukutiMetricCard(
                label: 'Contribution amount',
                value: money(pool.contributionAmountMinor),
                icon: Icons.savings_outlined,
                tone: DhukutiTone.success,
              ),
              DhukutiMetricCard(
                label: 'Expected collection',
                value: money(cycle!.expectedContributionTotalMinor),
                icon: Icons.account_balance_wallet_outlined,
                tone: DhukutiTone.info,
              ),
              DhukutiMetricCard(
                label: 'Paid so far',
                value: money(paidTotal),
                icon: Icons.check_circle_outline,
                tone: DhukutiTone.success,
              ),
              DhukutiMetricCard(
                label: 'Remaining amount',
                value: money(remaining),
                icon: Icons.pending_actions_outlined,
                tone: remaining == 0
                    ? DhukutiTone.success
                    : DhukutiTone.warning,
              ),
              DhukutiMetricCard(
                label: 'Current recipient',
                value: store.nameOf(cycle!.payoutRecipientId),
                icon: Icons.person_pin_circle_outlined,
                tone: DhukutiTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$paidCount of ${contributions.length} contributions paid',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            minHeight: 10,
            borderRadius: BorderRadius.circular(999),
            value: contributions.isEmpty ? 0 : paidCount / contributions.length,
          ),
          const SizedBox(height: 16),
          _NextActionCard(
            paid: myContribution?.status == ContributionStatus.paid,
            canPay: canPay,
            onPay: myContribution == null
                ? null
                : () async {
                    final paid = await showDhukutiPaymentBottomSheet(
                      context: context,
                      store: store,
                      pool: pool,
                      contribution: myContribution,
                    );
                    if (paid) {
                      onPaid();
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.paid,
    required this.canPay,
    required this.onPay,
  });

  final bool paid;
  final bool canPay;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            paid
                ? Icons.check_circle_outline
                : Icons.account_balance_wallet_outlined,
            color: paid ? dhukutiPrimary : dhukutiFestival,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              paid
                  ? 'Your contribution is paid'
                  : canPay
                  ? 'Your current cycle contribution is due.'
                  : 'No payable contribution is open for you right now.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            onPressed: canPay ? onPay : null,
            child: const Text('Pay Contribution'),
          ),
        ],
      ),
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({
    required this.store,
    required this.pool,
    required this.members,
    required this.cycle,
    required this.contributions,
  });

  final AppStore store;
  final DhukutiPool pool;
  final List<DhukutiMember> members;
  final DhukutiCycle? cycle;
  final List<DhukutiContribution> contributions;

  @override
  Widget build(BuildContext context) {
    return DhukutiSection(
      title: 'Members',
      child: Column(
        children: [
          for (final member in members)
            DhukutiMemberRow(
              store: store,
              member: member,
              isOrganizer: member.userId == pool.createdBy,
              contribution: contributions
                  .where((item) => item.userId == member.userId)
                  .cast<DhukutiContribution?>()
                  .firstWhere((item) => item != null, orElse: () => null),
              amountMinor: pool.contributionAmountMinor,
            ),
        ],
      ),
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({
    required this.store,
    required this.pool,
    required this.members,
    required this.cycles,
    required this.currentCycle,
  });

  final AppStore store;
  final DhukutiPool pool;
  final List<DhukutiMember> members;
  final List<DhukutiCycle> cycles;
  final DhukutiCycle? currentCycle;

  @override
  Widget build(BuildContext context) {
    return DhukutiSection(
      title: 'Schedule',
      child: Column(
        children: [
          for (final cycle in cycles)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DhukutiCycleCard(
                store: store,
                cycle: cycle,
                members: members,
                contributions: store.dhukutiContributions
                    .where((item) => item.cycleId == cycle.id)
                    .toList(),
                current: cycle.id == currentCycle?.id,
              ),
            ),
        ],
      ),
    );
  }
}

class _LedgerTab extends StatelessWidget {
  const _LedgerTab({
    required this.store,
    required this.pool,
    required this.filter,
    required this.onFilterChanged,
  });

  final AppStore store;
  final DhukutiPool pool;
  final DhukutiLedgerFilter filter;
  final ValueChanged<DhukutiLedgerFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final events =
        store.activity
            .where(
              (event) =>
                  event.groupId == pool.groupId &&
                  ledgerEventMatches(event, filter),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return DhukutiSection(
      title: 'Transparent Ledger',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 8,
              children: [
                for (final item in DhukutiLedgerFilter.values)
                  ChoiceChip(
                    selected: filter == item,
                    label: Text(_filterLabel(item)),
                    onSelected: (_) => onFilterChanged(item),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const DhukutiEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No ledger activity',
              message: 'Dhukuti actions and status updates appear here.',
            )
          else
            for (final event in events)
              DhukutiLedgerItem(store: store, event: event),
        ],
      ),
    );
  }
}

String _friendlyCycleStatus(DhukutiCycleStatus status) {
  return switch (status) {
    DhukutiCycleStatus.open => 'On Track',
    DhukutiCycleStatus.atRisk => 'At Risk',
    DhukutiCycleStatus.readyForPayout => 'Ready for Payout',
    DhukutiCycleStatus.paidOut => 'Paid Out',
    DhukutiCycleStatus.closed => 'Closed',
    DhukutiCycleStatus.upcoming => 'Upcoming',
    DhukutiCycleStatus.cancelled => 'Cancelled',
  };
}

String _filterLabel(DhukutiLedgerFilter filter) {
  return switch (filter) {
    DhukutiLedgerFilter.all => 'All',
    DhukutiLedgerFilter.contributions => 'Contributions',
    DhukutiLedgerFilter.payouts => 'Payouts',
    DhukutiLedgerFilter.statusUpdates => 'Status Updates',
  };
}
