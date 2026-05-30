import 'package:flutter/material.dart';

import '../../../shared/design_system/app_components.dart' as ds;
import 'dhukuti_tokens.dart';

class DhukutiStatusBadge extends StatelessWidget {
  const DhukutiStatusBadge({
    required this.label,
    required this.tone,
    this.icon,
    super.key,
  });

  final String label;
  final DhukutiTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ds.StatusBadge(
      label: label,
      icon: icon,
      tone: switch (tone) {
        DhukutiTone.success => ds.AppStatusTone.success,
        DhukutiTone.warning => ds.AppStatusTone.warning,
        DhukutiTone.info => ds.AppStatusTone.info,
        DhukutiTone.danger => ds.AppStatusTone.danger,
        DhukutiTone.neutral => ds.AppStatusTone.neutral,
      },
    );
  }
}
