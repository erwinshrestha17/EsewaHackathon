import 'package:flutter/material.dart';

import '../../../shared/design_system/app_components.dart' as ds;
import 'savings_circle_tokens.dart';

class SavingsCircleStatusBadge extends StatelessWidget {
  const SavingsCircleStatusBadge({
    required this.label,
    required this.tone,
    this.icon,
    super.key,
  });

  final String label;
  final SavingsCircleTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ds.StatusBadge(
      label: label,
      icon: icon,
      tone: switch (tone) {
        SavingsCircleTone.success => ds.AppStatusTone.success,
        SavingsCircleTone.warning => ds.AppStatusTone.warning,
        SavingsCircleTone.info => ds.AppStatusTone.info,
        SavingsCircleTone.danger => ds.AppStatusTone.danger,
        SavingsCircleTone.neutral => ds.AppStatusTone.neutral,
      },
    );
  }
}
