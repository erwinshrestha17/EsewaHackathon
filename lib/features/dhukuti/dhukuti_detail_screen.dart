import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../../shared/design_system/app_components.dart' as ds;
import '../../shared/design_system/app_spacing.dart';
import '../../shared/design_system/app_text_styles.dart';
import '../../src/app_state.dart';
import '../../src/finance.dart';
import '../../src/models.dart';
import 'community_savings_api.dart';
import 'widgets/dhukuti_status_badge.dart';
import 'widgets/dhukuti_tokens.dart';

const List<String> _paymentMethods = [
  'Cash',
  'Bank Transfer',
  'eSewa',
  'Khalti',
  'IME Pay',
  'Other',
];

const List<String> _expenseCategories = [
  'Food',
  'Event',
  'Emergency',
  'Maintenance',
  'Donation',
  'Travel',
  'Supplies',
  'Other',
];

enum _TrackerTab { dashboard, monthlyTracker, history }

enum _LedgerTab { all, contributions, expenses }

enum _ContributionUiStatus { pending, submitted, confirmedReceived, waived }

enum _LedgerItemType { contribution, expense }

Future<void> showRenameDhukutiPoolDialog({
  required BuildContext context,
  required AppStore store,
  required DhukutiPool pool,
  required VoidCallback onRenamed,
}) async {
  if (!store.canManageDhukutiPool(pool.id, store.currentUserId)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Only the Community Savings Tracker admin can rename this group.',
        ),
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
            title: const Text('Rename community fund group'),
            content: SizedBox(
              width: 420,
              child: TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Group name',
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
                  final error = store.renameDhukutiPool(pool.id, name.text);
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
  final bool isAdmin = true;
  final _api = CommunitySavingsApi();
  var _tab = _TrackerTab.dashboard;
  var _ledgerTab = _LedgerTab.all;
  late _CommunitySavingsGroup _communityGroup;
  var _members = <_CommunitySavingsMember>[];
  var _contributions = <_ContributionRecord>[];
  var _expenses = <_CommunityExpense>[];
  var _ledger = <_LedgerRecord>[];
  var _isLoading = true;
  String? _error;
  String? _month;

  @override
  void initState() {
    super.initState();
    final store = widget.store;
    final group = store.groupById(widget.pool.groupId);
    _communityGroup = _CommunitySavingsGroup(
      id: widget.pool.id,
      name: group.name,
      monthlyContributionAmount: widget.pool.contributionAmountMinor,
      currency: 'Rs.',
      currentBalance: 0,
    );
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.dashboard(
        widget.pool.id,
        accessToken: await _accessToken(),
      );
      if (!mounted) {
        return;
      }
      final group = data['group'] as Map<String, dynamic>;
      final summary = data['summary'] as Map<String, dynamic>;
      final members = (data['members'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final contributions = (data['contributions'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final expenses = (data['expenses'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      setState(() {
        _month = data['month']?.toString();
        _communityGroup = _CommunitySavingsGroup.fromJson(
          group,
          currentBalance: _readInt(summary, 'fundBalance'),
        );
        _members = [
          for (final item in members) _CommunitySavingsMember.fromJson(item),
        ];
        _contributions = [
          for (final item in contributions) _ContributionRecord.fromJson(item),
        ];
        _expenses = [
          for (final item in expenses) _CommunityExpense.fromJson(item),
        ];
        _ledger = [
          for (final item in _contributions)
            if (item.status == _ContributionUiStatus.confirmedReceived)
              _LedgerRecord.contribution(
                item,
                item.confirmedAt ?? DateTime.now(),
              ),
          for (final item in _expenses) _LedgerRecord.expense(item),
        ]..sort((a, b) => b.date.compareTo(a.date));
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  int get _totalConfirmedContributions => _contributions
      .where((item) => item.status == _ContributionUiStatus.confirmedReceived)
      .fold<int>(0, (sum, item) => sum + item.receivedAmount);

  int get _totalRecordedExpenses =>
      _expenses.fold<int>(0, (sum, item) => sum + item.amount);

  int get _fundBalance => _totalConfirmedContributions - _totalRecordedExpenses;

  int get _receivedThisMonth => _contributions
      .where((item) => item.status == _ContributionUiStatus.confirmedReceived)
      .fold<int>(0, (sum, item) => sum + item.receivedAmount);

  int get _pendingCount => _contributions
      .where(
        (item) =>
            item.status == _ContributionUiStatus.pending ||
            item.status == _ContributionUiStatus.submitted,
      )
      .length;

  int get _expensesThisMonth =>
      _expenses.fold<int>(0, (sum, item) => sum + item.amount);

  int get _totalExpectedThisMonth =>
      _contributions.fold<int>(0, (sum, item) => sum + item.expectedAmount);

  @override
  Widget build(BuildContext context) {
    final currentMonth = _monthLabel(DateTime.now());
    return DhukutiScrollView(
      children: [
        if (widget.onBack != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Community savings groups'),
            ),
          ),
        DhukutiHeader(
          title: 'Community Savings Tracker',
          subtitle: '${_communityGroup.name} • $currentMonth',
          action: isAdmin
              ? OutlinedButton.icon(
                  onPressed: () => showRenameDhukutiPoolDialog(
                    context: context,
                    store: widget.store,
                    pool: widget.pool,
                    onRenamed: () => setState(() {}),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Rename'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                )
              : null,
        ),
        _PaymentNotice(),
        _Tabs(
          selected: _tab,
          onChanged: (value) => setState(() => _tab = value),
        ),
        if (_isLoading)
          const DhukutiSection(
            title: 'Loading tracker',
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          DhukutiSection(
            title: 'Community Savings API unavailable',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_error!, style: AppTextStyles.bodySecondary),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _loadDashboard,
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('Retry'),
                ),
              ],
            ),
          )
        else
          switch (_tab) {
            _TrackerTab.dashboard => _DashboardView(
              groupName: _communityGroup.name,
              currentMonth: _monthLabel(_parseDate(_month) ?? DateTime.now()),
              monthlyContribution: _communityGroup.monthlyContributionAmount,
              fundBalance: _fundBalance,
              receivedThisMonth: _receivedThisMonth,
              pendingContributions: _pendingCount,
              expensesThisMonth: _expensesThisMonth,
              totalExpectedThisMonth: _totalExpectedThisMonth,
              memberCount: _members.length,
              hasActivity:
                  _totalConfirmedContributions > 0 || _expenses.isNotEmpty,
              isAdmin: isAdmin,
              onConfirmContribution: () => _showAdminConfirmSheet(),
              onRecordExpense: () => _showRecordExpenseSheet(),
              onViewHistory: () => setState(() => _tab = _TrackerTab.history),
              onManageMembers: () =>
                  setState(() => _tab = _TrackerTab.monthlyTracker),
              onHavePaid: () => _showMemberPaidSheet(),
              onViewStatus: () =>
                  setState(() => _tab = _TrackerTab.monthlyTracker),
            ),
            _TrackerTab.monthlyTracker => _MonthlyTrackerView(
              contributions: _contributions,
              isAdmin: isAdmin,
              currentUserId: widget.store.currentUserId,
              onConfirm: _showAdminConfirmSheet,
              onEdit: _showAdminConfirmSheet,
              onWaive: _waiveContribution,
              onHavePaid: _showMemberPaidSheet,
            ),
            _TrackerTab.history => _HistoryView(
              selected: _ledgerTab,
              onChanged: (value) => setState(() => _ledgerTab = value),
              ledger: _filteredLedger,
            ),
          },
      ],
    );
  }

  List<_LedgerRecord> get _filteredLedger {
    return switch (_ledgerTab) {
      _LedgerTab.all => _ledger,
      _LedgerTab.contributions =>
        _ledger
            .where((item) => item.type == _LedgerItemType.contribution)
            .toList(),
      _LedgerTab.expenses =>
        _ledger.where((item) => item.type == _LedgerItemType.expense).toList(),
    };
  }

  Future<void> _showMemberPaidSheet([_ContributionRecord? record]) async {
    final target =
        record ??
        _contributions.firstWhere(
          (item) => item.memberId == widget.store.currentUserId,
          orElse: () => _contributions.first,
        );
    final submitted = await showModalBottomSheet<_ContributionRecord>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          _MemberPaidSheet(record: target, month: _monthLabel(DateTime.now())),
    );
    if (submitted == null) {
      return;
    }
    await _api.submitContribution(
      groupId: widget.pool.id,
      contributionId: target.id,
      amountPaid: submitted.submittedAmount,
      paymentMethod: submitted.paymentMethod,
      note: submitted.note,
      referenceNumber: submitted.referenceNumber,
      accessToken: await _accessToken(),
    );
    await _loadDashboard();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Your payment note has been submitted. The fund balance will update after the admin confirms the money was received.',
        ),
      ),
    );
  }

  Future<void> _showAdminConfirmSheet([_ContributionRecord? record]) async {
    final pending = _contributions
        .where((item) => item.status != _ContributionUiStatus.confirmedReceived)
        .toList();
    final selected =
        record ?? (pending.isEmpty ? _contributions.first : pending.first);
    final confirmed = await showModalBottomSheet<_ContributionRecord>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AdminConfirmSheet(
        records: _contributions,
        selected: selected,
        month: _monthLabel(DateTime.now()),
        adminName: widget.store.nameOf(widget.store.currentUserId),
      ),
    );
    if (confirmed == null) {
      return;
    }
    await _api.confirmContribution(
      groupId: widget.pool.id,
      contributionId: confirmed.id,
      amountReceived: confirmed.receivedAmount,
      paymentMethod: confirmed.paymentMethod,
      dateReceived: _dateInput(confirmed.confirmedAt ?? DateTime.now()),
      confirmedBy: confirmed.confirmedBy,
      note: confirmed.note,
      referenceNumber: confirmed.referenceNumber,
      accessToken: await _accessToken(),
    );
    await _loadDashboard();
  }

  Future<void> _showRecordExpenseSheet() async {
    final expense = await showModalBottomSheet<_CommunityExpense>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _RecordExpenseSheet(
        availableBalance: _fundBalance,
        recordedBy: widget.store.nameOf(widget.store.currentUserId),
      ),
    );
    if (expense == null) {
      return;
    }
    await _api.recordExpense(
      groupId: widget.pool.id,
      title: expense.title,
      amountSpent: expense.amount,
      expenseDate: _dateInput(expense.expenseDate),
      category: expense.category,
      recordedBy: expense.recordedBy,
      description: expense.description,
      receiptReference: expense.receiptReference,
      accessToken: await _accessToken(),
    );
    await _loadDashboard();
  }

  Future<void> _waiveContribution(_ContributionRecord record) async {
    await _api.waiveContribution(
      groupId: widget.pool.id,
      contributionId: record.id,
      accessToken: await _accessToken(),
    );
    await _loadDashboard();
  }

  Future<String> _accessToken() async {
    final token = await AuthScope.of(context).backendAccessToken();
    if (token == null || token.isEmpty) {
      throw const CommunitySavingsApiException(
        'Start the app with BACKEND_API_BASE_URL and log in again.',
      );
    }
    return token;
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView({
    required this.groupName,
    required this.currentMonth,
    required this.monthlyContribution,
    required this.fundBalance,
    required this.receivedThisMonth,
    required this.pendingContributions,
    required this.expensesThisMonth,
    required this.totalExpectedThisMonth,
    required this.memberCount,
    required this.hasActivity,
    required this.isAdmin,
    required this.onConfirmContribution,
    required this.onRecordExpense,
    required this.onViewHistory,
    required this.onManageMembers,
    required this.onHavePaid,
    required this.onViewStatus,
  });

  final String groupName;
  final String currentMonth;
  final int monthlyContribution;
  final int fundBalance;
  final int receivedThisMonth;
  final int pendingContributions;
  final int expensesThisMonth;
  final int totalExpectedThisMonth;
  final int memberCount;
  final bool hasActivity;
  final bool isAdmin;
  final VoidCallback onConfirmContribution;
  final VoidCallback onRecordExpense;
  final VoidCallback onViewHistory;
  final VoidCallback onManageMembers;
  final VoidCallback onHavePaid;
  final VoidCallback onViewStatus;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DhukutiResponsiveGrid(
          children: [
            DhukutiMetricCard(
              label: 'Group name',
              value: groupName,
              icon: Icons.groups_outlined,
              tone: DhukutiTone.info,
            ),
            DhukutiMetricCard(
              label: 'Current month',
              value: currentMonth,
              icon: Icons.calendar_month_outlined,
              tone: DhukutiTone.neutral,
            ),
            DhukutiMetricCard(
              label: 'Available fund balance',
              value: _rs(fundBalance),
              icon: Icons.account_balance_outlined,
              tone: fundBalance >= 0
                  ? DhukutiTone.success
                  : DhukutiTone.warning,
            ),
            DhukutiMetricCard(
              label: 'Monthly contribution amount',
              value: _rs(monthlyContribution),
              icon: Icons.savings_outlined,
              tone: DhukutiTone.info,
            ),
            DhukutiMetricCard(
              label: 'Received this month',
              value: _rs(receivedThisMonth),
              icon: Icons.verified_outlined,
              tone: DhukutiTone.success,
            ),
            DhukutiMetricCard(
              label: 'Pending contributions',
              value: '$pendingContributions',
              icon: Icons.pending_actions_outlined,
              tone: pendingContributions == 0
                  ? DhukutiTone.success
                  : DhukutiTone.warning,
            ),
            DhukutiMetricCard(
              label: 'Expenses this month',
              value: _rs(expensesThisMonth),
              icon: Icons.receipt_long_outlined,
              tone: DhukutiTone.neutral,
            ),
            DhukutiMetricCard(
              label: 'Total expected this month',
              value: _rs(totalExpectedThisMonth),
              icon: Icons.summarize_outlined,
              tone: DhukutiTone.info,
            ),
            DhukutiMetricCard(
              label: 'Members',
              value: '$memberCount',
              icon: Icons.groups_outlined,
              tone: DhukutiTone.neutral,
            ),
          ],
        ),
        if (!hasActivity) ...[
          const SizedBox(height: AppSpacing.lg),
          const DhukutiEmptyState(
            icon: Icons.savings_outlined,
            title: 'No contributions recorded yet',
            message: 'Start tracking this month\'s community savings.',
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (isAdmin)
          _ActionPanel(
            title: 'Admin actions',
            actions: [
              _TrackerAction(
                icon: Icons.fact_check_outlined,
                label: 'Confirm Contribution',
                onTap: onConfirmContribution,
              ),
              _TrackerAction(
                icon: Icons.add_card_outlined,
                label: 'Record Expense',
                onTap: onRecordExpense,
              ),
              _TrackerAction(
                icon: Icons.history_outlined,
                label: 'View History',
                onTap: onViewHistory,
              ),
              _TrackerAction(
                icon: Icons.manage_accounts_outlined,
                label: 'Manage Members',
                onTap: onManageMembers,
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.lg),
        _ActionPanel(
          title: 'Member actions',
          actions: [
            _TrackerAction(
              icon: Icons.upload_file_outlined,
              label: 'I Have Paid',
              onTap: onHavePaid,
            ),
            _TrackerAction(
              icon: Icons.person_search_outlined,
              label: 'View My Status',
              onTap: onViewStatus,
            ),
            _TrackerAction(
              icon: Icons.history_outlined,
              label: 'View History',
              onTap: onViewHistory,
            ),
          ],
        ),
      ],
    );
  }
}

class _MonthlyTrackerView extends StatelessWidget {
  const _MonthlyTrackerView({
    required this.contributions,
    required this.isAdmin,
    required this.currentUserId,
    required this.onConfirm,
    required this.onEdit,
    required this.onWaive,
    required this.onHavePaid,
  });

  final List<_ContributionRecord> contributions;
  final bool isAdmin;
  final String currentUserId;
  final ValueChanged<_ContributionRecord> onConfirm;
  final ValueChanged<_ContributionRecord> onEdit;
  final ValueChanged<_ContributionRecord> onWaive;
  final ValueChanged<_ContributionRecord> onHavePaid;

  @override
  Widget build(BuildContext context) {
    return DhukutiSection(
      title: 'Monthly Contribution Tracker',
      child: contributions.isEmpty
          ? const DhukutiEmptyState(
              icon: Icons.group_add_outlined,
              title: 'No members added yet',
              message: 'Add members to start tracking monthly contributions.',
            )
          : Column(
              children: [
                for (final record in contributions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _ContributionRow(
                      record: record,
                      isAdmin: isAdmin,
                      isCurrentUser: record.memberId == currentUserId,
                      onConfirm: () => onConfirm(record),
                      onEdit: () => onEdit(record),
                      onWaive: () => onWaive(record),
                      onHavePaid: () => onHavePaid(record),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ContributionRow extends StatelessWidget {
  const _ContributionRow({
    required this.record,
    required this.isAdmin,
    required this.isCurrentUser,
    required this.onConfirm,
    required this.onEdit,
    required this.onWaive,
    required this.onHavePaid,
  });

  final _ContributionRecord record;
  final bool isAdmin;
  final bool isCurrentUser;
  final VoidCallback onConfirm;
  final VoidCallback onEdit;
  final VoidCallback onWaive;
  final VoidCallback onHavePaid;

  @override
  Widget build(BuildContext context) {
    return ds.AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DhukutiAvatar(label: record.initials),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(record.memberName, style: AppTextStyles.cardTitle),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Expected ${_rs(record.expectedAmount)} • Received ${_rs(record.receivedAmount)}',
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        if (record.paymentMethod.isNotEmpty)
                          _InlineMeta(
                            icon: Icons.payments_outlined,
                            label: record.paymentMethod,
                          ),
                        if (record.submittedAt != null)
                          _InlineMeta(
                            icon: Icons.upload_file_outlined,
                            label:
                                'Submitted ${dateLabel(record.submittedAt!)}',
                          ),
                        if (record.confirmedAt != null)
                          _InlineMeta(
                            icon: Icons.verified_outlined,
                            label:
                                'Confirmed ${dateLabel(record.confirmedAt!)}',
                          ),
                      ],
                    ),
                    if (record.status == _ContributionUiStatus.submitted) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Waiting for admin confirmation',
                        style: AppTextStyles.caption.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              DhukutiStatusBadge(
                label: _statusLabel(record.status),
                tone: _statusTone(record.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              if (isAdmin) ...[
                FilledButton.tonalIcon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Confirm'),
                ),
                OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: onWaive,
                  icon: const Icon(Icons.remove_done_outlined, size: 18),
                  label: const Text('Waive'),
                ),
              ],
              OutlinedButton.icon(
                onPressed: isCurrentUser ? onHavePaid : null,
                icon: const Icon(Icons.upload_file_outlined, size: 18),
                label: const Text('I Have Paid'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({
    required this.selected,
    required this.onChanged,
    required this.ledger,
  });

  final _LedgerTab selected;
  final ValueChanged<_LedgerTab> onChanged;
  final List<_LedgerRecord> ledger;

  @override
  Widget build(BuildContext context) {
    return DhukutiSection(
      title: 'History / Ledger',
      action: SegmentedButton<_LedgerTab>(
        selected: {selected},
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: _LedgerTab.all, label: Text('All')),
          ButtonSegment(
            value: _LedgerTab.contributions,
            label: Text('Contributions'),
          ),
          ButtonSegment(value: _LedgerTab.expenses, label: Text('Expenses')),
        ],
        onSelectionChanged: (value) => onChanged(value.first),
      ),
      child: ledger.isEmpty
          ? DhukutiEmptyState(
              icon: selected == _LedgerTab.expenses
                  ? Icons.receipt_long_outlined
                  : Icons.history_outlined,
              title: switch (selected) {
                _LedgerTab.expenses => 'No expenses recorded yet',
                _ => 'No fund activity yet',
              },
              message: switch (selected) {
                _LedgerTab.expenses =>
                  'Shared expenses will appear here once recorded by an admin.',
                _ =>
                  'Confirmed contributions and recorded expenses will appear here.',
              },
            )
          : Column(
              children: [
                for (final item in ledger)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _LedgerTile(item: item),
                  ),
              ],
            ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.item});

  final _LedgerRecord item;

  @override
  Widget build(BuildContext context) {
    final isContribution = item.type == _LedgerItemType.contribution;
    final color = isContribution
        ? dhukutiToneColor(context, DhukutiTone.success)
        : Theme.of(context).colorScheme.error;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Icon(
          isContribution
              ? Icons.add_circle_outline
              : Icons.remove_circle_outline,
        ),
      ),
      title: Text(
        item.title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.subtitle),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                for (final detail in item.details)
                  _InlineMeta(icon: detail.icon, label: detail.label),
              ],
            ),
          ],
        ),
      ),
      trailing: Text(
        '${isContribution ? '+' : '-'} ${_rs(item.amount)}',
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _MemberPaidSheet extends StatefulWidget {
  const _MemberPaidSheet({required this.record, required this.month});

  final _ContributionRecord record;
  final String month;

  @override
  State<_MemberPaidSheet> createState() => _MemberPaidSheetState();
}

class _MemberPaidSheetState extends State<_MemberPaidSheet> {
  late final TextEditingController _amount;
  final _note = TextEditingController();
  final _reference = TextEditingController();
  var _method = _paymentMethods.first;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
      text: (widget.record.expectedAmount ~/ 100).toString(),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'I Have Paid',
      helper:
          'Submit a note for money paid outside the app. Submitted payments do not change the fund balance.',
      child: Column(
        children: [
          _ReadOnlyField(label: 'Month', value: widget.month),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount paid',
              prefixText: 'Rs. ',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: [
              for (final item in _paymentMethods)
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (value) => setState(() => _method = value ?? _method),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Optional admin note'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _reference,
            decoration: const InputDecoration(
              labelText: 'Optional reference number',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  widget.record.copyWith(
                    submittedAmount: parseMoneyToMinor(_amount.text),
                    paymentMethod: _method,
                    note: _note.text.trim(),
                    referenceNumber: _reference.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Submit for Admin Confirmation'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminConfirmSheet extends StatefulWidget {
  const _AdminConfirmSheet({
    required this.records,
    required this.selected,
    required this.month,
    required this.adminName,
  });

  final List<_ContributionRecord> records;
  final _ContributionRecord selected;
  final String month;
  final String adminName;

  @override
  State<_AdminConfirmSheet> createState() => _AdminConfirmSheetState();
}

class _AdminConfirmSheetState extends State<_AdminConfirmSheet> {
  late _ContributionRecord _selected;
  late final TextEditingController _amount;
  final _note = TextEditingController();
  final _reference = TextEditingController();
  var _method = _paymentMethods.first;
  var _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _amount = TextEditingController(
      text:
          ((_selected.submittedAmount > 0
                      ? _selected.submittedAmount
                      : _selected.expectedAmount) ~/
                  100)
              .toString(),
    );
    _method = _selected.paymentMethod;
    _note.text = _selected.note;
    _reference.text = _selected.referenceNumber;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Confirm Received Contribution',
      helper:
          'This only records a payment received outside the app. No money is processed by the app.',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selected.memberId,
            decoration: const InputDecoration(labelText: 'Member'),
            items: [
              for (final record in widget.records)
                DropdownMenuItem(
                  value: record.memberId,
                  child: Text(record.memberName),
                ),
            ],
            onChanged: (value) {
              final next = widget.records.firstWhere(
                (item) => item.memberId == value,
                orElse: () => _selected,
              );
              setState(() {
                _selected = next;
                _amount.text =
                    ((next.submittedAmount > 0
                                ? next.submittedAmount
                                : next.expectedAmount) ~/
                            100)
                        .toString();
                _method = next.paymentMethod;
                _note.text = next.note;
                _reference.text = next.referenceNumber;
              });
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _ReadOnlyField(label: 'Month', value: widget.month),
          _ReadOnlyField(
            label: 'Expected amount',
            value: _rs(_selected.expectedAmount),
          ),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount received',
              prefixText: 'Rs. ',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: [
              for (final item in _paymentMethods)
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (value) => setState(() => _method = value ?? _method),
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date received'),
            subtitle: Text(dateLabel(_date)),
            trailing: OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDate: _date,
                );
                if (picked != null) {
                  setState(() => _date = picked);
                }
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: const Text('Change'),
            ),
          ),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Optional note'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _reference,
            decoration: const InputDecoration(
              labelText: 'Optional reference number',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(
                  context,
                  _selected.copyWith(
                    status: _ContributionUiStatus.confirmedReceived,
                    receivedAmount: parseMoneyToMinor(_amount.text),
                    paymentMethod: _method,
                    confirmedAt: _date,
                    confirmedBy: widget.adminName,
                    note: _note.text.trim(),
                    referenceNumber: _reference.text.trim(),
                  ),
                );
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Confirm Received'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordExpenseSheet extends StatefulWidget {
  const _RecordExpenseSheet({
    required this.availableBalance,
    required this.recordedBy,
  });

  final int availableBalance;
  final String recordedBy;

  @override
  State<_RecordExpenseSheet> createState() => _RecordExpenseSheetState();
}

class _RecordExpenseSheetState extends State<_RecordExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _receipt = TextEditingController();
  var _category = _expenseCategories.first;
  var _date = DateTime.now();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _description.dispose();
    _receipt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = parseMoneyToMinor(_amount.text);
    final exceedsBalance = amount > widget.availableBalance && amount > 0;
    return _SheetScaffold(
      title: 'Record Expense',
      helper: 'Record money spent from the community fund.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Expense title'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Title required'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount spent',
                prefixText: 'Rs. ',
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) =>
                  (value ?? '').contains('-') ||
                      parseMoneyToMinor(value ?? '') <= 0
                  ? 'Amount must be greater than 0'
                  : null,
            ),
            if (exceedsBalance) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Warning: this amount exceeds the available fund balance.',
                  style: AppTextStyles.caption.copyWith(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Expense date'),
              subtitle: Text(dateLabel(_date)),
              trailing: OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    initialDate: _date,
                  );
                  if (picked != null) {
                    setState(() => _date = picked);
                  }
                },
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                label: const Text('Change'),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final item in _expenseCategories)
                  DropdownMenuItem(value: item, child: Text(item)),
              ],
              onChanged: (value) =>
                  setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: AppSpacing.md),
            _ReadOnlyField(
              label: 'Paid by / recorded by',
              value: widget.recordedBy,
            ),
            TextField(
              controller: _description,
              decoration: const InputDecoration(
                labelText: 'Optional description',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _receipt,
              decoration: const InputDecoration(
                labelText: 'Optional receipt reference',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  Navigator.pop(
                    context,
                    _CommunityExpense(
                      id: 'expense-${DateTime.now().microsecondsSinceEpoch}',
                      title: _title.text.trim(),
                      amount: parseMoneyToMinor(_amount.text),
                      expenseDate: _date,
                      category: _category,
                      recordedBy: widget.recordedBy,
                      description: _description.text.trim(),
                      receiptReference: _receipt.text.trim(),
                    ),
                  );
                },
                icon: const Icon(Icons.save_outlined),
                label: const Text('Record Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.title, required this.actions});

  final String title;
  final List<_TrackerAction> actions;

  @override
  Widget build(BuildContext context) {
    return DhukutiSection(
      title: title,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth < 560
              ? constraints.maxWidth
              : (constraints.maxWidth - AppSpacing.md) / 2;
          return Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              for (final action in actions)
                SizedBox(width: itemWidth, child: action),
            ],
          );
        },
      ),
    );
  }
}

class _TrackerAction extends StatelessWidget {
  const _TrackerAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onChanged});

  final _TrackerTab selected;
  final ValueChanged<_TrackerTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_TrackerTab>(
      selected: {selected},
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: _TrackerTab.dashboard,
          icon: Icon(Icons.dashboard_outlined),
          label: Text('Dashboard'),
        ),
        ButtonSegment(
          value: _TrackerTab.monthlyTracker,
          icon: Icon(Icons.fact_check_outlined),
          label: Text('Tracker'),
        ),
        ButtonSegment(
          value: _TrackerTab.history,
          icon: Icon(Icons.history_outlined),
          label: Text('History'),
        ),
      ],
      onSelectionChanged: (value) => onChanged(value.first),
    );
  }
}

