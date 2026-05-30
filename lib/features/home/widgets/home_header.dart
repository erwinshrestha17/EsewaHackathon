import 'package:flutter/material.dart';

import '../../../shared/design_system/app_colors.dart';
import '../../../shared/design_system/app_spacing.dart';
import '../../../shared/design_system/app_text_styles.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    required this.displayName,
    required this.hasUnreadNotifications,
    required this.onNotifications,
    super.key,
  });

  final String displayName;
  final bool hasUnreadNotifications;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final firstName = displayName.trim().split(' ').first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: const Text(
                      'S',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('Sajha Kharcha', style: AppTextStyles.cardTitle),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Namaste, $firstName', style: AppTextStyles.screenTitle),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Here’s your shared balance summary',
                style: AppTextStyles.bodySecondary.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Notifications',
          onPressed: onNotifications,
          icon: Badge(
            isLabelVisible: hasUnreadNotifications,
            child: const Icon(Icons.notifications_outlined),
          ),
        ),
      ],
    );
  }
}
