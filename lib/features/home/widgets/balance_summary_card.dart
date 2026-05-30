import 'package:flutter/material.dart';

import '../../../shared/design_system/app_colors.dart';
import '../../../shared/design_system/app_shadows.dart';
import '../../../shared/design_system/app_spacing.dart';
import '../../../shared/design_system/app_text_styles.dart';
import '../../../src/finance.dart';
import '../home_models.dart';

class BalanceSummaryCard extends StatelessWidget {
  const BalanceSummaryCard({
    required this.summary,
    required this.groupCount,
    required this.pendingCount,
    super.key,
  });

  final HomeBalanceSummary summary;
  final int groupCount;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final net = summary.netBalance;
    final title = net > 0
        ? '${money(net)} to receive'
        : net < 0
        ? '${money(net.abs())} to pay'
        : 'All settled';
    final insight = pendingCount > 0
        ? 'You have $pendingCount pending settlement${pendingCount == 1 ? '' : 's'} waiting for confirmation.'
        : net > 0
        ? 'You’re owed ${money(net)} across $groupCount group${groupCount == 1 ? '' : 's'}.'
        : net < 0
        ? 'You have ${money(net.abs())} to settle across your groups.'
        : 'All clear. No open dues right now.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryGreen, AppColors.darkGreen],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.tinted(AppColors.primaryGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Your shared balance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            title,
            semanticsLabel: 'Net shared balance: $title',
            style: AppTextStyles.largeScreenTitle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            insight,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'You owe',
                  value: money(summary.totalYouOwe),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MiniStat(
                  label: 'Owed to you',
                  value: money(summary.totalOwedToYou),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MiniStat(
                  label: 'Pending',
                  value: money(summary.pendingAmount),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
