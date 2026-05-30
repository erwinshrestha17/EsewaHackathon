import 'package:flutter/material.dart';

import '../../src/app_state.dart';
import '../../src/models.dart';
import 'savings_circle_create_screen.dart';
import 'savings_circle_detail_screen.dart';
import 'widgets/savings_circle_pool_card.dart';
import 'widgets/savings_circle_tokens.dart';

class SavingsCircleListScreen extends StatefulWidget {
  const SavingsCircleListScreen({
    required this.store,
    this.onCreate,
    super.key,
  });

  final AppStore store;
  final Future<void> Function(BuildContext context)? onCreate;

  @override
  State<SavingsCircleListScreen> createState() =>
      _SavingsCircleListScreenState();
}

class _SavingsCircleListScreenState extends State<SavingsCircleListScreen> {
  var _showListOnMobile = true;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final pools = store.visibleSavingsCirclePools;
    if (store.selectedSavingsCirclePoolId == null && pools.isNotEmpty) {
      store.selectedSavingsCirclePoolId = pools.first.id;
    }
    final selected =
        pools
            .where((pool) => pool.id == store.selectedSavingsCirclePoolId)
            .cast<SavingsCirclePool?>()
            .firstWhere((pool) => pool != null, orElse: () => null) ??
        (pools.isEmpty ? null : pools.first);

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= 980;
        final list = _SavingsCirclePoolList(
          store: store,
          pools: pools,
          selectedId: selected?.id,
          onCreate: () => _openCreate(context),
          onLearn: () => _showHowItWorks(context),
          onSelect: (pool) {
            setState(() {
              store.selectedSavingsCirclePoolId = pool.id;
              _showListOnMobile = false;
            });
          },
        );
        final detail = selected == null
            ? Center(
                child: SavingsCircleEmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No Savings Circle pools yet',
                  message:
                      'Start or join a trusted contribution circle with people you know.',
                  action: FilledButton.icon(
                    onPressed: () => _openCreate(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Savings Circle Group'),
                  ),
                ),
              )
            : SavingsCircleDetailScreen(
                key: ValueKey('savings-circle-detail-${selected.id}'),
                store: store,
                pool: selected,
                onBack: twoPane
                    ? null
                    : () => setState(() => _showListOnMobile = true),
              );

        if (twoPane) {
          return Row(
            children: [
              SizedBox(width: 430, child: list),
              const VerticalDivider(width: 1),
              Expanded(child: detail),
            ],
          );
        }
        return _showListOnMobile || selected == null ? list : detail;
      },
    );
  }

  Future<void> _openCreate(BuildContext context) {
    final override = widget.onCreate;
    if (override != null) {
      return override(context);
    }
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SavingsCircleCreateScreen(store: widget.store),
      ),
    );
  }

  Future<void> _showHowItWorks(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How Sajha Kharcha Savings Circle Works',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sajha Kharcha Savings Circle tracks contribution schedules, payout turns, member statuses, and ledger activity for transparency.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SavingsCirclePoolList extends StatelessWidget {
  const _SavingsCirclePoolList({
    required this.store,
    required this.pools,
    required this.selectedId,
    required this.onCreate,
    required this.onLearn,
    required this.onSelect,
  });

  final AppStore store;
  final List<SavingsCirclePool> pools;
  final String? selectedId;
  final VoidCallback onCreate;
  final VoidCallback onLearn;
  final ValueChanged<SavingsCirclePool> onSelect;

  @override
  Widget build(BuildContext context) {
    return SavingsCircleScrollView(
      children: [
        SavingsCircleHeader(
          title: 'Savings Circle',
          subtitle:
              'Track contributions, payout turns, and group transparency.',
          action: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create Savings Circle Group'),
          ),
        ),
        SavingsCircleSection(
          title: 'About Sajha Kharcha Savings Circle',
          child: const Text(
            'Sajha Kharcha Savings Circle is a transparent contribution ledger and payment scheduler.',
          ),
        ),
        SavingsCircleSection(
          title: 'Your Savings Circle Pools',
          child: pools.isEmpty
              ? SavingsCircleEmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No Savings Circle pools yet',
                  message:
                      'Start or join a trusted contribution circle with people you know.',
                  action: FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Savings Circle Group'),
                  ),
                  secondaryAction: OutlinedButton.icon(
                    onPressed: onLearn,
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Learn how it works'),
                  ),
                )
              : Column(
                  children: [
                    for (final pool in pools)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SavingsCirclePoolCard(
                          store: store,
                          pool: pool,
                          selected: pool.id == selectedId,
                          onTap: () => onSelect(pool),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
