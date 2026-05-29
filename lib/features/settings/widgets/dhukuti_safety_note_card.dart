import 'package:flutter/material.dart';

import '../settings_models.dart';

class DhukutiSafetyNoteCard extends StatelessWidget {
  const DhukutiSafetyNoteCard({this.onTap, super.key});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.primary.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.22)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: colorScheme.primary),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  dhukutiSafetyNoteText,
                  style: TextStyle(height: 1.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