class _PaymentNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.16)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Payments are made outside the app. The fund balance updates only after an admin confirms money was received.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({
    required this.title,
    required this.helper,
    required this.child,
  });

  final String title;
  final String helper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(helper, style: AppTextStyles.bodySecondary),
            const SizedBox(height: AppSpacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _CommunitySavingsGroup {
  const _CommunitySavingsGroup({
    required this.id,
    required this.name,
    required this.monthlyContributionAmount,
    required this.currency,
    required this.currentBalance,
  });

  factory _CommunitySavingsGroup.fromJson(
    Map<String, dynamic> json, {
    required int currentBalance,
  }) {
    return _CommunitySavingsGroup(
      id: json['id'].toString(),
      name: json['name'].toString(),
      monthlyContributionAmount: _readInt(json, 'monthlyContributionAmount'),
      currency: json['currency']?.toString() ?? 'Rs.',
      currentBalance: currentBalance,
    );
  }

  final String id;
  final String name;
  final int monthlyContributionAmount;
  final String currency;
  final int currentBalance;
}

class _CommunitySavingsMember {
  const _CommunitySavingsMember({
    required this.id,
    required this.name,
    required this.role,
    required this.avatarInitials,
  });

  factory _CommunitySavingsMember.fromJson(Map<String, dynamic> json) {
    return _CommunitySavingsMember(
      id: json['id'].toString(),
      name: json['name'].toString(),
      role: json['role']?.toString() ?? 'member',
      avatarInitials: json['avatarInitials']?.toString() ?? '?',
    );
  }

  final String id;
  final String name;
  final String role;
  final String avatarInitials;
}

class _ContributionRecord {
  _ContributionRecord({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.month,
    required this.initials,
    required this.expectedAmount,
    required this.receivedAmount,
    required this.submittedAmount,
    required this.status,
    required this.paymentMethod,
    required this.submittedAt,
    required this.confirmedAt,
    required this.confirmedBy,
    required this.note,
    required this.referenceNumber,
  });

  factory _ContributionRecord.fromJson(Map<String, dynamic> json) {
    final status = switch (json['status']?.toString()) {
      'submitted' => _ContributionUiStatus.submitted,
      'confirmed_received' => _ContributionUiStatus.confirmedReceived,
      'waived' => _ContributionUiStatus.waived,
      _ => _ContributionUiStatus.pending,
    };
    return _ContributionRecord(
      id: json['id'].toString(),
      memberId: json['memberId'].toString(),
      memberName: json['memberName'].toString(),
      month: json['month']?.toString() ?? _dateInput(DateTime.now()),
      initials: _initials(json['memberName']?.toString() ?? '?'),
      expectedAmount: _readInt(json, 'expectedAmount'),
      receivedAmount: _readInt(json, 'receivedAmount'),
      submittedAmount: _readInt(json, 'submittedAmount'),
      status: status,
      paymentMethod: json['paymentMethod']?.toString() ?? '',
      submittedAt: _parseDate(json['submittedAt']?.toString()),
      confirmedAt: _parseDate(json['confirmedAt']?.toString()),
      confirmedBy: json['confirmedBy']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      referenceNumber: json['referenceNumber']?.toString() ?? '',
    );
  }

  final String id;
  final String memberId;
  final String memberName;
  final String month;
  final String initials;
  final int expectedAmount;
  int receivedAmount;
  int submittedAmount;
  _ContributionUiStatus status;
  String paymentMethod;
  DateTime? submittedAt;
  DateTime? confirmedAt;
  String confirmedBy;
  String note;
  String referenceNumber;

  _ContributionRecord copyWith({
    int? receivedAmount,
    int? submittedAmount,
    _ContributionUiStatus? status,
    String? paymentMethod,
    DateTime? submittedAt,
    DateTime? confirmedAt,
    String? confirmedBy,
    String? note,
    String? referenceNumber,
  }) {
    return _ContributionRecord(
      id: id,
      memberId: memberId,
      memberName: memberName,
      month: month,
      initials: initials,
      expectedAmount: expectedAmount,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      submittedAmount: submittedAmount ?? this.submittedAmount,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      submittedAt: submittedAt ?? this.submittedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      note: note ?? this.note,
      referenceNumber: referenceNumber ?? this.referenceNumber,
    );
  }
}

class _CommunityExpense {
  _CommunityExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.expenseDate,
    required this.category,
    required this.recordedBy,
    required this.description,
    required this.receiptReference,
  });

  factory _CommunityExpense.fromJson(Map<String, dynamic> json) {
    return _CommunityExpense(
      id: json['id'].toString(),
      title: json['title'].toString(),
      amount: _readInt(json, 'amount'),
      expenseDate:
          _parseDate(json['expenseDate']?.toString()) ?? DateTime.now(),
      category: json['category']?.toString() ?? 'Other',
      recordedBy: json['recordedBy']?.toString() ?? 'Admin',
      description: json['description']?.toString() ?? '',
      receiptReference: json['receiptReference']?.toString() ?? '',
    );
  }

  final String id;
  final String title;
  final int amount;
  final DateTime expenseDate;
  final String category;
  final String recordedBy;
  final String description;
  final String receiptReference;
}

