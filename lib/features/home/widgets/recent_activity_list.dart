import 'package:flutter/material.dart';

import '../home_models.dart';
import 'home_activity_item_tile.dart';

class RecentActivityList extends StatelessWidget {
  const RecentActivityList({
    required this.items,
    required this.onViewAll,
    required this.onItemTap,
    super.key,
  });

  final List<HomeActivityItem> items;
  final VoidCallback onViewAll;
  final ValueChanged<HomeActivityItem> onItemTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return _HomeSection(
      title: 'Recent activity',
      action: TextButton(
        onPressed: onViewAll,
        child: const Text('View all activity'),
      ),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: [
              for (final item in items.take(5))
                HomeActivityItemTile(item: item, onTap: () => onItemTap(item)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}
