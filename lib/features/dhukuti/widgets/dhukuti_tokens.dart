import 'package:flutter/material.dart';

import '../../../shared/design_system/app_colors.dart';
import '../../../shared/design_system/app_components.dart' as ds;
import '../../../shared/design_system/app_spacing.dart';
import '../../../shared/design_system/app_text_styles.dart';
import '../../../src/models.dart';

enum DhukutiTone { neutral, success, warning, info, danger }

const dhukutiPrimary = AppColors.primaryGreen;
const dhukutiFestival = AppColors.warning;
const dhukutiInk = AppColors.textPrimary;

Color dhukutiToneColor(BuildContext context, DhukutiTone tone) {
  final scheme = Theme.of(context).colorScheme;
  return switch (tone) {
    DhukutiTone.success => AppColors.success,
    DhukutiTone.warning => AppColors.warning,
    DhukutiTone.info => AppColors.info,
    DhukutiTone.danger => scheme.error,
    DhukutiTone.neutral => scheme.onSurfaceVariant,
  };
}

String dhukutiEnumLabel(Object value) {
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

DhukutiTone toneForPoolStatus(String status) {
  return switch (status) {
    'Active' => DhukutiTone.success,
    'Upcoming' => DhukutiTone.info,
    'At Risk' => DhukutiTone.warning,
    'Completed' => DhukutiTone.neutral,
    _ => DhukutiTone.neutral,
  };
}

DhukutiTone toneForCycleStatus(DhukutiCycleStatus status) {
  return switch (status) {
    DhukutiCycleStatus.readyForPayout => DhukutiTone.success,
    DhukutiCycleStatus.paidOut ||
    DhukutiCycleStatus.closed => DhukutiTone.neutral,
    DhukutiCycleStatus.atRisk => DhukutiTone.warning,
    DhukutiCycleStatus.cancelled => DhukutiTone.danger,
    DhukutiCycleStatus.open => DhukutiTone.info,
    DhukutiCycleStatus.upcoming => DhukutiTone.neutral,
  };
}

DhukutiTone toneForContributionStatus(ContributionStatus status) {
  return switch (status) {
    ContributionStatus.paid => DhukutiTone.success,
    ContributionStatus.late ||
    ContributionStatus.missed ||
    ContributionStatus.failed ||
    ContributionStatus.failedReview => DhukutiTone.warning,
    ContributionStatus.cancelled ||
    ContributionStatus.expired => DhukutiTone.danger,
    ContributionStatus.due || ContributionStatus.pending => DhukutiTone.neutral,
  };
}

class DhukutiSection extends StatelessWidget {
  const DhukutiSection({
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

class DhukutiScrollView extends StatelessWidget {
  const DhukutiScrollView({required this.children, super.key});

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

class DhukutiHeader extends StatelessWidget {
  const DhukutiHeader({
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
        final scheme = Theme.of(context).colorScheme;
        final compact = constraints.maxWidth < 760;
        final titleBlock = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
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

class DhukutiEmptyState extends StatelessWidget {
  const DhukutiEmptyState({
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
    final scheme = Theme.of(context).colorScheme;
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
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(icon, size: 34, color: scheme.onPrimaryContainer),
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

class DhukutiAvatar extends StatelessWidget {
  const DhukutiAvatar({required this.label, this.small = false, super.key});

  final String label;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: small ? 14 : null,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
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

class DhukutiMetricCard extends StatelessWidget {
  const DhukutiMetricCard({
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
  final DhukutiTone tone;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final color = dhukutiToneColor(context, tone);
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

class DhukutiResponsiveGrid extends StatelessWidget {
  const DhukutiResponsiveGrid({required this.children, super.key});

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

ds.AppStatusTone _toDesignTone(DhukutiTone tone) {
  return switch (tone) {
    DhukutiTone.success => ds.AppStatusTone.success,
    DhukutiTone.warning => ds.AppStatusTone.warning,
    DhukutiTone.info => ds.AppStatusTone.info,
    DhukutiTone.danger => ds.AppStatusTone.danger,
    DhukutiTone.neutral => ds.AppStatusTone.neutral,
  };
}
