import 'package:flutter/material.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({
    required this.onCreateGroup,
    required this.onConnectFriend,
    super.key,
  });

  final VoidCallback onCreateGroup;
  final VoidCallback onConnectFriend;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(Icons.groups_outlined, color: scheme.primary, size: 42),
          const SizedBox(height: 12),
          Text(
            'Start managing money together',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Create a group, connect with friends, or send your first Sangai gift.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              FilledButton(
                onPressed: onCreateGroup,
                child: const Text('Create Group'),
              ),
              OutlinedButton(
                onPressed: onConnectFriend,
                child: const Text('Connect Friend'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
