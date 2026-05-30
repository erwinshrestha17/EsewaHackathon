import 'dart:async';

import 'package:flutter/material.dart';

import '../design_system/app_colors.dart';
import '../design_system/app_components.dart' as ds;
import '../design_system/app_spacing.dart';
import '../design_system/app_text_styles.dart';
import '../../src/finance.dart';
import 'transaction_confirmation_controller.dart';
import 'transaction_confirmation_data.dart';
import 'transaction_failure_screen.dart';
import 'transaction_item_summary.dart';
import 'transaction_participant_row.dart';
import 'transaction_receipt_card.dart';
import 'transaction_status.dart';
import 'transaction_success_screen.dart';
import 'transaction_type.dart';

class TransactionConfirmationScreen extends StatefulWidget {
  const TransactionConfirmationScreen({
    required this.data,
    required this.onConfirm,
    super.key,
  });

  final TransactionConfirmationData data;
  final TransactionConfirmCallback onConfirm;

  @override
  State<TransactionConfirmationScreen> createState() =>
      _TransactionConfirmationScreenState();
}

class _TransactionConfirmationScreenState
    extends State<TransactionConfirmationScreen> {
  var _processing = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final validationError = data.validationError;
    final canConfirm = validationError == null && !_processing;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Transaction')),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (validationError != null) ...[
              _InlineNotice(
                icon: Icons.info_outline,
                message: validationError,
                color: scheme.error,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canConfirm ? _confirm : null,
                icon: _processing
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _processing
                      ? 'Confirming payment...'
                      : data.confirmationButtonText,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _processing ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _HeroSummary(data: data),
            const SizedBox(height: AppSpacing.lg),
            TransactionReceiptCard(data: data),
            if (data.warningMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              _InlineNotice(
                icon: Icons.warning_amber_outlined,
                message: data.warningMessage!,
                color: const Color(0xFFB56A12),
              ),
            ],
            if (data.complianceNote != null) ...[
              const SizedBox(height: AppSpacing.md),
              _InlineNotice(
                icon: Icons.verified_user_outlined,
                message: data.complianceNote!,
                color: scheme.primary,
              ),
            ],
            if (data.participants.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              _SectionTitle(
                title: data.transactionType == TransactionType.adjustment
                    ? 'Adjustment entries'
                    : 'Participants',
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final participant in data.participants)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TransactionParticipantRow(participant: participant),
                ),
            ],
            if ((data.items ?? const <TransactionItem>[]).isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              TransactionItemSummary(items: data.items!),
            ],
            const SizedBox(height: 118),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm() async {
    if (_processing) {
      return;
    }
    setState(() => _processing = true);
    final result = await TransactionConfirmationController.submit(
      widget.data,
      widget.onConfirm,
    );
    if (!mounted) {
      return;
    }
    setState(() => _processing = false);
    if (result.isSuccess) {
      final popped = await Navigator.of(context).push<TransactionResult>(
        MaterialPageRoute<TransactionResult>(
          builder: (_) => TransactionSuccessScreen(result: result),
        ),
      );
      if (mounted) {
        Navigator.pop(context, popped ?? result);
      }
      return;
    }
    await Navigator.of(context).push<TransactionResult>(
      MaterialPageRoute<TransactionResult>(
        builder: (_) => TransactionFailureScreen(
          result: result,
          onRetry: () {
            Navigator.pop(context);
            unawaited(_confirm());
          },
        ),
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.data});

  final TransactionConfirmationData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = _iconFor(data.transactionType);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title.isEmpty
                          ? data.transactionType.confirmationTitle
                          : data.title,
                      style: AppTextStyles.sectionTitle,
                    ),
                    Text(data.subtitle, style: AppTextStyles.bodySecondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            money(data.amount),
            style: AppTextStyles.largeScreenTitle.copyWith(
              color: AppColors.darkGreen,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusBadge(
                label: data.isLocalPayment ? 'Payment Ready' : 'Payment',
                icon: Icons.account_balance_wallet_outlined,
              ),
              _StatusBadge(
                label: data.statusLabel ?? 'Draft',
                icon: Icons.pending_actions_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ds.StatusBadge(
      label: label,
      icon: icon,
      tone: ds.AppStatusTone.info,
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.sectionTitle);
  }
}

IconData _iconFor(TransactionType type) {
  return switch (type) {
    TransactionType.groupExpense => Icons.receipt_long_outlined,
    TransactionType.settlement => Icons.payments_outlined,
    TransactionType.gift => Icons.card_giftcard_outlined,
    TransactionType.dhukutiContribution => Icons.savings_outlined,
    TransactionType.dhukutiPayout => Icons.account_balance_wallet_outlined,
    TransactionType.giftPoolContribution => Icons.redeem_outlined,
    TransactionType.adjustment => Icons.tune,
    TransactionType.manualItemExpense => Icons.edit_note_outlined,
    TransactionType.ocrExpense => Icons.document_scanner_outlined,
  };
}
