import 'package:flutter/material.dart';

import '../auth/auth_controller.dart';
import '../../shared/api/backend_api.dart';
import '../../shared/design_system/app_spacing.dart';
import '../../shared/design_system/app_text_styles.dart';
import '../../src/app_state.dart';
import '../../src/finance.dart';
import '../../src/models.dart';
import 'widgets/dhukuti_status_badge.dart';
import 'widgets/dhukuti_tokens.dart';

class DhukutiCreateScreen extends StatefulWidget {
  const DhukutiCreateScreen({required this.store, super.key});

  final AppStore store;

  @override
  State<DhukutiCreateScreen> createState() => _DhukutiCreateScreenState();
}

class _DhukutiCreateScreenState extends State<DhukutiCreateScreen> {
  final _poolName = TextEditingController(text: 'New Community Fund');
  final _amount = TextEditingController(text: '3000');
  var _frequency = 'Monthly';
  String? _groupId;
  final _selectedMembers = <String>{};
  var _agreementAccepted = false;

  @override
  void initState() {
    super.initState();
    final groups = widget.store.visibleDhukutiGroups;
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
    final groups = store.visibleDhukutiGroups;
    final connections = store.activeConnectionUsers();
    final memberCount = _selectedMembers.length + 1;
    final amount = parseMoneyToMinor(_amount.text);
    final expected = amount * memberCount;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Community Savings Tracker')),
      body: DhukutiScrollView(
        children: [
          DhukutiHeader(
            title: 'Create Community Savings Tracker',
            subtitle:
                'Set up a trusted contribution tracker with in-app eSewa payments.',
          ),
          DhukutiSection(
            title: 'Tracker Details',
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
            action: DhukutiStatusBadge(
              label: '$memberCount people',
              tone: DhukutiTone.success,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are included automatically. Select members whose monthly contributions will be tracked.',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _DhukutiMemberSelectorCard(
                      user: store.currentUser,
                      selected: true,
                      enabled: false,
                      onTap: () {},
                    ),
                    for (final user in connections)
                      _DhukutiMemberSelectorCard(
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
          DhukutiSection(
            title: 'Review',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReviewRow(label: 'Contribution amount', value: money(amount)),
                _ReviewRow(label: 'Number of members', value: '$memberCount'),
                _ReviewRow(
                  label: 'Expected monthly total',
                  value: money(expected),
                ),
                const _ReviewRow(label: 'Start date', value: 'Jun 15, 2026'),
                const _ReviewRow(
                  label: 'Balance rule',
                  value: 'Only confirmed received contributions update balance',
                ),
                _ReviewRow(
                  label: 'Admin',
                  value: store.currentUser.displayName,
                ),
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
                    'Community Savings Tracker records contributions paid through eSewa and keeps the fund ledger transparent.',
                  ),
                ),
                const SizedBox(height: 14),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _agreementAccepted,
                  title: const Text(
                    'I understand admin confirmation is required before the fund balance updates.',
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
                      ? () {
                          _createPool(context);
                        }
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

  Future<void> _createPool(BuildContext context) async {
    final api = BackendApi();
    try {
      if (!api.isConfigured) {
        throw const BackendApiException(
          'Backend API is required for signed-in actions.',
        );
      }
      final token = await AuthScope.read(context).backendAccessToken();
      if (token == null) {
        throw const BackendApiException('Sign in again to continue.');
      }
      final name = _poolName.text.trim().isEmpty
          ? 'New Community Fund'
          : _poolName.text.trim();
      await api.createCommunitySavingsGroup(
        accessToken: token,
        group: {
          'groupId': _groupId!,
          'name': name,
          'monthlyContributionAmount': parseMoneyToMinor(_amount.text),
          'currency': 'Rs.',
          'frequency': _frequency.toLowerCase(),
        },
      );
      final snapshot = await api.appBootstrap(accessToken: token);
      if (!context.mounted) {
        return;
      }
      widget.store.loadBackendSnapshot(snapshot);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$name invites sent.')));
      Navigator.pop(context);
    } on BackendApiException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }
}

class _DhukutiMemberSelectorCard extends StatelessWidget {
  const _DhukutiMemberSelectorCard({
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
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 260),
      child: Material(
        color: selected ? scheme.primary : scheme.surface,
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
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                DhukutiAvatar(label: user.avatar, small: true),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    user.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.check_circle, size: 18, color: scheme.onPrimary),
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
