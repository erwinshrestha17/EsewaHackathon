import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';
import '../design_system/app_components.dart' as ds;
import '../design_system/app_spacing.dart';
import '../design_system/app_text_styles.dart';
import '../../src/finance.dart';
import 'transaction_status.dart';

class TransactionFailureScreen extends StatelessWidget {
  const TransactionFailureScreen({
    required this.result,
    required this.onRetry,
    super.key,
  });

  final TransactionResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Failed')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            const SizedBox(height: 28),
            Container(
              width: 86,
              height: 86,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: const Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 54,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Transaction Failed',
              textAlign: TextAlign.center,
              style: AppTextStyles.screenTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              result.reason?.trim().isNotEmpty == true
                  ? result.reason!
                  : result.message.trim().isNotEmpty
                  ? result.message
                  : 'Payment could not be completed. Please try again.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.xxl),
            ds.AppCard(
              child: Column(
                children: [
                  _Line(label: 'Amount', value: money(result.amount)),
                  _Line(label: 'Reference', value: result.transactionReference),
                  _Line(label: 'Status', value: result.status.label),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, result),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
