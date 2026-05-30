import 'package:flutter/material.dart';

import '../design_system/app_components.dart' as ds;
import '../design_system/app_spacing.dart';
import '../design_system/app_text_styles.dart';
import '../../src/finance.dart';
import 'transaction_status.dart';

class TransactionSuccessScreen extends StatelessWidget {
  const TransactionSuccessScreen({required this.result, super.key});

  final TransactionResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Transaction Complete')),
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
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(
                Icons.check_circle,
                color: scheme.onPrimaryContainer,
                size: 54,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              result.title,
              textAlign: TextAlign.center,
              style: AppTextStyles.screenTitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              result.message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: AppSpacing.xxl),
            _ResultCard(result: result),
            const SizedBox(height: AppSpacing.xxl),
            FilledButton(
              onPressed: () => Navigator.pop(context, result),
              child: const Text('Done'),
            ),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: () => Navigator.pop(context, result),
              child: const Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final TransactionResult result;

  @override
  Widget build(BuildContext context) {
    return ds.AppCard(
      child: Column(
        children: [
          _Line(label: 'Amount', value: money(result.amount)),
          _Line(label: 'Reference', value: result.transactionReference),
          _Line(label: 'Date/time', value: _dateTimeLabel(result.createdAt)),
        ],
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

String _dateTimeLabel(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')} $hour:$minute';
}
