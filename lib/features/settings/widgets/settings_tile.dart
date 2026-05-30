import 'package:flutter/material.dart';

import '../../../shared/design_system/app_colors.dart';
import '../../../shared/design_system/app_spacing.dart';
import '../../../shared/design_system/app_text_styles.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.enabled = true,
    this.showChevron = true,
    this.danger = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool enabled;
  final bool showChevron;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final activeColor = danger ? AppColors.error : AppColors.primaryGreen;
    final foreground = enabled
        ? danger
              ? AppColors.error
              : AppColors.textPrimary
        : AppColors.textMuted;
    final iconColor = enabled ? activeColor : AppColors.textMuted;
    return ListTile(
      minTileHeight: 56,
      enabled: enabled,
      onTap: enabled ? onTap : null,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: iconColor.withValues(alpha: 0.12),
        foregroundColor: iconColor,
        child: Icon(icon, size: 20),
      ),
      title: Text(
        title,
        style: AppTextStyles.body.copyWith(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: _SettingsTileTrailing(
        value: value,
        showChevron: showChevron && onTap != null,
        enabled: enabled,
      ),
    );
  }
}

class _SettingsTileTrailing extends StatelessWidget {
  const _SettingsTileTrailing({
    required this.value,
    required this.showChevron,
    required this.enabled,
  });

  final String? value;
  final bool showChevron;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppColors.textSecondary : AppColors.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              value!,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        if (showChevron) ...[
          const SizedBox(width: AppSpacing.xs),
          Icon(Icons.chevron_right, color: color),
        ],
      ],
    );
  }
}
