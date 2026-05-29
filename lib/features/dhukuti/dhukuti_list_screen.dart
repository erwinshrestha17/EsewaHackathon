import 'package:flutter/material.dart';

import '../../src/app_state.dart';
import '../../src/models.dart';
import 'dhukuti_create_screen.dart';
import 'dhukuti_detail_screen.dart';
import 'widgets/dhukuti_pool_card.dart';
import 'widgets/dhukuti_tokens.dart';

class DigitalDhukutiScreen extends StatefulWidget {
  const DigitalDhukutiScreen({required this.store, super.key});

  final AppStore store;

  @override
  State<DigitalDhukutiScreen> createState() => _DigitalDhukutiScreenState();
}

class _DigitalDhukutiScreenState extends State<DigitalDhukutiScreen> {
  var _showListOnMobile = true;
  var _listState = _DhukutiListState.loaded;

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final pools = store.visibleDhukutiPools;
    if (store.selectedDhukutiPoolId == null && pools.isNotEmpty) {
      store.selectedDhukutiPoolId = pools.first.id;
    }
    final selected =
        pools
            .where((pool) => pool.id == store.selectedDhukutiPoolId)
            .cast<DhukutiPool?>()
            .firstWhere((pool) => pool != null, orElse: () => null) ??
        (pools.isEmpty ? null : pools.first);

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= 980;
        final list = _DhukutiPoolList(
          store: store,
          pools: pools,
          selectedId: selected?.id,
          state: _listState,
          onStateChanged: (value) => setState(() => _listState = value),
          onCreate: () => _openCreate(context),
          onLearn: () => _showHowItWorks(context),
          onSelect: (pool) {
            setState(() {
              store.selectedDhukutiPoolId = pool.id;
              _showListOnMobile = false;
            });
          },
        );
        final detail = selected == null
            ? Center(
                child: DhukutiEmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No Dhukuti pools yet',
                  message:
                      'Start or join a trusted contribution circle with people you know.',
                  action: FilledButton.icon(
                    onPressed: () => _openCreate(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Dhukuti Pool'),
                  ),
                ),
              )
            : DhukutiDetailScreen(
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
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DhukutiCreateScreen(store: widget.store),
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
                  'How Sangai Dhukuti Works',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This prototype records contribution schedules, payout turns, member statuses, and ledger activity for transparency. Mock eSewa confirmation only marks a contribution as paid in local demo state.',
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

enum _DhukutiListState { loaded, loading, empty, failed }

class _DhukutiPoolList extends StatelessWidget {
  const _DhukutiPoolList({
    required this.store,
    required this.pools,
    required this.selectedId,
    required this.state,
    required this.onStateChanged,
    required this.onCreate,
    required this.onLearn,
    required this.onSelect,
  });

  final AppStore store;
  final List<DhukutiPool> pools;
  final String? selectedId;
  final _DhukutiListState state;
  final ValueChanged<_DhukutiListState> onStateChanged;
  final VoidCallback onCreate;
  final VoidCallback onLearn;
  final ValueChanged<DhukutiPool> onSelect;

  @override
  Widget build(BuildContext context) {
    return DhukutiScrollView(
      children: [
        DhukutiHeader(
          title: 'Digital Dhukuti',
          subtitle:
              'Track contributions, payout turns, and group transparency.',
          action: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('Create Dhukuti Pool'),
          ),
        ),
        DhukutiSection(
          title: 'About Sangai Dhukuti',
          child: const Text(
            'Sangai Dhukuti is a transparent contribution ledger and payment scheduler.',
          ),
        ),
        _DemoStateControls(state: state, onChanged: onStateChanged),
        switch (state) {
          _DhukutiListState.loading => const _LoadingSkeleton(),
          _DhukutiListState.failed => DhukutiSection(
            title: 'Pools',
            child: DhukutiEmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Failed to load data',
              message:
                  'The mock Dhukuti list could not be loaded. Try again for the demo state.',
              action: FilledButton.icon(
                onPressed: () => onStateChanged(_DhukutiListState.loaded),
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ),
          ),
          _DhukutiListState.empty => DhukutiSection(
            title: 'Pools',
            child: DhukutiEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No Dhukuti pools yet',
              message:
                  'Start or join a trusted contribution circle with people you know.',
              action: FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: const Text('Create Dhukuti Pool'),
              ),
              secondaryAction: OutlinedButton.icon(
                onPressed: onLearn,
                icon: const Icon(Icons.info_outline),
                label: const Text('Learn how it works'),
              ),
            ),
          ),
          _DhukutiListState.loaded => DhukutiSection(
            title: 'Your Dhukuti Pools',
            child: pools.isEmpty
                ? DhukutiEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'No Dhukuti pools yet',
                    message:
                        'Start or join a trusted contribution circle with people you know.',
                    action: FilledButton.icon(
                      onPressed: onCreate,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Dhukuti Pool'),
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
                          child: DhukutiPoolCard(
                            store: store,
                            pool: pool,
                            selected: pool.id == selectedId,
                            onTap: () => onSelect(pool),
                          ),
                        ),
                    ],
                  ),
          ),
        },
      ],
    );
  }
}

class _DemoStateControls extends StatelessWidget {
  const _DemoStateControls({required this.state, required this.onChanged});

  final _DhukutiListState state;
  final ValueChanged<_DhukutiListState> onChanged;

  @override
  Widget build(BuildContext context) {
    return DhukutiSection(
      title: 'Demo UI States',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Wrap(
          spacing: 8,
          children: [
            for (final value in _DhukutiListState.values)
              ChoiceChip(
                selected: state == value,
                label: Text(switch (value) {
                  _DhukutiListState.loaded => 'Loaded',
                  _DhukutiListState.loading => 'Loading',
                  _DhukutiListState.empty => 'Empty',
                  _DhukutiListState.failed => 'Failed',
                }),
                onSelected: (_) => onChanged(value),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return DhukutiSection(
      title: 'Pools',
      child: Column(
        children: [
          for (var index = 0; index < 3; index++)
            Container(
              height: 132,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
        ],
      ),
    );
  }
}
