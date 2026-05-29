import 'package:flutter/material.dart';

import '../../../src/models.dart';

enum DhukutiTone { neutral, success, warning, info, danger }

const dhukutiPrimary = Color(0xFF178C5B);
const dhukutiFestival = Color(0xFFB56A12);
const dhukutiInk = Color(0xFF19352B);

Color dhukutiToneColor(BuildContext context, DhukutiTone tone) {
  final scheme = Theme.of(context).colorScheme;
  return switch (tone) {
    DhukutiTone.success => dhukutiPrimary,
    DhukutiTone.warning => dhukutiFestival,
    DhukutiTone.info => scheme.tertiary,
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
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
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
      padding: const EdgeInsets.all(20),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
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
        final compact = constraints.maxWidth < 760;
        final titleBlock = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: dhukutiPrimary.withValues(alpha: 0.12),
              foregroundColor: dhukutiPrimary,
              child: const Icon(Icons.account_balance_wallet_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle),
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
            children: [titleBlock, const SizedBox(height: 12), action!],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
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
                  color: dhukutiPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 34, color: dhukutiPrimary),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
              if (action != null || secondaryAction != null) ...[
                const SizedBox(height: 16),
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
    return CircleAvatar(
      radius: small ? 14 : null,
      backgroundColor: dhukutiPrimary.withValues(alpha: 0.12),
      foregroundColor: dhukutiInk,
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.13),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (helper != null) Text(helper!),
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
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
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
