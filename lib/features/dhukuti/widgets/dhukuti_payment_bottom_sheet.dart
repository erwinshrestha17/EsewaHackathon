import 'package:flutter/material.dart';

import '../../../shared/design_system/app_spacing.dart';
import '../../../shared/design_system/app_text_styles.dart';
import '../../../src/app_state.dart';
import '../../../src/models.dart';

const List<String> _paymentMethods = [
  'Cash',
  'Bank Transfer',
  'eSewa',
  'Khalti',
  'IME Pay',
  'Other',
];

Future<bool> showDhukutiPaymentBottomSheet({
  required BuildContext context,
  required AppStore store,
  required DhukutiPool pool,
  required DhukutiContribution contribution,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ContributionNoteSheet(
      groupName: pool.name,
      amount: contribution.amountMinor,
      monthLabel: 'Month ${contribution.cycleNumber}',
    ),
  );
  return result ?? false;
}

class _ContributionNoteSheet extends StatefulWidget {
  const _ContributionNoteSheet({
    required this.groupName,
    required this.amount,
    required this.monthLabel,
  });

  final String groupName;
  final int amount;
  final String monthLabel;

  @override
  State<_ContributionNoteSheet> createState() => _ContributionNoteSheetState();
}

class _ContributionNoteSheetState extends State<_ContributionNoteSheet> {
  late final TextEditingController _amount;
  final _note = TextEditingController();
  final _reference = TextEditingController();
  var _method = _paymentMethods.first;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: (widget.amount ~/ 100).toString());
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
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'I Have Paid',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Submit a note for a monthly contribution paid outside the app. The available fund balance updates only after admin confirmation.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.lg),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Group'),
              child: Text(
                widget.groupName,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Month'),
              child: Text(
                widget.monthLabel,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
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
                for (final method in _paymentMethods)
                  DropdownMenuItem(value: method, child: Text(method)),
              ],
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
            const SizedBox(height: AppSpacing.md),
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
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Submit for Admin Confirmation'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your payment note has been submitted. The fund balance will update after the admin confirms the money was received.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }
}
