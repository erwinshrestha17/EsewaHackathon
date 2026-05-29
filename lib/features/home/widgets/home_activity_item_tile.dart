import 'package:flutter/material.dart';

import '../../../src/finance.dart';
import '../home_models.dart';

class HomeActivityItemTile extends StatelessWidget {
  const HomeActivityItemTile({required this.item, this.onTap, super.key});

  final HomeActivityItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      minVerticalPadding: 10,
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: scheme.primary.withValues(alpha: 0.10),
        foregroundColor: scheme.primary,
        child: Icon(item.icon),
      ),
      title: Text(
        item.title,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        '${item.subtitle} · ${item.timestamp}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: item.amount == null && item.status == null
          ? null
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (item.amount != null)
                  Text(
                    money(item.amount!),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                if (item.status != null) ...[
                  const SizedBox(height: 4),
                  _SmallStatus(label: item.status!),
                ],
              ],
            ),
    );
  }
}

class _SmallStatus extends StatelessWidget {
  const _SmallStatus({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        color: scheme.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
