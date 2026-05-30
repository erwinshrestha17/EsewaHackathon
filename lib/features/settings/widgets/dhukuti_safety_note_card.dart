import 'package:flutter/material.dart';

import '../../../shared/design_system/app_components.dart' as ds;
import '../../../shared/design_system/app_spacing.dart';
import '../../../shared/design_system/app_text_styles.dart';
import '../settings_models.dart';

class DhukutiSafetyNoteCard extends StatelessWidget {
  const DhukutiSafetyNoteCard({this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ds.AppCard(
      tone: ds.AppStatusTone.info,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              dhukutiSafetyNoteText,
              style: AppTextStyles.bodySecondary.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
