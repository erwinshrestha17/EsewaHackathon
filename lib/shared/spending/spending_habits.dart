import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../src/finance.dart';
import '../../src/models.dart';
import '../design_system/app_components.dart' as ds;
import '../design_system/app_spacing.dart';
import '../design_system/app_text_styles.dart';
import '../localization/app_localizations.dart';

enum SpendingInsightScope { personal, group }

enum SpendingPeriod { daily, weekly, monthly }

class SpendingBucket {
  const SpendingBucket({required this.label, required this.amountMinor});

  final String label;
  final int amountMinor;
}

class SpendingHabitsPanel extends StatefulWidget {
  const SpendingHabitsPanel({
    required this.title,
    required this.expenses,
    required this.userId,
    required this.scope,
    this.subtitle,
    this.groupId,
    this.framed = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Iterable<Expense> expenses;
  final String userId;
  final String? groupId;
  final SpendingInsightScope scope;
  final bool framed;

  @override
  State<SpendingHabitsPanel> createState() => _SpendingHabitsPanelState();
}

class _SpendingHabitsPanelState extends State<SpendingHabitsPanel> {
  var _period = SpendingPeriod.daily;

  @override
  Widget build(BuildContext context) {
    final buckets = _bucketsFor(widget.expenses, _period);
    final total = buckets.fold<int>(
      0,
      (sum, bucket) => sum + bucket.amountMinor,
    );
    final activeBuckets = buckets.where((bucket) => bucket.amountMinor > 0);
    final average = activeBuckets.isEmpty ? 0 : total ~/ activeBuckets.length;
    final peak = buckets.fold<SpendingBucket?>(
      null,
      (best, bucket) =>
          best == null || bucket.amountMinor > best.amountMinor ? bucket : best,
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: AppTextStyles.sectionTitle),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle!,
                      style: AppTextStyles.bodySecondary.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<SpendingPeriod>(
                segments: [
                  for (final period in SpendingPeriod.values)
                    ButtonSegment(
                      value: period,
                      label: Text(context.t(period.label)),
                    ),
                ],
                selected: {_period},
                onSelectionChanged: (value) =>
                    setState(() => _period = value.first),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _SpendingMetrics(
          total: total,
          average: average,
          peakLabel: peak == null || peak.amountMinor == 0 ? '-' : peak.label,
        ),
        const SizedBox(height: AppSpacing.md),
        _SpendingBarChart(buckets: buckets),
      ],
    );

    if (!widget.framed) {
      return content;
    }
    return ds.AppCard(child: content);
  }

  List<SpendingBucket> _bucketsFor(
    Iterable<Expense> source,
    SpendingPeriod period,
  ) {
    final entries = source
        .where((expense) => expense.status == ExpenseStatus.active)
        .where(
          (expense) =>
              widget.groupId == null || expense.groupId == widget.groupId,
        )
        .map(
          (expense) => (
            date: expense.expenseDate,
            amount: widget.scope == SpendingInsightScope.group
                ? expense.totalMinor
                : _shareForUser(expense, widget.userId),
          ),
        )
        .where((entry) => entry.amount > 0)
        .toList();

    final anchor = entries.isEmpty
        ? DateTime.now()
        : entries
              .map((entry) => entry.date)
              .reduce((a, b) => a.isAfter(b) ? a : b);

    return switch (period) {
      SpendingPeriod.daily => _dailyBuckets(entries, anchor),
      SpendingPeriod.weekly => _weeklyBuckets(entries, anchor),
      SpendingPeriod.monthly => _monthlyBuckets(entries, anchor),
    };
  }

  List<SpendingBucket> _dailyBuckets(
    List<({DateTime date, int amount})> entries,
    DateTime anchor,
  ) {
    final days = [
      for (var offset = 6; offset >= 0; offset--)
        _dayStart(anchor.subtract(Duration(days: offset))),
    ];
    return [
      for (final day in days)
        SpendingBucket(
          label: '${day.month}/${day.day}',
          amountMinor: _sumBetween(
            entries,
            day,
            day.add(const Duration(days: 1)),
          ),
        ),
    ];
  }

  List<SpendingBucket> _weeklyBuckets(
    List<({DateTime date, int amount})> entries,
    DateTime anchor,
  ) {
    final anchorWeek = _weekStart(anchor);
    final weeks = [
      for (var offset = 5; offset >= 0; offset--)
        anchorWeek.subtract(Duration(days: offset * 7)),
    ];
    return [
      for (final week in weeks)
        SpendingBucket(
          label: '${week.month}/${week.day}',
          amountMinor: _sumBetween(
            entries,
            week,
            week.add(const Duration(days: 7)),
          ),
        ),
    ];
  }

  List<SpendingBucket> _monthlyBuckets(
    List<({DateTime date, int amount})> entries,
    DateTime anchor,
  ) {
    final months = [
      for (var offset = 5; offset >= 0; offset--)
        DateTime(anchor.year, anchor.month - offset),
    ];
    return [
      for (final month in months)
        SpendingBucket(
          label: _monthLabel(month),
          amountMinor: _sumBetween(
            entries,
            month,
            DateTime(month.year, month.month + 1),
          ),
        ),
    ];
  }

  int _sumBetween(
    List<({DateTime date, int amount})> entries,
    DateTime start,
    DateTime end,
  ) {
    return entries
        .where(
          (entry) => !entry.date.isBefore(start) && entry.date.isBefore(end),
        )
        .fold<int>(0, (sum, entry) => sum + entry.amount);
  }

  int _shareForUser(Expense expense, String userId) {
    return expense.shares
        .where((share) => share.userId == userId)
        .fold<int>(0, (sum, share) => sum + share.amountMinor);
  }

  DateTime _dayStart(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _weekStart(DateTime value) {
    final day = _dayStart(value);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  String _monthLabel(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[value.month - 1];
  }
}

class _SpendingMetrics extends StatelessWidget {
  const _SpendingMetrics({
    required this.total,
    required this.average,
    required this.peakLabel,
  });

  final int total;
  final int average;
  final String peakLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _MetricPill(label: 'Total', value: shortMoney(total)),
        _MetricPill(label: 'Average', value: shortMoney(average)),
        _MetricPill(label: 'Peak', value: peakLabel),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: scheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpendingBarChart extends StatelessWidget {
  const _SpendingBarChart({required this.buckets});

  final List<SpendingBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxAmount = buckets.fold<int>(
      0,
      (best, bucket) => math.max(best, bucket.amountMinor),
    );
    if (maxAmount == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Text(
          'No spending recorded for this period.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySecondary.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final bucket in buckets)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      shortMoney(bucket.amountMinor),
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: bucket.amountMinor / maxAmount,
                          widthFactor: 1,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 8),
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      child: Text(
                        bucket.label,
                        style: AppTextStyles.caption.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

extension on SpendingPeriod {
  String get label {
    return switch (this) {
      SpendingPeriod.daily => 'Daily',
      SpendingPeriod.weekly => 'Weekly',
      SpendingPeriod.monthly => 'Monthly',
    };
  }
}