class _LedgerRecord {
  _LedgerRecord({
    required this.sourceId,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
    required this.details,
  });

  factory _LedgerRecord.contribution(
    _ContributionRecord record,
    DateTime date,
  ) {
    return _LedgerRecord(
      sourceId: record.id,
      type: _LedgerItemType.contribution,
      title: 'Contribution confirmed',
      subtitle: record.memberName,
      amount: record.receivedAmount,
      date: date,
      details: [
        _LedgerDetail(Icons.payments_outlined, record.paymentMethod),
        _LedgerDetail(Icons.calendar_month_outlined, record.month),
        _LedgerDetail(
          Icons.verified_outlined,
          'Confirmed ${dateLabel(record.confirmedAt ?? date)}',
        ),
        _LedgerDetail(
          Icons.admin_panel_settings_outlined,
          'Confirmed by ${record.confirmedBy.isEmpty ? 'admin' : record.confirmedBy}',
        ),
      ],
    );
  }

  factory _LedgerRecord.expense(_CommunityExpense expense) {
    return _LedgerRecord(
      sourceId: expense.id,
      type: _LedgerItemType.expense,
      title: expense.title,
      subtitle: expense.category,
      amount: expense.amount,
      date: expense.expenseDate,
      details: [
        _LedgerDetail(
          Icons.calendar_today_outlined,
          dateLabel(expense.expenseDate),
        ),
        _LedgerDetail(
          Icons.person_outline,
          'Recorded by ${expense.recordedBy}',
        ),
      ],
    );
  }

