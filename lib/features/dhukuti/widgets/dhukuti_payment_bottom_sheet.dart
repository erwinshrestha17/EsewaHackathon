import 'package:flutter/material.dart';

import '../../../src/app_state.dart';
import '../../../src/finance.dart';
import '../../../src/models.dart';
import '../../../features/settings/settings_models.dart';
import '../../../shared/transactions/transaction_confirmation_controller.dart';
import '../../../shared/transactions/transaction_confirmation_data.dart';
import '../../../shared/transactions/transaction_status.dart';
import '../../../shared/transactions/transaction_type.dart';
import 'dhukuti_tokens.dart';

Future<bool> showDhukutiPaymentBottomSheet({
  required BuildContext context,
  required AppStore store,
  required DhukutiPool pool,
  required DhukutiContribution contribution,
}) async {
  final cycle = store.dhukutiCycles.firstWhere(
    (item) => item.id == contribution.cycleId,
  );
  final result = await openTransactionConfirmation(
    context,
    TransactionConfirmationData(
      id: contribution.id,
      transactionType: TransactionType.dhukutiContribution,
      title: 'Confirm Dhukuti Contribution',
      subtitle: '${pool.name} • Cycle ${contribution.cycleNumber}',
      amount: contribution.amountMinor,
      payerName: store.nameOf(contribution.userId),
      payerAvatarUrl: store.userById(contribution.userId).avatar,
      recipientName: store.nameOf(cycle.payoutRecipientId),
      recipientAvatarUrl: store.userById(cycle.payoutRecipientId).avatar,
      poolName: pool.name,
      complianceNote: dhukutiSafetyNoteText,
      confirmationButtonText: 'Pay Contribution',
      createdAt: DateTime.now(),
      idempotencyKey: contribution.idempotencyKey,
      operationType: contribution.operationType,
      details: [
        TransactionDetail('Cycle', 'Cycle ${contribution.cycleNumber}'),
        TransactionDetail('Due date', dateLabel(contribution.dueDate)),
        TransactionDetail(
          'Current payout recipient',
          store.nameOf(cycle.payoutRecipientId),
        ),
      ],
    ),
    () async {
      store.payDhukutiContribution(contribution.id);
      return TransactionResult.success(
        title: 'Contribution Paid',
        message: 'Your Dhukuti ledger has been updated.',
        amount: contribution.amountMinor,
        transactionReference: contribution.id,
        createdAt: DateTime.now(),
      );
    },
  );
  return result?.isSuccess ?? false;
}

class _DhukutiPaymentSheet extends StatefulWidget {
  const _DhukutiPaymentSheet({
    required this.store,
    required this.pool,
    required this.contribution,
  });

  final AppStore store;
  final DhukutiPool pool;
  final DhukutiContribution contribution;

  @override
  State<_DhukutiPaymentSheet> createState() => _DhukutiPaymentSheetState();
}

class _DhukutiPaymentSheetState extends State<_DhukutiPaymentSheet> {
  var _paid = false;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, bottom + 20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _paid ? _successView(context) : _confirmView(context),
        ),
      ),
    );
  }

  Widget _confirmView(BuildContext context) {
    return Column(
      key: const ValueKey('confirm'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirm Dhukuti Contribution',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Payment confirmation is simulated. No real money movement occurs.',
        ),
        const SizedBox(height: 16),
        _PaymentRow(
          label: 'Amount',
          value: money(widget.contribution.amountMinor),
        ),
        _PaymentRow(label: 'Pool', value: widget.pool.name),
        _PaymentRow(
          label: 'Cycle',
          value: 'Cycle ${widget.contribution.cycleNumber}',
        ),
        const _PaymentRow(label: 'Payment method', value: 'eSewa Wallet'),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            widget.store.payDhukutiContribution(widget.contribution.id);
            setState(() => _paid = true);
          },
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: const Text('Pay with eSewa'),
        ),
      ],
    );
  }

  Widget _successView(BuildContext context) {
    return Column(
      key: const ValueKey('success'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: dhukutiPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.check_circle_outline,
            size: 44,
            color: dhukutiPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Contribution Paid',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Your ${money(widget.contribution.amountMinor)} contribution was recorded in the transparent ledger.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.label, required this.value});

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
