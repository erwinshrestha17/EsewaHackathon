import 'package:flutter/material.dart';

import '../../../shared/design_system/app_colors.dart';
import '../../../shared/design_system/app_components.dart' as ds;
import '../../../shared/design_system/app_spacing.dart';
import '../../../shared/design_system/app_text_styles.dart';
import '../../../src/models.dart';

enum SavingsCircleTone { neutral, success, warning, info, danger }

const savingsCirclePrimary = AppColors.primaryGreen;
const savingsCircleFestival = AppColors.warning;
const savingsCircleInk = AppColors.textPrimary;

Color savingsCircleToneColor(BuildContext context, SavingsCircleTone tone) {
  return switch (tone) {
    SavingsCircleTone.success => AppColors.success,
    SavingsCircleTone.warning => AppColors.warning,
    SavingsCircleTone.info => AppColors.info,
    SavingsCircleTone.danger => AppColors.error,
    SavingsCircleTone.neutral => AppColors.textSecondary,
  };
}

String savingsCircleEnumLabel(Object value) {
  final label = value.toString().split('.').last;
  final buffer = StringBuffer();
  for (var i = 0; i < label.length; i++) {
    final char = label[i];
    if (i > 0 && char.toUpperCase() == char && char.toLowerCase() != char) {
      buffer.write(' ');
    }
    buffer.write(i == 0 ? char.toUpperCase() : char);
  }
  return buffer.toString();
}

SavingsCircleTone toneForPoolStatus(String status) {
  return switch (status) {
    'Active' => SavingsCircleTone.success,
    'Upcoming' => SavingsCircleTone.info,
    'At Risk' => SavingsCircleTone.warning,
    'Completed' => SavingsCircleTone.neutral,
    _ => SavingsCircleTone.neutral,
  };
}

SavingsCircleTone toneForCycleStatus(SavingsCircleCycleStatus status) {
  return switch (status) {
    SavingsCircleCycleStatus.readyForPayout => SavingsCircleTone.success,
    SavingsCircleCycleStatus.paidOut ||
    SavingsCircleCycleStatus.closed => SavingsCircleTone.neutral,
    SavingsCircleCycleStatus.atRisk => SavingsCircleTone.warning,
    SavingsCircleCycleStatus.cancelled => SavingsCircleTone.danger,
    SavingsCircleCycleStatus.open => SavingsCircleTone.info,
    SavingsCircleCycleStatus.upcoming => SavingsCircleTone.neutral,
  };
}

SavingsCircleTone toneForContributionStatus(ContributionStatus status) {
  return switch (status) {
    ContributionStatus.paid => SavingsCircleTone.success,
    ContributionStatus.late ||
    ContributionStatus.missed ||
    ContributionStatus.failed ||
    ContributionStatus.failedReview => SavingsCircleTone.warning,
    ContributionStatus.cancelled ||
    ContributionStatus.expired => SavingsCircleTone.danger,
    ContributionStatus.due ||
    ContributionStatus.pending => SavingsCircleTone.neutral,
  };
}

class SavingsCircleSection extends StatelessWidget {
  const SavingsCircleSection({
    required this.title,
    required this.child,
    this.action,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ds.AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(title, style: AppTextStyles.sectionTitle)),
              ?action,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class SavingsCircleScrollView extends StatelessWidget {
  const SavingsCircleScrollView({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.xl),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
      itemBuilder: (context, index) => children[index],
    );
  }
}

class SavingsCircleHeader extends StatelessWidget {
  const SavingsCircleHeader({
    required this.title,
    required this.subtitle,
    this.action,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final titleBlock = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.lightGreen,
              foregroundColor: AppColors.darkGreen,
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.screenTitle),
                  const SizedBox(height: AppSpacing.xs),
                  Text(subtitle, style: AppTextStyles.bodySecondary),
                ],
              ),
            ),
          ],
        );
        if (action == null) {
          return titleBlock;
        }
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleBlock,
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: AppSpacing.lg),
            action!,
          ],
        );
      },
    );
  }
}

class SavingsCircleEmptyState extends StatelessWidget {
  const SavingsCircleEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.secondaryAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(icon, size: 34, color: AppColors.darkGreen),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              if (action != null || secondaryAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [?action, ?secondaryAction],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SavingsCircleAvatar extends StatelessWidget {
  const SavingsCircleAvatar({
    required this.label,
    this.small = false,
    super.key,
  });

  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: small ? 14 : null,
      backgroundColor: AppColors.lightGreen,
      foregroundColor: AppColors.darkGreen,
      child: Text(
        label,
        style: TextStyle(
          fontSize: small ? 11 : null,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class SavingsCircleMetricCard extends StatelessWidget {
  const SavingsCircleMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    this.helper,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final SavingsCircleTone tone;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final color = savingsCircleToneColor(context, tone);
    return ds.AppCard(
      padding: const EdgeInsets.all(14),
      tone: _toDesignTone(tone),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.13),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                Text(value, style: AppTextStyles.sectionTitle),
                if (helper != null)
                  Text(helper!, style: AppTextStyles.bodySecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SavingsCircleResponsiveGrid extends StatelessWidget {
  const SavingsCircleResponsiveGrid({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1060
            ? 4
            : constraints.maxWidth >= 680
            ? 2
            : 1;
        final width =
            (constraints.maxWidth - ((columns - 1) * AppSpacing.md)) / columns;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final child in children)
              SizedBox(
                width: width.clamp(240, constraints.maxWidth).toDouble(),
                child: child,
              ),
          ],
        );
      },
    );
  }
}

ds.AppStatusTone _toDesignTone(SavingsCircleTone tone) {
  return switch (tone) {
    SavingsCircleTone.success => ds.AppStatusTone.success,
    SavingsCircleTone.warning => ds.AppStatusTone.warning,
    SavingsCircleTone.info => ds.AppStatusTone.info,
    SavingsCircleTone.danger => ds.AppStatusTone.danger,
    SavingsCircleTone.neutral => ds.AppStatusTone.neutral,
  };
}
