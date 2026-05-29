import 'package:flutter/material.dart';

class FestivalModeCard extends StatelessWidget {
  const FestivalModeCard({required this.onExplore, super.key});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.secondary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.celebration_outlined, color: scheme.secondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Festival Mode',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Fast Demo Flow',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a Dashain Khasi split, Tihar gift pool, or College Picnic group.',
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onExplore,
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Explore Templates'),
          ),
        ],
      ),
    );
  }
}
