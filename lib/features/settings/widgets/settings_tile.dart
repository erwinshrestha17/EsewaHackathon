import 'package:flutter/material.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.value,
    this.onTap,
    this.enabled = true,
    this.showChevron = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final VoidCallback? onTap;
  final bool enabled;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.44);
    final iconColor = enabled
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.56);
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
        style: TextStyle(fontWeight: FontWeight.w700, color: foreground),
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
    final color = enabled
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.42);
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
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: color),
        ],
      ],
    );
  }
}
