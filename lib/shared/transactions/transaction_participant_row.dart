import 'package:flutter/material.dart';

import '../../src/finance.dart';
import 'transaction_confirmation_data.dart';

class TransactionParticipantRow extends StatelessWidget {
  const TransactionParticipantRow({required this.participant, super.key});

  final TransactionParticipant participant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          _TransactionAvatar(label: participant.avatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  participant.roleLabel,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(
            money(participant.amountShare),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class TransactionAvatar extends StatelessWidget {
  const TransactionAvatar({required this.label, this.size = 40, super.key});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return _TransactionAvatar(label: label, size: size);
  }
}

class _TransactionAvatar extends StatelessWidget {
  const _TransactionAvatar({required this.label, this.size = 40});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUrl = label.startsWith('http://') || label.startsWith('https://');
    if (isUrl) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(label),
      );
    }
    final initials = label.trim().isEmpty ? '?' : label.trim();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.primary.withValues(alpha: 0.12),
      child: Text(
        initials.length > 2 ? initials.substring(0, 2).toUpperCase() : initials,
        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w900),
      ),
    );
  }
}
