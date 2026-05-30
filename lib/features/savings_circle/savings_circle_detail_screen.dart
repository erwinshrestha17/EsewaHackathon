import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/settings/settings_models.dart';
import '../../shared/transactions/transaction_confirmation_controller.dart';
import '../../shared/transactions/transaction_confirmation_data.dart';
import '../../shared/transactions/transaction_status.dart';
import '../../shared/transactions/transaction_type.dart';
import '../../src/app_state.dart';
import '../../src/finance.dart';
import '../../src/models.dart';
import 'widgets/savings_circle_cycle_card.dart';
import 'widgets/savings_circle_ledger_item.dart';
import 'widgets/savings_circle_member_row.dart';
import 'widgets/savings_circle_payment_bottom_sheet.dart';
import 'widgets/savings_circle_pool_card.dart';
import 'widgets/savings_circle_status_badge.dart';
import 'widgets/savings_circle_tokens.dart';

enum _SavingsCircleTab { overview, members, schedule, ledger }

Future<void> showRenameSavingsCirclePoolDialog({
  required BuildContext context,
  required AppStore store,
  required SavingsCirclePool pool,
  required VoidCallback onRenamed,
}) async {
  if (!store.canManageSavingsCirclePool(pool.id, store.currentUserId)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Only the Savings Circle admin can rename this group.'),
      ),
    );
    return;
  }
  final name = TextEditingController(text: pool.name);
  String? errorText;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Rename Savings Circle group'),
            content: SizedBox(
              width: 420,
              child: TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Savings Circle group name',
                  errorText: errorText,
                ),
                onChanged: (_) {
                  if (errorText != null) {
                    setState(() => errorText = null);
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final error = store.renameSavingsCirclePool(
                    pool.id,
                    name.text,
                  );
                  if (error != null) {
                    setState(() => errorText = error);
                    return;
                  }
                  Navigator.pop(dialogContext);
                  onRenamed();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${pool.name} saved.')),
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
  name.dispose();
}

class SavingsCircleDetailScreen extends StatefulWidget {
  const SavingsCircleDetailScreen({
    required this.store,
    required this.pool,
    this.onBack,
    super.key,
  });

  final AppStore store;
  final SavingsCirclePool pool;
  final VoidCallback? onBack;

  @override
  State<SavingsCircleDetailScreen> createState() =>
      _SavingsCircleDetailScreenState();
}

class _SavingsCircleDetailScreenState extends State<SavingsCircleDetailScreen> {
  var _tab = _SavingsCircleTab.overview;
  var _ledgerFilter = SavingsCircleLedgerFilter.all;

  @override
  Widget build(BuildContext context) {
    final pool = widget.pool;
    final store = widget.store;
    final members = store.membersForPool(pool.id);
    final cycles =
        store.savingsCircleCycles
            .where((cycle) => cycle.poolId == pool.id)
            .toList()
          ..sort((a, b) => a.cycleNumber.compareTo(b.cycleNumber));
    final currentCycle = currentCycleFor(pool, cycles);
    final currentContributions = store.savingsCircleContributions
        .where((item) => item.cycleId == currentCycle?.id)
        .toList();
    final statusLabel = poolDisplayStatus(pool, currentCycle);
    final canManage = store.canManageSavingsCirclePool(
      pool.id,
      store.currentUserId,
    );

    return SavingsCircleScrollView(
      children: [
        if (widget.onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Savings Circle pools'),
            ),
          ),
        SavingsCircleHeader(
          title: pool.name,
          subtitle:
              '${widget.store.groupById(pool.groupId).name} • ${money(pool.contributionAmountMinor)} ${pool.frequency}',
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              SavingsCircleStatusBadge(
                label: statusLabel,
                tone: toneForPoolStatus(statusLabel),
              ),
              if (canManage)
                OutlinedButton.icon(
                  onPressed: () => showRenameSavingsCirclePoolDialog(
                    context: context,
                    store: store,
                    pool: pool,
                    onRenamed: () => setState(() {}),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Rename'),
                ),
            ],
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
          _SavingsCircleTab.overview => _OverviewTab(
            store: store,
            pool: pool,
            cycle: currentCycle,
            contributions: currentContributions,
            onPaid: () => setState(() {}),
          ),
          _SavingsCircleTab.members => _MembersTab(
            store: store,
            pool: pool,
            members: members,
            cycle: currentCycle,
            contributions: currentContributions,
          ),
          _SavingsCircleTab.schedule => _ScheduleTab(
            store: store,
            pool: pool,
            members: members,
            cycles: cycles,
            currentCycle: currentCycle,
          ),
          _SavingsCircleTab.ledger => _LedgerTab(
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
  final SavingsCirclePool pool;
  final List<SavingsCircleMember> members;
  final List<SavingsCircleCycle> cycles;

  @override
  Widget build(BuildContext context) {
    final currentCycle = currentCycleFor(pool, cycles);
    return SavingsCircleResponsiveGrid(
      children: [
        SavingsCircleMetricCard(
          label: 'Contribution',
          value: money(pool.contributionAmountMinor),
          helper: pool.frequency,
          icon: Icons.savings_outlined,
          tone: SavingsCircleTone.success,
        ),
        SavingsCircleMetricCard(
          label: 'Start date',
          value: dateLabel(pool.startDate),
          icon: Icons.calendar_today_outlined,
          tone: SavingsCircleTone.neutral,
        ),
        SavingsCircleMetricCard(
          label: 'Members',
          value: '${members.length}',
          icon: Icons.groups_outlined,
          tone: SavingsCircleTone.info,
        ),
        SavingsCircleMetricCard(
          label: 'Current cycle',
          value: currentCycle == null
              ? 'Pending'
              : '${currentCycle.cycleNumber} of ${cycles.length}',
          icon: Icons.event_repeat,
          tone: currentCycle?.status == SavingsCircleCycleStatus.atRisk
              ? SavingsCircleTone.warning
              : SavingsCircleTone.success,
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
  final SavingsCirclePool pool;
  final SavingsCircleCycle cycle;
  final List<SavingsCircleContribution> contributions;

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
    final color = savingsCircleToneColor(context, tone);

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
              SavingsCircleStatusBadge(label: cycleStatus, tone: tone),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SavingsCircleAvatar(label: recipient.avatar),
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
          if (cycle.status == SavingsCircleCycleStatus.atRisk) ...[
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
          if (cycle.status == SavingsCircleCycleStatus.readyForPayout ||
              cycle.status == SavingsCircleCycleStatus.atRisk) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => unawaited(
                openTransactionConfirmation(
                  context,
                  _payoutConfirmationData(store, pool, cycle),
                  () async {
                    final wasReady =
                        cycle.status == SavingsCircleCycleStatus.readyForPayout;
                    final reference = store.confirmSavingsCirclePayoutReview(
                      cycle.id,
                    );
                    return TransactionResult.success(
                      title: wasReady
                          ? 'Payout Recorded'
                          : 'Payout Review Recorded',
                      message:
                          'Your Savings Circle ledger has been updated without implying a guaranteed payout.',
                      amount: cycle.expectedContributionTotalMinor,
                      transactionReference: reference,
                      createdAt: DateTime.now(),
                    );
                  },
                ),
              ),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Review payout'),
            ),
          ],
        ],
      ),
    );
  }
}

TransactionConfirmationData _payoutConfirmationData(
  AppStore store,
  SavingsCirclePool pool,
  SavingsCircleCycle cycle,
) {
  return TransactionConfirmationData(
    id: 'savings-circle-payout-${cycle.id}',
    transactionType: TransactionType.savingsCirclePayout,
    title: 'Confirm Payout',
    subtitle: '${pool.name} • Cycle ${cycle.cycleNumber}',
    amount: cycle.expectedContributionTotalMinor,
    payerName: pool.name,
    payerAvatarUrl: 'D',
    recipientName: store.nameOf(cycle.payoutRecipientId),
    recipientAvatarUrl: store.userById(cycle.payoutRecipientId).avatar,
    poolName: pool.name,
    warningMessage: cycle.status == SavingsCircleCycleStatus.atRisk
        ? 'Some contributions are unpaid. This payout should not be shown as guaranteed.'
        : null,
    complianceNote: savingsCircleSafetyNoteText,
    confirmationButtonText: 'Confirm Payout',
    createdAt: DateTime.now(),
    idempotencyKey: '${pool.id}-payout-${cycle.cycleNumber}',
    operationType: 'savings_circle_payout',
    details: [
      TransactionDetail('Cycle', 'Cycle ${cycle.cycleNumber}'),
      TransactionDetail(
        'Paid contribution total',
        money(cycle.paidContributionTotalMinor),
      ),
      TransactionDetail('Cycle status', enumLabel(cycle.status)),
    ],
  );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onChanged});

  final _SavingsCircleTab selected;
  final ValueChanged<_SavingsCircleTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<_SavingsCircleTab>(
        selected: {selected},
        onSelectionChanged: (value) => onChanged(value.first),
        segments: const [
          ButtonSegment(
            value: _SavingsCircleTab.overview,
            label: Text('Overview'),
            icon: Icon(Icons.dashboard_outlined),
          ),
          ButtonSegment(
            value: _SavingsCircleTab.members,
            label: Text('Members'),
            icon: Icon(Icons.groups_outlined),
          ),
          ButtonSegment(
            value: _SavingsCircleTab.schedule,
            label: Text('Schedule'),
            icon: Icon(Icons.event_note_outlined),
          ),
          ButtonSegment(
            value: _SavingsCircleTab.ledger,
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
  final SavingsCirclePool pool;
  final SavingsCircleCycle? cycle;
  final List<SavingsCircleContribution> contributions;
  final VoidCallback onPaid;

  @override
  Widget build(BuildContext context) {
    if (cycle == null) {
      return const SavingsCircleEmptyState(
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
        .cast<SavingsCircleContribution?>()
        .firstWhere((item) => item != null, orElse: () => null);
    final canPay =
        myContribution != null &&
        myContribution.status != ContributionStatus.paid &&
        myContribution.status != ContributionStatus.pending &&
        cycle!.status != SavingsCircleCycleStatus.upcoming;

    return SavingsCircleSection(
      title: 'Overview',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SavingsCircleResponsiveGrid(
            children: [
              SavingsCircleMetricCard(
                label: 'Contribution amount',
                value: money(pool.contributionAmountMinor),
                icon: Icons.savings_outlined,
                tone: SavingsCircleTone.success,
              ),
              SavingsCircleMetricCard(
                label: 'Expected collection',
                value: money(cycle!.expectedContributionTotalMinor),
                icon: Icons.account_balance_wallet_outlined,
                tone: SavingsCircleTone.info,
              ),
              SavingsCircleMetricCard(
                label: 'Paid so far',
                value: money(paidTotal),
                icon: Icons.check_circle_outline,
                tone: SavingsCircleTone.success,
              ),
              SavingsCircleMetricCard(
                label: 'Remaining amount',
                value: money(remaining),
                icon: Icons.pending_actions_outlined,
                tone: remaining == 0
                    ? SavingsCircleTone.success
                    : SavingsCircleTone.warning,
              ),
              SavingsCircleMetricCard(
                label: 'Current recipient',
                value: store.nameOf(cycle!.payoutRecipientId),
                icon: Icons.person_pin_circle_outlined,
                tone: SavingsCircleTone.neutral,
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
                    final paid = await showSavingsCirclePaymentBottomSheet(
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
          const SizedBox(height: 12),
          _SavingsCircleExitCard(
            store: store,
            pool: pool,
            contribution: myContribution,
            onChanged: onPaid,
          ),
        ],
      ),
    );
  }
}

class _SavingsCircleExitCard extends StatelessWidget {
  const _SavingsCircleExitCard({
    required this.store,
    required this.pool,
    required this.contribution,
    required this.onChanged,
  });

  final AppStore store;
  final SavingsCirclePool pool;
  final SavingsCircleContribution? contribution;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final decision = store.savingsCircleExitDecision(pool.id);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.exit_to_app_outlined,
                color: savingsCircleFestival,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  decision.title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(decision.message),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (decision.secondaryAction != null)
                OutlinedButton(
                  onPressed: () =>
                      _showSavingsCircleExitDialog(context, store, pool),
                  child: Text(decision.secondaryAction!),
                ),
              FilledButton(
                onPressed:
                    decision.type == SavingsCircleExitDecisionType.unavailable
                    ? null
                    : () async {
                        if (decision.type ==
                            SavingsCircleExitDecisionType.pendingContribution) {
                          final paidAmount = store
                              .payRemainingSavingsCircleExitContributions(
                                pool.id,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  paidAmount == 0
                                      ? 'No remaining contribution is open.'
                                      : 'Paid ${money(paidAmount)} toward remaining Savings Circle obligations.',
                                ),
                              ),
                            );
                          }
                          onChanged();
                          return;
                        }
                        if (decision.type ==
                                SavingsCircleExitDecisionType.receivedPayout &&
                            decision.amountMinor > 0 &&
                            contribution != null) {
                          final paid =
                              await showSavingsCirclePaymentBottomSheet(
                                context: context,
                                store: store,
                                pool: pool,
                                contribution: contribution!,
                              );
                          if (paid) {
                            onChanged();
                          }
                          return;
                        }
                        if (decision.canLeaveNow) {
                          final error = store.leaveSavingsCircleBeforeStart(
                            pool.id,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  error ?? 'You left ${pool.name}.',
                                ),
                              ),
                            );
                          }
                          onChanged();
                          return;
                        }
                        await _showSavingsCircleExitDialog(
                          context,
                          store,
                          pool,
                        );
                        onChanged();
                      },
                child: Text(decision.primaryAction ?? 'Request Exit'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _showSavingsCircleExitDialog(
  BuildContext context,
  AppStore store,
  SavingsCirclePool pool,
) async {
  final decision = store.savingsCircleExitDecision(pool.id);
  final reason = TextEditingController(
    text: decision.type == SavingsCircleExitDecisionType.pendingContribution
        ? 'Requesting admin review before remaining contributions are fully paid'
        : decision.type == SavingsCircleExitDecisionType.receivedPayout
        ? 'Requesting exit approval after payout'
        : 'Need to exit before receiving payout',
  );
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(decision.title),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(decision.message),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for admin and member review',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: decision.canRequestApproval
              ? () {
                  store.requestEmergencyExit(pool.id, reason.text);
                  Navigator.pop(dialogContext);
                }
              : null,
          child: const Text('Request Review'),
        ),
      ],
    ),
  );
  reason.dispose();
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
            color: paid ? savingsCirclePrimary : savingsCircleFestival,
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
  final SavingsCirclePool pool;
  final List<SavingsCircleMember> members;
  final SavingsCircleCycle? cycle;
  final List<SavingsCircleContribution> contributions;

  @override
  Widget build(BuildContext context) {
    return SavingsCircleSection(
      title: 'Members',
      child: Column(
        children: [
          for (final member in members)
            SavingsCircleMemberRow(
              store: store,
              member: member,
              isOrganizer: member.userId == pool.createdBy,
              contribution: contributions
                  .where((item) => item.userId == member.userId)
                  .cast<SavingsCircleContribution?>()
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
  final SavingsCirclePool pool;
  final List<SavingsCircleMember> members;
  final List<SavingsCircleCycle> cycles;
  final SavingsCircleCycle? currentCycle;

  @override
  Widget build(BuildContext context) {
    return SavingsCircleSection(
      title: 'Schedule',
      child: Column(
        children: [
          for (final cycle in cycles)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SavingsCircleCycleCard(
                store: store,
                cycle: cycle,
                members: members,
                contributions: store.savingsCircleContributions
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
  final SavingsCirclePool pool;
  final SavingsCircleLedgerFilter filter;
  final ValueChanged<SavingsCircleLedgerFilter> onFilterChanged;

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

    return SavingsCircleSection(
      title: 'Transparent Ledger',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 8,
              children: [
                for (final item in SavingsCircleLedgerFilter.values)
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
            const SavingsCircleEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No ledger activity',
              message: 'Savings Circle actions and status updates appear here.',
            )
          else
            for (final event in events)
              SavingsCircleLedgerItem(store: store, event: event),
        ],
      ),
    );
  }
}

String _friendlyCycleStatus(SavingsCircleCycleStatus status) {
  return switch (status) {
    SavingsCircleCycleStatus.open => 'On Track',
    SavingsCircleCycleStatus.atRisk => 'At Risk',
    SavingsCircleCycleStatus.readyForPayout => 'Ready for Payout',
    SavingsCircleCycleStatus.paidOut => 'Paid Out',
    SavingsCircleCycleStatus.closed => 'Closed',
    SavingsCircleCycleStatus.upcoming => 'Upcoming',
    SavingsCircleCycleStatus.cancelled => 'Cancelled',
  };
}

String _filterLabel(SavingsCircleLedgerFilter filter) {
  return switch (filter) {
    SavingsCircleLedgerFilter.all => 'All',
    SavingsCircleLedgerFilter.contributions => 'Contributions',
    SavingsCircleLedgerFilter.payouts => 'Payouts',
    SavingsCircleLedgerFilter.statusUpdates => 'Status Updates',
  };
}
