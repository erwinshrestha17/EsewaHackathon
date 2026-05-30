import 'package:flutter/material.dart';

import '../../shared/design_system/app_colors.dart';
import '../../shared/design_system/app_spacing.dart';
import '../../shared/design_system/app_text_styles.dart';
import '../../src/app_state.dart';
import '../../src/finance.dart';
import '../../src/models.dart';
import 'widgets/savings_circle_status_badge.dart';
import 'widgets/savings_circle_tokens.dart';

class SavingsCircleCreateScreen extends StatefulWidget {
  const SavingsCircleCreateScreen({required this.store, super.key});

  final AppStore store;

  @override
  State<SavingsCircleCreateScreen> createState() =>
      _SavingsCircleCreateScreenState();
}

class _SavingsCircleCreateScreenState extends State<SavingsCircleCreateScreen> {
  final _poolName = TextEditingController(text: 'New Savings Circle');
  final _amount = TextEditingController(text: '3000');
  final _serviceFee = TextEditingController(text: '50');
  var _frequency = 'Monthly';
  var _payoutOrder = 'Manual order';
  String? _groupId;
  final _selectedMembers = <String>{};
  var _agreementAccepted = false;

  @override
  void initState() {
    super.initState();
    final groups = widget.store.visibleSavingsCircleGroups;
    _groupId = groups.isEmpty ? null : groups.first.id;
    _selectedMembers.addAll(
      widget.store.activeConnectionUsers().take(4).map((user) => user.id),
    );
  }

  @override
  void dispose() {
    _poolName.dispose();
    _amount.dispose();
    _serviceFee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final groups = store.visibleSavingsCircleGroups;
    final connections = store.activeConnectionUsers();
    final memberCount = _selectedMembers.length + 1;
    final amount = parseMoneyToMinor(_amount.text);
    final serviceFee = parseMoneyToMinor(_serviceFee.text);
    final expected = amount * memberCount;
    final netPayout = expected - serviceFee;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Savings Circle Pool')),
      body: SavingsCircleScrollView(
        children: [
          SavingsCircleHeader(
            title: 'Create Savings Circle Pool',
            subtitle: 'Set up a trusted contribution circle.',
          ),
          SavingsCircleSection(
            title: 'Pool Details',
            child: Column(
              children: [
                TextField(
                  controller: _poolName,
                  decoration: const InputDecoration(labelText: 'Pool name'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _groupId,
                  decoration: const InputDecoration(labelText: 'Group'),
                  items: [
                    for (final group in groups)
                      DropdownMenuItem(
                        value: group.id,
                        child: Text(group.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _groupId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Contribution amount',
                    prefixText: 'NPR ',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: const [
                    DropdownMenuItem(value: 'Weekly', child: Text('Weekly')),
                    DropdownMenuItem(value: 'Monthly', child: Text('Monthly')),
                    DropdownMenuItem(value: 'Custom', child: Text('Custom')),
                  ],
                  onChanged: (value) =>
                      setState(() => _frequency = value ?? _frequency),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _serviceFee,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Service fee per payout',
                    prefixText: 'NPR ',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                InputDatePickerFormField(
                  firstDate: DateTime(2026, 5, 29),
                  lastDate: DateTime(2027, 12, 31),
                  initialDate: DateTime(2026, 6, 15),
                  fieldLabelText: 'Start date',
                ),
              ],
            ),
          ),
          SavingsCircleSection(
            title: 'Members',
            action: SavingsCircleStatusBadge(
              label: '$memberCount people',
              tone: SavingsCircleTone.success,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are included automatically. Select members who must accept the Savings Circle schedule.',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _SavingsCircleMemberSelectorCard(
                      user: store.currentUser,
                      selected: true,
                      enabled: false,
                      onTap: () {},
                    ),
                    for (final user in connections)
                      _SavingsCircleMemberSelectorCard(
                        user: user,
                        selected: _selectedMembers.contains(user.id),
                        onTap: () {
                          setState(() {
                            _selectedMembers.contains(user.id)
                                ? _selectedMembers.remove(user.id)
                                : _selectedMembers.add(user.id);
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          SavingsCircleSection(
            title: 'Payout Order',
            child: SegmentedButton<String>(
              selected: {_payoutOrder},
              onSelectionChanged: (value) =>
                  setState(() => _payoutOrder = value.first),
              segments: const [
                ButtonSegment(
                  value: 'Manual order',
                  label: Text('Manual'),
                  icon: Icon(Icons.drag_indicator),
                ),
                ButtonSegment(
                  value: 'Random order',
                  label: Text('Random'),
                  icon: Icon(Icons.shuffle),
                ),
                ButtonSegment(
                  value: 'Organizer first',
                  label: Text('Organizer'),
                  icon: Icon(Icons.workspace_premium_outlined),
                ),
              ],
            ),
          ),
          SavingsCircleSection(
            title: 'Review',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReviewRow(label: 'Contribution amount', value: money(amount)),
                _ReviewRow(label: 'Number of members', value: '$memberCount'),
                _ReviewRow(label: 'Gross pot', value: money(expected)),
                _ReviewRow(label: 'Service fee', value: money(serviceFee)),
                _ReviewRow(
                  label: 'Net payout per cycle',
                  value: money(netPayout),
                ),
                _ReviewRow(label: 'Total cycles', value: '$memberCount'),
                const _ReviewRow(label: 'Start date', value: 'Jun 15, 2026'),
                _ReviewRow(label: 'Payout order', value: _payoutOrder),
                const _ReviewRow(
                  label: 'Late contribution rule',
                  value: 'Marked at risk after due date',
                ),
                const _ReviewRow(
                  label: 'Exit rule',
                  value: 'Member review after contribution or payout',
                ),
                _ReviewRow(
                  label: 'Admin',
                  value: store.currentUser.displayName,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: savingsCircleFestival.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: savingsCircleFestival.withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Text(
                    'Savings Circle is a contribution schedule and transparent ledger. It does not provide credit, interest, investment return, or guaranteed payout.',
                  ),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _agreementAccepted,
                  title: const Text(
                    'I understand the contribution and payout schedule.',
                  ),
                  onChanged: (value) =>
                      setState(() => _agreementAccepted = value ?? false),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed:
                      _agreementAccepted &&
                          _groupId != null &&
                          amount > 0 &&
                          memberCount > 1
                      ? () => _createPool(context)
                      : null,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send Invites'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _createPool(BuildContext context) {
    final id = widget.store.createSavingsCirclePool(
      groupId: _groupId!,
      name: _poolName.text.trim().isEmpty
          ? 'New Savings Circle'
          : _poolName.text.trim(),
      contributionAmountMinor: parseMoneyToMinor(_amount.text),
      frequency: _frequency,
      startDate: DateTime(2026, 6, 15),
      memberIds: _selectedMembers.toList(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.store.poolById(id).name} invites sent.'),
      ),
    );
    Navigator.pop(context);
  }
}

class _SavingsCircleMemberSelectorCard extends StatelessWidget {
  const _SavingsCircleMemberSelectorCard({
    required this.user,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final AppUser user;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 260),
      child: Material(
        color: selected ? AppColors.primaryGreen : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        elevation: selected ? 2 : 0,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? AppColors.primaryGreen : AppColors.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                SavingsCircleAvatar(label: user.avatar, small: true),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    user.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.check_circle, size: 18, color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
