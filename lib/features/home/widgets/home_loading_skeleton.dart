import 'package:flutter/material.dart';

class HomeLoadingSkeleton extends StatelessWidget {
  const HomeLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SkeletonBlock(height: 72),
        SizedBox(height: 14),
        _SkeletonBlock(height: 210),
        SizedBox(height: 14),
        _SkeletonBlock(height: 116),
        SizedBox(height: 14),
        _SkeletonBlock(height: 132),
        SizedBox(height: 14),
        _SkeletonBlock(height: 220),
      ],
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