  final String sourceId;
  final _LedgerItemType type;
  final String title;
  final String subtitle;
  final int amount;
  final DateTime date;
  final List<_LedgerDetail> details;
}

class _LedgerDetail {
  const _LedgerDetail(this.icon, this.label);

  final IconData icon;
  final String label;
}

String _statusLabel(_ContributionUiStatus status) {
  return switch (status) {
    _ContributionUiStatus.pending => 'Pending',
    _ContributionUiStatus.submitted => 'Submitted',
    _ContributionUiStatus.confirmedReceived => 'Confirmed Received',
    _ContributionUiStatus.waived => 'Waived',
  };
}

DhukutiTone _statusTone(_ContributionUiStatus status) {
  return switch (status) {
    _ContributionUiStatus.pending => DhukutiTone.neutral,
    _ContributionUiStatus.submitted => DhukutiTone.info,
    _ContributionUiStatus.confirmedReceived => DhukutiTone.success,
    _ContributionUiStatus.waived => DhukutiTone.warning,
  };
}

String _rs(int minor) => money(minor).replaceFirst('NPR', 'Rs.');

int _readInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _parseDate(String? value) {
  if (value == null || value.isEmpty || value == 'null') {
    return null;
  }
  return DateTime.tryParse(value);
}

String _dateInput(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) {
    return '?';
  }
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

String _monthLabel(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}
