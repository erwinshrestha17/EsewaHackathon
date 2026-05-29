import 'package:flutter/material.dart';

class PrototypeModeBanner extends StatefulWidget {
  const PrototypeModeBanner({super.key});

  @override
  State<PrototypeModeBanner> createState() => _PrototypeModeBannerState();
}

class _PrototypeModeBannerState extends State<PrototypeModeBanner> {
  var _visible = true;

  @override
  Widget build(BuildContext context) {
    if (!_visible) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final color = const Color(0xFFB56A12);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Prototype mode: payments are simulated.',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss prototype note',
            onPressed: () => setState(() => _visible = false),
            icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
