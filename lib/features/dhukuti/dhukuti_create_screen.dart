import 'package:flutter/material.dart';

import '../../src/app_state.dart';
import '../../src/finance.dart';
import 'widgets/dhukuti_tokens.dart';

class DhukutiCreateScreen extends StatefulWidget {
  const DhukutiCreateScreen({required this.store, super.key});

  final AppStore store;

  @override
  State<DhukutiCreateScreen> createState() => _DhukutiCreateScreenState();
}

class _DhukutiCreateScreenState extends State<DhukutiCreateScreen> {
  final _poolName = TextEditingController(text: 'New Digital Dhukuti');
  final _amount = TextEditingController(text: '3000');
  var _frequency = 'Monthly';
  var _payoutOrder = 'Manual order';
  String? _groupId;
  final _selectedMembers = <String>{};

  @override
  void initState() {
    super.initState();
    final groups = widget.store.visibleGroups;
    _groupId = groups.isEmpty ? null : groups.first.id;
    _selectedMembers.addAll(
      widget.store.activeConnectionUsers().take(4).map((user) => user.id),
    );
  }

  @override
  void dispose() {
    _poolName.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final groups = store.visibleGroups;
    final connections = store.activeConnectionUsers();
    final memberCount = _selectedMembers.length + 1;
    final amount = parseMoneyToMinor(_amount.text);
    final expected = amount * memberCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Dhukuti Pool')),
      body: DhukutiScrollView(
        children: [
          DhukutiHeader(
            title: 'Create Dhukuti Pool',
            subtitle: 'Set up a trusted contribution circle.',
          ),
          DhukutiSection(
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
                InputDatePickerFormField(
                  firstDate: DateTime(2026, 5, 29),
                  lastDate: DateTime(2027, 12, 31),
                  initialDate: DateTime(2026, 6, 15),
                  fieldLabelText: 'Start date',
                ),
              ],
            ),
          ),
          DhukutiSection(
            title: 'Members',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final user in connections)
                  FilterChip(
                    selected: _selectedMembers.contains(user.id),
                    avatar: DhukutiAvatar(label: user.avatar, small: true),
                    label: Text(user.displayName),
                    onSelected: (selected) {
                      setState(() {
                        selected
                            ? _selectedMembers.add(user.id)
                            : _selectedMembers.remove(user.id);
                      });
                    },
                  ),
              ],
            ),
          ),
          DhukutiSection(
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
          DhukutiSection(
            title: 'Review',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReviewRow(label: 'Contribution amount', value: money(amount)),
                _ReviewRow(label: 'Number of members', value: '$memberCount'),
                _ReviewRow(
                  label: 'Expected payout per cycle',
                  value: money(expected),
                ),
                _ReviewRow(label: 'Total cycles', value: '$memberCount'),
                const _ReviewRow(label: 'Start date', value: 'Jun 15, 2026'),
                _ReviewRow(label: 'Payout order', value: _payoutOrder),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dhukutiFestival.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: dhukutiFestival.withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Text(
                    'Digital Dhukuti is a contribution schedule and transparent ledger. It does not provide credit, interest, investment return, or guaranteed payout.',
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _showPhase2Message(context),
                  icon: const Icon(Icons.lock_clock_outlined),
                  label: const Text('Create Dhukuti Pool'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPhase2Message(BuildContext context) {
    return showModalBottomSheet<void>(
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
                  'Coming Soon / Phase 2',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pool creation is not connected yet. Existing pools show the transparent schedule and ledger flow.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Got it'),
                ),
              ],
            ),
          ),
        );
      },
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
