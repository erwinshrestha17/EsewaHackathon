import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'app_state.dart';
import 'finance.dart';
import 'models.dart';

class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({
    required AppStore super.notifier,
    required super.child,
    super.key,
  });

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<StoreScope>();
    assert(scope != null, 'No StoreScope found in context.');
    return scope!.notifier!;
  }
}

class SangaiApp extends StatelessWidget {
  const SangaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sangai',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF178C5B),
          primary: const Color(0xFF178C5B),
          secondary: const Color(0xFFB56A12),
          tertiary: const Color(0xFF235789),
          error: const Color(0xFFB3261E),
          surface: const Color(0xFFFBFCF8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F2),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          isDense: true,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const SangaiShell(),
    );
  }
}

class SangaiShell extends StatefulWidget {
  const SangaiShell({super.key});

  @override
  State<SangaiShell> createState() => _SangaiShellState();
}

class _SangaiShellState extends State<SangaiShell> {
  var _index = 0;

  static const _destinations = <_Destination>[
    _Destination('Home', Icons.dashboard_outlined, Icons.dashboard),
    _Destination('Groups', Icons.groups_outlined, Icons.groups),
    _Destination(
      'Connections',
      Icons.person_add_alt_1_outlined,
      Icons.person_add_alt_1,
    ),
    _Destination('Gifts', Icons.card_giftcard_outlined, Icons.card_giftcard),
    _Destination(
      'Dhukuti',
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet,
    ),
    _Destination('Activity', Icons.history_outlined, Icons.history),
  ];

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final body = switch (_index) {
      0 => HomeScreen(onNavigate: _go),
      1 => const GroupsScreen(),
      2 => const ConnectionsScreen(),
      3 => const GiftsScreen(),
      4 => const DhukutiScreen(),
      _ => const ActivityScreen(),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'S',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sangai'),
                      Text(
                        'Connect, split, gift, settle',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Activity',
                onPressed: () => _go(5),
                icon: Badge(
                  isLabelVisible: store.currentNotifications
                      .where((item) => !item.read)
                      .isNotEmpty,
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
              const SizedBox(width: 4),
              _UserSwitcher(store: store),
              const SizedBox(width: 12),
            ],
          ),
          body: Row(
            children: [
              if (wide)
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _go,
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationRailDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: Text(destination.label),
                      ),
                  ],
                ),
              Expanded(child: body),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: _go,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: destination.label,
                      ),
                  ],
                ),
        );
      },
    );
  }

  void _go(int index) {
    setState(() => _index = index);
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.onNavigate, super.key});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final dhukutiDue = store.dhukutiContributions
        .where(
          (item) =>
              item.userId == store.currentUserId &&
              (item.status == ContributionStatus.due ||
                  item.status == ContributionStatus.late),
        )
        .fold<int>(0, (sum, item) => sum + item.amountMinor);

    return AppScrollView(
      children: [
        Text(
          'Namaste, ${store.currentUser.displayName.split(' ').first}',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          'A local wallet-style prototype with seeded demo data and no backend calls.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        ResponsiveWrap(
          children: [
            StatTile(
              label: 'You owe',
              value: shortMoney(store.totalOwedByCurrentUser),
              icon: Icons.north_east,
              tone: Tone.warning,
            ),
            StatTile(
              label: 'Owed to you',
              value: shortMoney(store.totalOwedToCurrentUser),
              icon: Icons.south_west,
              tone: Tone.success,
            ),
            StatTile(
              label: 'Pending settlements',
              value: '${store.pendingSettlementsForCurrentUser.length}',
              icon: Icons.hourglass_top,
              tone: Tone.info,
            ),
            StatTile(
              label: 'Dhukuti dues',
              value: shortMoney(dhukutiDue),
              icon: Icons.account_balance_wallet,
              tone: Tone.neutral,
            ),
          ],
        ),
        SectionPanel(
          title: 'Fast Demo Flow',
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () {
                  final id = store.createFestivalTemplate(
                    'Dashain Khasi Split',
                  );
                  store.selectedGroupId = id;
                  onNavigate(1);
                },
                icon: const Icon(Icons.celebration_outlined),
                label: const Text('Dashain split'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final count = store.settleAllForCurrentUserAcrossGroups();
                  showSnack(
                    context,
                    count == 0
                        ? 'No current payable suggestions for this user.'
                        : 'Confirmed $count mock settlement(s).',
                  );
                },
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Settle my dues'),
              ),
              OutlinedButton.icon(
                onPressed: () => onNavigate(3),
                icon: const Icon(Icons.card_giftcard_outlined),
                label: const Text('Send gift'),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The recommended story arc is ready: create a Dashain group, add an expense, split it, settle through Sangai Pay, send a gift, then show the Digital Dhukuti ledger.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  FeatureChip(label: 'P0 loop complete'),
                  FeatureChip(label: 'P1 split modes'),
                  FeatureChip(label: 'P2 Flutter prototype'),
                  FeatureChip(label: 'No backend touched'),
                ],
              ),
            ],
          ),
        ),
        SectionPanel(
          title: 'Groups Snapshot',
          action: TextButton.icon(
            onPressed: () => onNavigate(1),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Open'),
          ),
          child: Column(
            children: [
              for (final group in store.visibleGroups.take(4))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Icon(iconForCategory(group.category)),
                  ),
                  title: Text(group.name),
                  subtitle: Text(
                    '${enumLabel(group.category)} • ${group.template}',
                  ),
                  trailing: BalancePill(
                    amountMinor: store.balanceForUserInGroup(
                      group.id,
                      store.currentUserId,
                    ),
                  ),
                  onTap: () {
                    store.selectedGroupId = group.id;
                    onNavigate(1);
                  },
                ),
            ],
          ),
        ),
        SectionPanel(
          title: 'Recent Activity',
          action: TextButton.icon(
            onPressed: () => onNavigate(5),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('All'),
          ),
          child: ActivityList(items: store.visibleActivity.take(6).toList()),
        ),
      ],
    );
  }
}

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final connections = store.connectionsFor(store.currentUserId);
    final incoming = connections
        .where(
          (item) =>
              item.recipientId == store.currentUserId &&
              item.status == ConnectionStatus.pending,
        )
        .toList();
    final active = connections
        .where((item) => item.status == ConnectionStatus.approved)
        .toList();
    final results = store.searchUsers(_searchController.text);

    return AppScrollView(
      children: [
        ScreenHeader(
          title: 'Connections',
          subtitle:
              'Connect through QR or mobile contacts, then manage trusted people for groups and gifts.',
          icon: Icons.person_add_alt_1,
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => showScanQrDialog(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan'),
              ),
              OutlinedButton.icon(
                onPressed: () => showMyQrDialog(context),
                icon: const Icon(Icons.qr_code_2),
                label: const Text('My QR'),
              ),
            ],
          ),
        ),
        SectionPanel(
          title: 'Mobile Contacts',
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search name or phone',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              if (results.isEmpty)
                const EmptyState(
                  icon: Icons.contacts_outlined,
                  title: 'No contacts found',
                  body: 'Try a seeded mobile number such as 9800000008.',
                )
              else
                for (final user in results)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(user: user),
                    title: Text(user.displayName),
                    subtitle: Text(user.phone),
                    trailing: FilledButton.icon(
                      onPressed: () {
                        final message = store.sendConnectionRequest(user.id);
                        showSnack(context, message);
                        setState(() {});
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Connect'),
                    ),
                  ),
            ],
          ),
        ),
        if (incoming.isNotEmpty)
          SectionPanel(
            title: 'Incoming Requests',
            child: Column(
              children: [
                for (final connection in incoming)
                  _ConnectionTile(connection: connection, compact: false),
              ],
            ),
          ),
        SectionPanel(
          title: 'Active Connections',
          child: active.isEmpty
              ? const EmptyState(
                  icon: Icons.people_outline,
                  title: 'No active connections',
                  body:
                      'Approved connections can join groups and receive gifts.',
                )
              : Column(
                  children: [
                    for (final connection in active)
                      _ConnectionTile(connection: connection, compact: false),
                  ],
                ),
        ),
      ],
    );
  }
}

class _InviteQrView extends StatelessWidget {
  const _InviteQrView({
    required this.code,
    required this.label,
    required this.size,
  });

  final String code;
  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: QrImageView(
          data: code,
          version: QrVersions.auto,
          size: size,
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.M,
          gapless: false,
          semanticsLabel: 'Sangai QR invite for $label',
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Colors.black,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _ConnectionTile extends StatelessWidget {
  const _ConnectionTile({required this.connection, required this.compact});

  final Connection connection;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final other = store.userById(connection.otherUserId(store.currentUserId));
    final blockedByMe = connection.isBlockedBy(store.currentUserId, other.id);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(user: other),
      title: Text(other.displayName),
      subtitle: Text(
        '${enumLabel(connection.status)} • ${connection.events.length} event(s)'
        '${blockedByMe ? ' • blocked by you' : ''}',
      ),
      trailing: compact
          ? StatusPill(label: enumLabel(connection.status), tone: Tone.neutral)
          : Wrap(
              spacing: 6,
              children: [
                if (connection.status == ConnectionStatus.pending &&
                    connection.recipientId == store.currentUserId)
                  IconButton.filledTonal(
                    tooltip: 'Approve',
                    onPressed: () => store.approveConnection(connection.id),
                    icon: const Icon(Icons.check),
                  ),
                if (connection.status == ConnectionStatus.pending &&
                    connection.recipientId == store.currentUserId)
                  IconButton.outlined(
                    tooltip: 'Decline',
                    onPressed: () => store.declineConnection(connection.id),
                    icon: const Icon(Icons.close),
                  ),
                if (connection.status == ConnectionStatus.approved)
                  IconButton.outlined(
                    tooltip: 'Remove',
                    onPressed: () => store.removeConnection(connection.id),
                    icon: const Icon(Icons.person_remove_outlined),
                  ),
                IconButton.outlined(
                  tooltip: blockedByMe ? 'Unblock' : 'Block',
                  onPressed: () => blockedByMe
                      ? store.unblockConnection(connection.id, other.id)
                      : store.blockConnection(connection.id, other.id),
                  icon: Icon(blockedByMe ? Icons.lock_open : Icons.block),
                ),
                IconButton.outlined(
                  tooltip: 'Report',
                  onPressed: () {
                    store.reportConnection(
                      connection.id,
                      other.id,
                      'safety_review',
                    );
                    showSnack(context, 'Safety report opened for review.');
                  },
                  icon: const Icon(Icons.flag_outlined),
                ),
              ],
            ),
    );
  }
}

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final groups = store.visibleGroups;
    final selectedId = store.selectedGroupId;
    final selected = groups.any((group) => group.id == selectedId)
        ? store.groupByIdOrNull(selectedId)
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= 1000;
        final list = AppScrollView(
          children: [
            ScreenHeader(
              title: 'Groups',
              subtitle:
                  'Create groups from accepted connections, add split expenses, settle, export statements, and keep history visible.',
              icon: Icons.groups,
              action: FilledButton.icon(
                onPressed: () => showCreateGroupDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('New group'),
              ),
            ),
            SectionPanel(
              title: 'Your Groups',
              child: groups.isEmpty
                  ? const EmptyState(
                      icon: Icons.group_off_outlined,
                      title: 'No groups',
                      body: 'Create one with active connections.',
                    )
                  : Column(
                      children: [
                        for (final group in groups)
                          ListTile(
                            selected: group.id == selectedId,
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              child: Icon(iconForCategory(group.category)),
                            ),
                            title: Text(group.name),
                            subtitle: Text(
                              '${enumLabel(group.category)} • ${store.membersForGroup(group.id, activeOnly: true).length} active members',
                            ),
                            trailing: BalancePill(
                              amountMinor: store.balanceForUserInGroup(
                                group.id,
                                store.currentUserId,
                              ),
                            ),
                            onTap: () => setState(
                              () => store.selectedGroupId = group.id,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        );

        final detail = selected == null
            ? const Center(
                child: EmptyState(
                  icon: Icons.groups_2_outlined,
                  title: 'Select a group',
                  body: 'Pick a group from the list or create a new group.',
                ),
              )
            : GroupDetail(group: selected, scrollable: twoPane);

        if (twoPane) {
          return Row(
            children: [
              SizedBox(width: 410, child: list),
              const VerticalDivider(width: 1),
              Expanded(child: detail),
            ],
          );
        }
        return selected == null
            ? list
            : AppScrollView(
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => store.selectedGroupId = null),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Groups'),
                  ),
                  detail,
                ],
              );
      },
    );
  }
}

class GroupDetail extends StatelessWidget {
  const GroupDetail({required this.group, this.scrollable = true, super.key});

  final Group group;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final members = store.membersForGroup(group.id);
    final balances = store.balancesForGroup(group.id);
    final suggestions = store.suggestionsForGroup(group.id);
    final canAddExpense = store.isActiveGroupMember(
      group.id,
      store.currentUserId,
    );
    final groupExpenses =
        store.expenses.where((expense) => expense.groupId == group.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final children = [
      ScreenHeader(
        title: group.name,
        subtitle:
            '${enumLabel(group.category)} • ${group.template} • ${members.length} historical member(s)',
        icon: iconForCategory(group.category),
        action: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: canAddExpense
                  ? () => showAddExpenseDialog(context, group.id)
                  : null,
              icon: const Icon(Icons.receipt_long),
              label: const Text('Add expense'),
            ),
            OutlinedButton.icon(
              onPressed: () => showStatementDialog(context, group.id),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Statement'),
            ),
          ],
        ),
      ),
      ResponsiveWrap(
        children: [
          StatTile(
            label: 'Group balance',
            value: money(
              balances.values.fold<int>(0, (sum, value) => sum + value).abs(),
            ),
            icon: Icons.balance,
            tone: Tone.neutral,
          ),
          StatTile(
            label: 'Your position',
            value: money(
              store.balanceForUserInGroup(group.id, store.currentUserId),
            ),
            icon: Icons.account_balance,
            tone:
                store.balanceForUserInGroup(group.id, store.currentUserId) >= 0
                ? Tone.success
                : Tone.warning,
          ),
          StatTile(
            label: 'Suggestions',
            value: '${suggestions.length}',
            icon: Icons.route_outlined,
            tone: Tone.info,
          ),
          StatTile(
            label: 'Locked through',
            value: group.latestSettlementLockAt == null
                ? 'Open'
                : dateLabel(group.latestSettlementLockAt!),
            icon: Icons.lock_clock_outlined,
            tone: Tone.neutral,
          ),
        ],
      ),
      SectionPanel(
        title: 'Members and Roles',
        action: OutlinedButton.icon(
          onPressed: () => showAddMemberDialog(context, group.id),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add'),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final member in members)
              InputChip(
                avatar: UserAvatar(
                  user: store.userById(member.userId),
                  small: true,
                ),
                label: Text(
                  '${store.nameOf(member.userId)} • ${enumLabel(member.role)}'
                  '${member.status == MemberStatus.removed ? ' • inactive' : ''}',
                ),
                onDeleted:
                    member.userId == store.currentUserId ||
                        member.status == MemberStatus.removed
                    ? null
                    : () => store.removeGroupMember(group.id, member.userId),
                onPressed: () => showRoleDialog(context, group.id, member),
              ),
          ],
        ),
      ),
      SectionPanel(
        title: 'Balances',
        child: balances.isEmpty
            ? const EmptyState(
                icon: Icons.check_circle_outline,
                title: 'All settled',
                body:
                    'Open balance is zero after paid settlements and adjustments.',
              )
            : Column(
                children: [
                  for (final entry in balances.entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: UserAvatar(user: store.userById(entry.key)),
                      title: Text(store.nameOf(entry.key)),
                      subtitle: Text(entry.value >= 0 ? 'Is owed' : 'Owes'),
                      trailing: BalancePill(amountMinor: entry.value),
                    ),
                ],
              ),
      ),
      SectionPanel(
        title: 'Settlement Suggestions',
        child: suggestions.isEmpty
            ? const EmptyState(
                icon: Icons.done_all,
                title: 'No settlement needed',
                body: 'The greedy net-balance simplifier found no open debts.',
              )
            : Column(
                children: [
                  for (final suggestion in suggestions)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.payments)),
                      title: Text(
                        '${store.nameOf(suggestion.payerId)} pays ${store.nameOf(suggestion.payeeId)}',
                      ),
                      subtitle: Text(
                        suggestion.hasPending
                            ? 'Pending payment already exists'
                            : 'Greedy min-cash-flow suggestion',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          BalancePill(amountMinor: -suggestion.amountMinor),
                          if (!suggestion.hasPending)
                            FilledButton(
                              onPressed: () {
                                final settlement = store
                                    .createOrReuseSettlement(suggestion);
                                showSnack(
                                  context,
                                  'Pending settlement ${settlement.id} created.',
                                );
                              },
                              child: const Text('Create'),
                            )
                          else
                            FilledButton.icon(
                              onPressed: () => store.confirmSettlement(
                                suggestion.pendingSettlementId!,
                              ),
                              icon: const Icon(Icons.check),
                              label: const Text('Confirm'),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
      SectionPanel(
        title: 'Expenses',
        child: groupExpenses.isEmpty
            ? const EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No expenses yet',
                body: 'Add a manual or receipt-assisted expense.',
              )
            : Column(
                children: [
                  for (final expense in groupExpenses)
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      leading: Icon(
                        expense.status == ExpenseStatus.voided
                            ? Icons.cancel_outlined
                            : Icons.receipt_long,
                      ),
                      title: Text(expense.title),
                      subtitle: Text(
                        '${money(expense.totalMinor)} • ${enumLabel(expense.splitMode)} • paid by ${payerSummary(store, expense)}',
                      ),
                      trailing: StatusPill(
                        label: expense.lockedAt == null
                            ? enumLabel(expense.status)
                            : 'Locked',
                        tone: expense.status == ExpenseStatus.voided
                            ? Tone.warning
                            : Tone.neutral,
                      ),
                      children: [
                        for (final share in expense.shares)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: UserAvatar(
                              user: store.userById(share.userId),
                              small: true,
                            ),
                            title: Text(store.nameOf(share.userId)),
                            trailing: Text(money(share.amountMinor)),
                          ),
                        if (expense.items.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final item in expense.items)
                                  Chip(
                                    avatar: const Icon(
                                      Icons.restaurant_menu,
                                      size: 16,
                                    ),
                                    label: Text(
                                      '${item.label} • ${money(item.totalAmountMinor)}',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        OverflowBar(
                          alignment: MainAxisAlignment.start,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  showEditExpenseDialog(context, expense),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit'),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                final ok = store.voidExpense(
                                  expense.id,
                                  'Demo void requested',
                                );
                                showSnack(
                                  context,
                                  ok
                                      ? 'Expense voided.'
                                      : 'Expense is locked; use adjustment.',
                                );
                              },
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('Void'),
                            ),
                            if (expense.lockedAt != null)
                              TextButton.icon(
                                onPressed: () => showAdjustmentDialog(
                                  context,
                                  group.id,
                                  expense.payers.isEmpty
                                      ? expense.payerId
                                      : expense.payers.first.userId,
                                ),
                                icon: const Icon(Icons.tune),
                                label: const Text('Adjust'),
                              ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
      ),
      SectionPanel(
        title: 'Activity Timeline',
        child: GroupActivitySummary(
          groupId: group.id,
          items: store.activityForGroup(group.id).take(5).toList(),
        ),
      ),
    ];

    if (scrollable) {
      return AppScrollView(children: children);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(height: 16),
          children[index],
        ],
      ],
    );
  }
}

class GiftsScreen extends StatefulWidget {
  const GiftsScreen({super.key});

  @override
  State<GiftsScreen> createState() => _GiftsScreenState();
}

class _GiftsScreenState extends State<GiftsScreen> {
  final _amount = TextEditingController(text: '500');
  final _message = TextEditingController(text: 'Dashain ko shubhakamana! 🌺');
  GiftTheme _theme = giftThemes.first;
  String? _recipientId;

  // Compose vs. celebration ("done") stage, mirroring the send flow.
  bool _sent = false;
  late GiftTheme _sentTheme;
  int _sentAmountMinor = 0;
  String _sentToName = '';
  String _sentMessage = '';

  static const _quickAmounts = <int>[251, 500, 1100];

  @override
  void dispose() {
    _amount.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final connections = store.activeConnectionUsers();
    // Reset the recipient when it is unset or no longer a valid connection
    // (e.g. after switching the active user) so a stale id never lingers.
    if (_recipientId == null ||
        !connections.any((user) => user.id == _recipientId)) {
      _recipientId = connections.isEmpty ? null : connections.first.id;
    }
    final visibleGifts =
        store.gifts
            .where(
              (gift) =>
                  gift.senderId == store.currentUserId ||
                  gift.recipientId == store.currentUserId,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return AppScrollView(
      children: [
        ScreenHeader(
          title: 'Sangai Gifts',
          subtitle:
              'Send a themed money envelope to a connection, or run a group gift pool.',
          icon: Icons.card_giftcard,
        ),
        if (connections.isEmpty)
          const SectionPanel(
            title: 'Send a gift',
            child: EmptyState(
              icon: Icons.person_add_alt,
              title: 'No connections yet',
              body:
                  'Gifts can only be sent to active, accepted connections. Add one from the Connections tab first.',
            ),
          ),
        ResponsiveWrap(
          children: [
            if (connections.isNotEmpty)
              SectionPanel(
                title: _sent ? 'Gift sent' : 'Send a gift',
                child: _sent
                    ? _buildCelebration(context)
                    : _buildCompose(context, store, connections),
              ),
            SectionPanel(
              title: 'Gift Pools',
              action: OutlinedButton.icon(
                onPressed: () => showCreateGiftPoolDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('New pool'),
              ),
              child: store.giftPools.isEmpty
                  ? const EmptyState(
                      icon: Icons.redeem_outlined,
                      title: 'No gift pools',
                      body: 'Create one from a group for a shared envelope.',
                    )
                  : Column(
                      children: [
                        for (final pool in store.giftPools)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.redeem),
                            ),
                            title: Text(pool.title),
                            subtitle: Text(
                              '${store.groupById(pool.groupId).name} • ${money(store.giftPoolTotal(pool.id))} of ${money(pool.targetAmountMinor)}',
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                StatusPill(
                                  label: enumLabel(pool.status),
                                  tone: pool.status == GiftPoolStatus.completed
                                      ? Tone.success
                                      : Tone.neutral,
                                ),
                                FilledButton(
                                  onPressed: pool.status == GiftPoolStatus.open
                                      ? () => showContributeToGiftPoolDialog(
                                          context,
                                          pool,
                                        )
                                      : null,
                                  child: const Text('Contribute'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
        SectionPanel(
          title: 'Gift Ledger',
          child: visibleGifts.isEmpty
              ? const EmptyState(
                  icon: Icons.mail_outline,
                  title: 'No gifts yet',
                  body:
                      'Gift messages remain visible only to sender and recipient.',
                )
              : Column(
                  children: [
                    for (final gift in visibleGifts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: GiftEnvelopeCard(
                          gift: gift,
                          isSender: gift.senderId == store.currentUserId,
                          isRecipient: gift.recipientId == store.currentUserId,
                          senderName: store.nameOf(gift.senderId),
                          recipientName: store.nameOf(gift.recipientId),
                          onOpen: () {
                            if (store.openGift(gift.id)) {
                              showGiftOpenedCelebration(
                                context,
                                gift,
                                fromName: store.nameOf(gift.senderId),
                                toName: store.nameOf(gift.recipientId),
                              );
                            }
                          },
                          onCancel: () =>
                              showSnack(context, store.cancelGift(gift.id)),
                          onRefund: () =>
                              showSnack(context, store.refundGift(gift.id)),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCompose(
    BuildContext context,
    AppStore store,
    List<AppUser> connections,
  ) {
    final amountMinor = parseMoneyToMinor(_amount.text);
    final valid = amountMinor > 0 && _recipientId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live preview of the envelope the recipient will receive.
        GiftCardVisual(
          theme: _theme,
          amountMinor: amountMinor,
          fromName: store.nameOf(store.currentUserId).split(' ').first,
          toName: _recipientId == null
              ? '…'
              : store.nameOf(_recipientId!).split(' ').first,
          message: _message.text,
        ),
        const _GiftEyebrow('Choose a theme'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final theme in giftThemes) _themeButton(context, theme),
            ],
          ),
        ),
        const _GiftEyebrow('To'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final user in connections) _recipientButton(context, user),
            ],
          ),
        ),
        const _GiftEyebrow('Amount'),
        Row(
          children: [
            for (final amount in _quickAmounts)
              Expanded(child: _amountButton(context, amount)),
          ],
        ),
        const SizedBox(height: 11),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Custom amount',
            prefixText: 'NPR ',
          ),
        ),
        const SizedBox(height: 11),
        TextField(
          controller: _message,
          maxLines: 2,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Add a message…',
            helperText: 'Visible only to you and the recipient.',
            suffixIcon: IconButton(
              tooltip: 'Stickers',
              icon: const Icon(Icons.emoji_emotions_outlined),
              onPressed: _openStickerPicker,
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: valid ? () => _send(context, store, amountMinor) : null,
            icon: const Icon(Icons.card_giftcard),
            label: const Text('Send'),
          ),
        ),
      ],
    );
  }

  void _send(BuildContext context, AppStore store, int amountMinor) {
    final toName = store.nameOf(_recipientId!);
    final message = store.sendGift(
      recipientId: _recipientId!,
      template: _theme.label,
      amountMinor: amountMinor,
      message: _message.text,
    );
    if (message.startsWith('Gift sent')) {
      setState(() {
        _sent = true;
        _sentTheme = _theme;
        _sentAmountMinor = amountMinor;
        _sentToName = toName;
        _sentMessage = _message.text;
      });
    } else {
      showSnack(context, message);
    }
  }

  Widget _buildCelebration(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GiftCardVisual(
          theme: _sentTheme,
          amountMinor: _sentAmountMinor,
          fromName: 'You',
          toName: _sentToName.split(' ').first,
          message: _sentMessage,
          big: true,
        ),
        const SizedBox(height: 22),
        Text(
          'Gift sent! 🎉',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${money(_sentAmountMinor)} to $_sentToName',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => setState(() => _sent = false),
          child: const Text('Send another'),
        ),
      ],
    );
  }

  Widget _themeButton(BuildContext context, GiftTheme theme) {
    final selected = _theme.id == theme.id;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 9, bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => setState(() => _theme = theme),
        child: Container(
          width: 78,
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 7),
          decoration: BoxDecoration(
            color: selected ? scheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected ? theme.from : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: theme.gradient,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(theme.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 6),
              Text(
                theme.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recipientButton(BuildContext context, AppUser user) {
    final selected = _recipientId == user.id;
    final scheme = Theme.of(context).colorScheme;
    final green = scheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _recipientId = user.id),
        child: Container(
          width: 66,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 7),
          decoration: BoxDecoration(
            color: selected
                ? green.withValues(alpha: 0.10)
                : scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? green : scheme.outlineVariant,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              UserAvatar(user: user),
              const SizedBox(height: 6),
              Text(
                user.displayName.split(' ').first,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? green : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountButton(BuildContext context, int amount) {
    final selected = _amount.text == amount.toString();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => setState(() => _amount.text = amount.toString()),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surface,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          child: Text(
            'Rs $amount',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  // Inserts an emoji sticker into the message at the cursor (or appends it).
  void _insertIntoMessage(String insert) {
    final text = _message.text;
    final selection = _message.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    final updated = text.replaceRange(start, end, insert);
    _message.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + insert.length),
    );
    setState(() {});
  }

  void _openStickerPicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SizedBox(
          height: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  'Stickers',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 8,
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final emoji in giftStickerEmojis)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _insertIntoMessage(emoji),
                        child: Center(
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A small uppercase section label used between gift compose sections.
class _GiftEyebrow extends StatelessWidget {
  const _GiftEyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 9),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Festival- and occasion-aware visual treatment for a gift card.
class GiftTheme {
  const GiftTheme({
    required this.id,
    required this.label,
    required this.emoji,
    required this.icon,
    required this.from,
    required this.to,
  });

  final String id;
  final String label;
  final String emoji;
  final IconData icon;
  final Color from;
  final Color to;

  Color get color => from;

  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [from, to],
  );
}

/// Selectable gift themes. Gradients use the app's festival palette so they sit
/// alongside the green primary brand without clashing.
const giftThemes = <GiftTheme>[
  GiftTheme(
    id: 'dashain',
    label: 'Dashain Tika',
    emoji: '🌺',
    icon: Icons.celebration,
    from: Color(0xFFF2A12E),
    to: Color(0xFFCE3F30),
  ),
  GiftTheme(
    id: 'tihar',
    label: 'Tihar Deusi',
    emoji: '🪔',
    icon: Icons.light_mode,
    from: Color(0xFFFFB627),
    to: Color(0xFFD98324),
  ),
  GiftTheme(
    id: 'birthday',
    label: 'Birthday',
    emoji: '🎂',
    icon: Icons.cake,
    from: Color(0xFF7A4FB6),
    to: Color(0xFFCE3F30),
  ),
  GiftTheme(
    id: 'wedding',
    label: 'Wedding',
    emoji: '💍',
    icon: Icons.favorite,
    from: Color(0xFF27B069),
    to: Color(0xFF15784A),
  ),
  GiftTheme(
    id: 'thanks',
    label: 'Thank You',
    emoji: '🙏',
    icon: Icons.volunteer_activism,
    from: Color(0xFF2A7DB6),
    to: Color(0xFF15784A),
  ),
];

const _defaultGiftTheme = GiftTheme(
  id: 'gift',
  label: 'Gift',
  emoji: '🎁',
  icon: Icons.card_giftcard,
  from: Color(0xFF1B9355),
  to: Color(0xFF15784A),
);

GiftTheme giftThemeFor(String template) {
  final key = template.trim().toLowerCase();
  for (final theme in giftThemes) {
    final word = theme.id == 'thanks' ? 'thank' : theme.id;
    if (key.contains(word)) {
      return theme;
    }
  }
  return _defaultGiftTheme;
}

Tone toneForGiftStatus(GiftStatus status) {
  return switch (status) {
    GiftStatus.opened => Tone.success,
    GiftStatus.sent => Tone.info,
    GiftStatus.pending => Tone.warning,
    GiftStatus.refunded || GiftStatus.cancelled => Tone.neutral,
    GiftStatus.failed ||
    GiftStatus.failedReview ||
    GiftStatus.expired => Tone.danger,
  };
}

/// The themed gradient gift card with decorative mandalas, used as the live
/// preview, the celebration card, and the colourful face of each ledger entry.
class GiftCardVisual extends StatelessWidget {
  const GiftCardVisual({
    required this.theme,
    required this.amountMinor,
    required this.fromName,
    required this.toName,
    required this.message,
    this.big = false,
    this.faded = false,
    super.key,
  });

  final GiftTheme theme;
  final int amountMinor;
  final String fromName;
  final String toName;
  final String message;
  final bool big;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(big ? 26 : 22),
      child: Container(
        decoration: BoxDecoration(
          gradient: theme.gradient,
          boxShadow: [
            BoxShadow(
              color: theme.from.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -26,
              top: -26,
              child: SizedBox.square(
                dimension: big ? 150 : 120,
                child: const CustomPaint(
                  painter: GiftMandalaPainter(opacity: 0.45),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -40,
              child: const SizedBox.square(
                dimension: 110,
                child: CustomPaint(
                  painter: GiftMandalaPainter(opacity: 0.25),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(big ? 24 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          theme.label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ),
                      Text(
                        theme.emoji,
                        style: TextStyle(fontSize: big ? 30 : 24),
                      ),
                    ],
                  ),
                  SizedBox(height: big ? 14 : 10),
                  Text(
                    money(amountMinor),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: big ? 40 : 32,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  if (message.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '“${message.trim()}”',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('From $fromName', style: _footerStyle),
                      Text('To $toName', style: _footerStyle),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return faded ? Opacity(opacity: 0.55, child: card) : card;
  }

  static const _footerStyle = TextStyle(
    color: Colors.white,
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
  );
}

/// Paints the concentric petal mandala that decorates the gift card corners.
class GiftMandalaPainter extends CustomPainter {
  const GiftMandalaPainter({this.opacity = 0.45});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.013
      ..color = Colors.white.withValues(alpha: 0.55 * opacity);

    final petal = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * 0.18,
      height: size.height * 0.68,
    );
    for (var i = 0; i < 12; i++) {
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(i * math.pi / 6);
      canvas.drawOval(petal, stroke);
      canvas.restore();
    }
    canvas.drawCircle(center, size.width * 0.44, stroke);
    canvas.drawCircle(
      center,
      size.width * 0.13,
      Paint()..color = Colors.white.withValues(alpha: 0.25 * opacity),
    );
    canvas.drawCircle(
      center,
      size.width * 0.05,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(covariant GiftMandalaPainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}

/// Emoji stickers a sender can drop into a gift message. These insert as plain
/// characters, so they round-trip through the message string unchanged.
const giftStickerEmojis = <String>[
  '🌺', '🪔', '🎉', '🎊', '✨', '🎆', '🎇', '🕉️',
  '🙏', '🛕', '🪷', '🎁', '🍰', '🧧', '🪙', '🌟',
  '😀', '😄', '😍', '🥰', '😘', '🤗', '😎', '🥳',
  '❤️', '🧡', '💛', '💚', '💙', '💜', '💖', '💝',
  '👍', '👏', '🙌', '🤝', '💪', '🔥', '🎈', '💫',
];

/// A ledger entry: the themed gift card plus sender/recipient actions.
class GiftEnvelopeCard extends StatelessWidget {
  const GiftEnvelopeCard({
    required this.gift,
    required this.isSender,
    required this.isRecipient,
    required this.senderName,
    required this.recipientName,
    required this.onOpen,
    required this.onCancel,
    required this.onRefund,
    super.key,
  });

  final GiftCard gift;
  final bool isSender;
  final bool isRecipient;
  final String senderName;
  final String recipientName;
  final VoidCallback onOpen;
  final VoidCallback onCancel;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) {
    final theme = giftThemeFor(gift.template);
    final reversed =
        gift.status == GiftStatus.refunded ||
        gift.status == GiftStatus.cancelled;
    final canOpen = isRecipient && gift.status == GiftStatus.sent;
    final canCancel = isSender && gift.status == GiftStatus.sent;
    final canRefund = isSender && gift.status == GiftStatus.opened;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GiftCardVisual(
          theme: theme,
          amountMinor: gift.amountMinor,
          fromName: senderName.split(' ').first,
          toName: recipientName.split(' ').first,
          message: gift.message,
          faded: reversed,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            StatusPill(
              label: enumLabel(gift.status),
              tone: toneForGiftStatus(gift.status),
            ),
            const Spacer(),
            if (canOpen)
              FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.drafts_outlined, size: 18),
                label: const Text('Open'),
              ),
            if (canCancel)
              OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
            if (canRefund)
              OutlinedButton(onPressed: onRefund, child: const Text('Refund')),
          ],
        ),
        if (reversed) ...[
          const SizedBox(height: 6),
          Text(
            gift.status == GiftStatus.cancelled
                ? 'Cancelled before opening • Sangai Pay payment reversed.'
                : 'Refunded • Sangai Pay payment reversed.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

Future<void> showGiftOpenedCelebration(
  BuildContext context,
  GiftCard gift, {
  required String fromName,
  required String toName,
}) async {
  final theme = giftThemeFor(gift.template);
  await showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GiftCardVisual(
              theme: theme,
              amountMinor: gift.amountMinor,
              fromName: fromName.split(' ').first,
              toName: toName.split(' ').first,
              message: gift.message,
              big: true,
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'You received ${money(gift.amountMinor)} 🎉',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: theme.from,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Thanks!'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class DhukutiScreen extends StatefulWidget {
  const DhukutiScreen({super.key});

  @override
  State<DhukutiScreen> createState() => _DhukutiScreenState();
}

class _DhukutiScreenState extends State<DhukutiScreen> {
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final pools = store.visibleDhukutiPools;
    final selectedId =
        store.selectedDhukutiPoolId ?? (pools.isEmpty ? null : pools.first.id);
    final selected = selectedId == null ? null : store.poolById(selectedId);

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoPane = constraints.maxWidth >= 1000;
        final list = AppScrollView(
          children: [
            ScreenHeader(
              title: 'Digital Dhukuti',
              subtitle:
                  'Transparent contribution scheduler and ledger. No credit, interest, investment return, or guaranteed payout claims.',
              icon: Icons.account_balance_wallet,
              action: FilledButton.icon(
                onPressed: () => showCreateDhukutiDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('New pool'),
              ),
            ),
            SectionPanel(
              title: 'Pools',
              child: pools.isEmpty
                  ? const EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'No Dhukuti pool',
                      body: 'Create one from an existing group.',
                    )
                  : Column(
                      children: [
                        for (final pool in pools)
                          ListTile(
                            selected: pool.id == selectedId,
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(
                              child: Icon(Icons.account_balance_wallet),
                            ),
                            title: Text(pool.name),
                            subtitle: Text(
                              '${money(pool.contributionAmountMinor)} ${pool.frequency} • ${enumLabel(pool.status)}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              setState(
                                () => store.selectedDhukutiPoolId = pool.id,
                              );
                            },
                          ),
                      ],
                    ),
            ),
          ],
        );
        final detail = selected == null
            ? const Center(
                child: EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Select a pool',
                  body: 'Dhukuti details appear here.',
                ),
              )
            : DhukutiDetail(pool: selected);
        if (twoPane) {
          return Row(
            children: [
              SizedBox(width: 390, child: list),
              const VerticalDivider(width: 1),
              Expanded(child: detail),
            ],
          );
        }
        return selected == null ? list : detail;
      },
    );
  }
}

class DhukutiDetail extends StatelessWidget {
  const DhukutiDetail({required this.pool, super.key});

  final DhukutiPool pool;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final members = store.membersForPool(pool.id);
    final cycles = store.dhukutiCycles
        .where((cycle) => cycle.poolId == pool.id)
        .toList();
    final contributions = store.contributionsForPool(pool.id);
    final myMember = members
        .where((member) => member.userId == store.currentUserId)
        .cast<DhukutiMember?>()
        .firstWhere((member) => member != null, orElse: () => null);
    final myDue = contributions
        .where(
          (item) =>
              item.userId == store.currentUserId &&
              item.status != ContributionStatus.paid,
        )
        .toList();

    return AppScrollView(
      children: [
        ScreenHeader(
          title: pool.name,
          subtitle:
              '${money(pool.contributionAmountMinor)} ${pool.frequency} • Current payout: ${store.nameOf(cycles.first.payoutRecipientId)}',
          icon: Icons.account_balance_wallet,
          action: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (myMember?.status == DhukutiMemberStatus.invited)
                FilledButton.icon(
                  onPressed: () => store.acceptDhukuti(pool.id),
                  icon: const Icon(Icons.check),
                  label: const Text('Accept'),
                ),
              if (myMember?.status == DhukutiMemberStatus.invited)
                OutlinedButton.icon(
                  onPressed: () => store.declineDhukuti(pool.id),
                  icon: const Icon(Icons.close),
                  label: const Text('Decline'),
                ),
              OutlinedButton.icon(
                onPressed: () => showEmergencyExitDialog(context, pool.id),
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Emergency exit'),
              ),
            ],
          ),
        ),
        ResponsiveWrap(
          children: [
            StatTile(
              label: 'Contribution',
              value: money(pool.contributionAmountMinor),
              icon: Icons.savings_outlined,
              tone: Tone.neutral,
            ),
            StatTile(
              label: 'Members',
              value: '${members.length}',
              icon: Icons.groups,
              tone: Tone.info,
            ),
            StatTile(
              label: 'Current cycle',
              value: enumLabel(cycles.first.status),
              icon: Icons.event_repeat,
              tone: cycles.first.status == DhukutiCycleStatus.atRisk
                  ? Tone.warning
                  : Tone.success,
            ),
            StatTile(
              label: 'Your unpaid dues',
              value: money(
                myDue.fold<int>(0, (sum, item) => sum + item.amountMinor),
              ),
              icon: Icons.notification_important_outlined,
              tone: myDue.isEmpty ? Tone.success : Tone.warning,
            ),
          ],
        ),
        SectionPanel(
          title: 'Payout Order',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final member in members)
                Chip(
                  avatar: UserAvatar(
                    user: store.userById(member.userId),
                    small: true,
                  ),
                  label: Text(
                    '${member.payoutOrder}. ${store.nameOf(member.userId)} • ${enumLabel(member.status)}',
                  ),
                ),
            ],
          ),
        ),
        SectionPanel(
          title: 'Contribution Schedule',
          child: Column(
            children: [
              for (final cycle in cycles)
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Text('${cycle.cycleNumber}')),
                  title: Text(
                    'Cycle ${cycle.cycleNumber}: payout to ${store.nameOf(cycle.payoutRecipientId)}',
                  ),
                  subtitle: Text(
                    '${dateLabel(cycle.dueDate)} • ${money(cycle.paidContributionTotalMinor)} of ${money(cycle.expectedContributionTotalMinor)}',
                  ),
                  trailing: StatusPill(
                    label: enumLabel(cycle.status),
                    tone: cycle.status == DhukutiCycleStatus.atRisk
                        ? Tone.warning
                        : Tone.neutral,
                  ),
                  children: [
                    for (final contribution in contributions.where(
                      (item) => item.cycleId == cycle.id,
                    ))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: UserAvatar(
                          user: store.userById(contribution.userId),
                          small: true,
                        ),
                        title: Text(store.nameOf(contribution.userId)),
                        subtitle: Text(dateLabel(contribution.dueDate)),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            StatusPill(
                              label: enumLabel(contribution.status),
                              tone:
                                  contribution.status == ContributionStatus.paid
                                  ? Tone.success
                                  : contribution.status ==
                                        ContributionStatus.late
                                  ? Tone.warning
                                  : Tone.neutral,
                            ),
                            if (contribution.userId == store.currentUserId &&
                                contribution.status != ContributionStatus.paid)
                              FilledButton(
                                onPressed: () => store.payDhukutiContribution(
                                  contribution.id,
                                ),
                                child: const Text('Pay'),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final reports = store.connections.expand((item) => item.reports).toList();
    final failedReview = store.payments
        .where((payment) => payment.status == PaymentStatus.failedReview)
        .toList();

    return AppScrollView(
      children: [
        ScreenHeader(
          title: 'Activity and Ops',
          subtitle:
              'Audit timeline, reminders, simulated push notifications, cache status, analytics, and lightweight admin review surfaces.',
          icon: Icons.history,
        ),
        ResponsiveWrap(
          children: [
            SectionPanel(
              title: 'Notifications',
              action: TextButton.icon(
                onPressed: store.markNotificationsRead,
                icon: const Icon(Icons.done_all),
                label: const Text('Mark read'),
              ),
              child: store.currentNotifications.isEmpty
                  ? const EmptyState(
                      icon: Icons.notifications_none,
                      title: 'No notifications',
                      body: 'Settlement nudges and Dhukuti dues appear here.',
                    )
                  : Column(
                      children: [
                        for (final notification
                            in store.currentNotifications.take(6))
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              notification.read
                                  ? Icons.notifications_none
                                  : Icons.notifications_active_outlined,
                            ),
                            title: Text(notification.title),
                            subtitle: Text(notification.body),
                            trailing: StatusPill(
                              label: notification.read ? 'Read' : 'Unread',
                              tone: notification.read
                                  ? Tone.neutral
                                  : Tone.info,
                            ),
                          ),
                      ],
                    ),
            ),
            SectionPanel(
              title: 'Prototype Controls',
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: store.pushPreviewEnabled,
                    onChanged: (_) => store.togglePushPreview(),
                    title: const Text('Push notification preview'),
                    subtitle: const Text(
                      'P2 push UX is simulated inside the Flutter app.',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: store.cacheWarm,
                    onChanged: (_) => store.refreshCache(),
                    title: const Text('Local cache projection'),
                    subtitle: const Text(
                      'Frontend cache mirrors the Redis-backed shape without backend infrastructure.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SectionPanel(
          title: 'Analytics Dashboard',
          child: ResponsiveWrap(
            children: [
              for (final entry in store.analytics.entries)
                StatTile(
                  label: enumLabel(entry.key),
                  value: '${entry.value}',
                  icon: Icons.query_stats,
                  tone: Tone.info,
                ),
            ],
          ),
        ),
        SectionPanel(
          title: 'Admin Review Queue',
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Connection reports'),
                subtitle: Text('${reports.length} open lightweight report(s)'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.warning_amber_outlined),
                title: const Text('Payment manual review'),
                subtitle: Text(
                  '${failedReview.length} failed_review transaction(s)',
                ),
              ),
              for (final request in store.emergencyExitRequests)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.exit_to_app),
                  title: Text(
                    '${store.nameOf(request.userId)} exit request • ${store.poolById(request.poolId).name}',
                  ),
                  subtitle: Text('${request.reason} • ${request.status}'),
                  trailing: request.status == 'requested'
                      ? FilledButton(
                          onPressed: () =>
                              store.approveEmergencyExit(request.id),
                          child: const Text('Approve'),
                        )
                      : StatusPill(label: request.status, tone: Tone.success),
                ),
            ],
          ),
        ),
        SectionPanel(
          title: 'Full Activity Log',
          child: ActivityList(items: store.visibleActivity),
        ),
      ],
    );
  }
}

class AppScrollView extends StatelessWidget {
  const AppScrollView({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: children.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) => children[index],
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.action,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final titleBlock = Row(
          children: [
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        );
        if (action == null) {
          return titleBlock;
        }
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleBlock, const SizedBox(height: 12), action!],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            action!,
          ],
        );
      },
    );
  }
}

class SectionPanel extends StatelessWidget {
  const SectionPanel({
    required this.title,
    required this.child,
    this.action,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class ResponsiveWrap extends StatelessWidget {
  const ResponsiveWrap({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1180
            ? 4
            : constraints.maxWidth >= 760
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final child in children)
              SizedBox(
                width: width.clamp(250, constraints.maxWidth).toDouble(),
                child: child,
              ),
          ],
        );
      },
    );
  }
}

enum Tone { neutral, success, warning, info, danger }

class StatTile extends StatelessWidget {
  const StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, tone);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.14),
            foregroundColor: color,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({required this.user, this.small = false, super.key});

  final AppUser user;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: small ? 12 : null,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      child: Text(
        user.avatar,
        style: TextStyle(
          fontSize: small ? 10 : null,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({required this.label, required this.tone, super.key});

  final String label;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class BalancePill extends StatelessWidget {
  const BalancePill({required this.amountMinor, super.key});

  final int amountMinor;

  @override
  Widget build(BuildContext context) {
    final label = amountMinor == 0
        ? 'Settled'
        : amountMinor > 0
        ? '+${money(amountMinor)}'
        : money(amountMinor);
    return StatusPill(
      label: label,
      tone: amountMinor == 0
          ? Tone.neutral
          : amountMinor > 0
          ? Tone.success
          : Tone.warning,
    );
  }
}

class FeatureChip extends StatelessWidget {
  const FeatureChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.check_circle_outline, size: 18),
      label: Text(label),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 36,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class ActivityList extends StatelessWidget {
  const ActivityList({required this.items, super.key});

  final List<ActivityLog> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.history_toggle_off,
        title: 'No activity',
        body: 'Actions appear here with timestamps and entity references.',
      );
    }
    return Column(
      children: [
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.timeline)),
            title: Text(item.title),
            subtitle: Text('${item.body}\n${dateLabel(item.createdAt)}'),
            isThreeLine: true,
          ),
      ],
    );
  }
}

class GroupActivitySummary extends StatelessWidget {
  const GroupActivitySummary({
    required this.groupId,
    required this.items,
    super.key,
  });

  final String groupId;
  final List<ActivityLog> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
        icon: Icons.history_toggle_off,
        title: 'No activity',
        body: 'Recent group activity appears here.',
      );
    }
    return Column(
      children: [
        for (final item in items) GroupActivityTile(item: item, compact: true),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => showGroupActivityDialog(context, groupId),
            icon: const Icon(Icons.history),
            label: const Text('View all activity'),
          ),
        ),
      ],
    );
  }
}

class GroupActivityTile extends StatelessWidget {
  const GroupActivityTile({
    required this.item,
    this.compact = false,
    super.key,
  });

  final ActivityLog item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final actor = item.actorId == null ? 'System' : store.nameOf(item.actorId!);
    final amount = activityAmount(store, item);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(activityIcon(item))),
      title: Text(activityDescription(store, item)),
      subtitle: Text(
        [
          activityTypeLabel(item),
          actor,
          dateTimeLabel(item.createdAt),
          if (amount != null) statementMoney(amount),
        ].join(' • '),
      ),
      isThreeLine: !compact,
    );
  }
}

Future<void> showGroupActivityDialog(
  BuildContext context,
  String groupId,
) async {
  final store = StoreScope.of(context);
  var filter = 'All';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final allItems = store.activityForGroup(groupId);
          final items = allItems
              .where(
                (item) => filter == 'All' || activityFilter(item) == filter,
              )
              .toList();
          return AlertDialog(
            title: Text('${store.groupById(groupId).name} Activity'),
            content: SizedBox(
              width: 760,
              height: math.min(560, MediaQuery.sizeOf(context).height * 0.68),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in const [
                        'All',
                        'Expenses',
                        'Settlements',
                        'Members',
                        'Adjustments',
                        'Gifts',
                      ])
                        ChoiceChip(
                          label: Text(option),
                          selected: filter == option,
                          onSelected: (_) => setState(() => filter = option),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: items.isEmpty
                        ? const EmptyState(
                            icon: Icons.filter_alt_off_outlined,
                            title: 'No matching activity',
                            body: 'Try a different activity filter.',
                          )
                        : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) =>
                                GroupActivityTile(item: items[index]),
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    },
  );
}

String activityTypeLabel(ActivityLog item) {
  return switch (activityFilter(item)) {
    'Expenses' => 'Expense',
    'Settlements' => 'Settlement',
    'Members' => 'Member',
    'Adjustments' => 'Adjustment',
    'Gifts' => 'Gift',
    _ => enumLabel(item.eventType),
  };
}

String activityFilter(ActivityLog item) {
  if (item.entityType.contains('expense') ||
      item.eventType.contains('expense')) {
    return 'Expenses';
  }
  if (item.entityType.contains('settlement') ||
      item.eventType.contains('settlement')) {
    return 'Settlements';
  }
  if (item.entityType.contains('member') || item.eventType.contains('member')) {
    return 'Members';
  }
  if (item.entityType.contains('adjustment') ||
      item.eventType.contains('adjustment')) {
    return 'Adjustments';
  }
  if (item.entityType.contains('gift') || item.eventType.contains('gift')) {
    return 'Gifts';
  }
  return 'Other';
}

IconData activityIcon(ActivityLog item) {
  return switch (activityFilter(item)) {
    'Expenses' => Icons.receipt_long,
    'Settlements' => Icons.payments,
    'Members' => Icons.group,
    'Adjustments' => Icons.tune,
    'Gifts' => Icons.card_giftcard,
    _ => Icons.timeline,
  };
}

String activityDescription(AppStore store, ActivityLog item) {
  final amount = activityAmount(store, item);
  if (item.eventType == 'settlement_paid' && amount != null) {
    return '${item.body.replaceAll(' via Sangai Pay.', '')}.';
  }
  if (item.eventType == 'expense_added') {
    return item.body;
  }
  if (item.eventType == 'adjustment_created' && amount != null) {
    return 'System applied ${statementMoney(amount)} adjustment.';
  }
  if (item.eventType == 'member_added') {
    return item.body.replaceAll(' joined ', ' was added to ');
  }
  if (item.eventType == 'member_removed') {
    return item.body;
  }
  return item.body;
}

int? activityAmount(AppStore store, ActivityLog item) {
  if (item.entityType == 'expense') {
    for (final expense in store.expenses) {
      if (expense.id == item.entityId) {
        return expense.totalMinor;
      }
    }
  }
  if (item.entityType == 'settlement') {
    for (final settlement in store.settlements) {
      if (settlement.id == item.entityId) {
        return settlement.amountMinor;
      }
    }
  }
  if (item.entityType == 'adjustment') {
    for (final adjustment in store.adjustments) {
      if (adjustment.id == item.entityId) {
        return adjustment.entries
            .where((entry) => entry.direction == 'credit')
            .fold<int>(0, (sum, entry) => sum + entry.amountMinor);
      }
    }
  }
  return null;
}

class _UserSwitcher extends StatelessWidget {
  const _UserSwitcher({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: store.currentUserId,
        borderRadius: BorderRadius.circular(8),
        items: [
          for (final user in store.users)
            DropdownMenuItem(
              value: user.id,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(user: user, small: true),
                  const SizedBox(width: 8),
                  Text(user.displayName.split(' ').first),
                ],
              ),
            ),
        ],
        onChanged: (value) {
          if (value != null) {
            store.switchUser(value);
          }
        },
      ),
    );
  }
}

Color toneColor(BuildContext context, Tone tone) {
  final scheme = Theme.of(context).colorScheme;
  return switch (tone) {
    Tone.success => const Color(0xFF178C5B),
    Tone.warning => const Color(0xFFB56A12),
    Tone.info => scheme.tertiary,
    Tone.danger => scheme.error,
    Tone.neutral => scheme.onSurfaceVariant,
  };
}

IconData iconForCategory(GroupCategory category) {
  return switch (category) {
    GroupCategory.festival => Icons.celebration,
    GroupCategory.trek => Icons.landscape_outlined,
    GroupCategory.bhoj => Icons.restaurant,
    GroupCategory.travel => Icons.luggage,
    GroupCategory.event => Icons.event,
    GroupCategory.household => Icons.home_outlined,
    GroupCategory.apartment => Icons.apartment,
    GroupCategory.custom => Icons.category_outlined,
  };
}

String payerSummary(AppStore store, Expense expense) {
  if (expense.payers.isEmpty) {
    return store.nameOf(expense.payerId);
  }
  return expense.payers
      .map(
        (payer) => '${store.nameOf(payer.userId)} ${money(payer.amountMinor)}',
      )
      .join(' + ');
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class _ScanQrDialog extends StatefulWidget {
  const _ScanQrDialog({required this.store, required this.onResult});

  final AppStore store;
  final ValueChanged<String> onResult;

  @override
  State<_ScanQrDialog> createState() => _ScanQrDialogState();
}

class _ScanQrDialogState extends State<_ScanQrDialog> {
  static const _scannerMethodChannel = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/method',
  );

  late final MobileScannerController _scannerController =
      MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        formats: const [BarcodeFormat.qrCode],
      );

  bool _handlingScan = false;
  bool _scannerReady = false;
  String? _message;
  String? _scannerIssue;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareScanner());
  }

  @override
  void dispose() {
    unawaited(_scannerController.dispose());
    super.dispose();
  }

  Future<void> _prepareScanner() async {
    if (kIsWeb && !_hasSecureWebCameraContext()) {
      if (!mounted) {
        return;
      }
      setState(() {
        _scannerReady = false;
        _scannerIssue =
            'Camera scanning on web needs HTTPS or localhost. Run the web app from a secure origin.';
      });
      return;
    }

    if (!kIsWeb) {
      try {
        await _scannerMethodChannel.invokeMethod<int>('state');
      } on MissingPluginException {
        if (!mounted) {
          return;
        }
        setState(() {
          _scannerReady = false;
          _scannerIssue =
              'The QR scanner plugin is not registered in this app process. Stop the app completely, then run flutter clean, flutter pub get, and launch again.';
        });
        return;
      } on PlatformException catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _scannerReady = false;
          _scannerIssue =
              error.message ?? 'The camera permission check failed.';
        });
        return;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _scannerReady = true;
      _scannerIssue = null;
    });
  }

  bool _hasSecureWebCameraContext() {
    final uri = Uri.base;
    final host = uri.host.toLowerCase();
    return uri.scheme == 'https' ||
        host == 'localhost' ||
        host == '::1' ||
        host.startsWith('127.');
  }

  void _handleDetectError(Object error, StackTrace stackTrace) {
    if (!mounted) {
      return;
    }
    setState(() {
      _scannerReady = false;
      _scannerIssue = switch (error) {
        MissingPluginException() =>
          'The QR scanner plugin is not registered in this app process. Stop the app completely, then run flutter clean, flutter pub get, and launch again.',
        MobileScannerException(:final errorDetails, :final errorCode) =>
          errorDetails?.message ?? errorCode.message,
        PlatformException(:final message) =>
          message ?? 'The camera scanner could not start.',
        _ => 'The camera scanner could not start.',
      };
    });
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_handlingScan) {
      return;
    }
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue ?? barcode.displayValue;
      if (value != null && value.trim().isNotEmpty) {
        unawaited(_submit(value));
        return;
      }
    }
  }

  Future<void> _submit(String value) async {
    final code = value.trim();
    if (code.isEmpty) {
      setState(() => _message = 'That QR invite code is not valid.');
      return;
    }
    if (_handlingScan) {
      return;
    }

    setState(() {
      _handlingScan = true;
      _message = null;
    });

    final validationError = widget.store.qrInviteValidationError(code);
    if (validationError != null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _handlingScan = false;
        _message = validationError;
      });
      return;
    }

    final message = widget.store.acceptQrInvite(code);
    try {
      await _scannerController.stop();
    } catch (_) {
      // The scanner may already be stopped while the dialog is closing.
    }
    if (!mounted) {
      return;
    }
    Navigator.pop(context);
    widget.onResult(message);
  }

  Widget _buildScannerError(
    BuildContext context,
    MobileScannerException error,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final details = error.errorDetails?.message ?? error.errorCode.name;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_photography_outlined, color: colorScheme.error),
              const SizedBox(height: 8),
              Text(
                details,
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerIssue(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final issue = _scannerIssue;
    return ColoredBox(
      color: colorScheme.surfaceContainerHighest,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: issue == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.no_photography_outlined,
                      color: colorScheme.error,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      issue,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewSize = MediaQuery.sizeOf(context);
    final scannerSize = math
        .min(360.0, math.min(viewSize.width - 96, viewSize.height * 0.48))
        .clamp(220.0, 360.0);
    return AlertDialog(
      title: const Text('Scan QR'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: scannerSize.toDouble(),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_scannerReady)
                        MobileScanner(
                          controller: _scannerController,
                          fit: BoxFit.cover,
                          onDetect: _handleCapture,
                          onDetectError: _handleDetectError,
                          errorBuilder: _buildScannerError,
                          placeholderBuilder: (context) => ColoredBox(
                            color: colorScheme.surfaceContainerHighest,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        )
                      else
                        _buildScannerIssue(context),
                      IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: colorScheme.primary,
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

Future<void> showScanQrDialog(BuildContext context) async {
  final store = StoreScope.of(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => _ScanQrDialog(
      store: store,
      onResult: (message) => showSnack(context, message),
    ),
  );
}

Future<void> showMyQrDialog(BuildContext context) async {
  final store = StoreScope.of(context);
  final code = store.qrInviteCodeFor(store.currentUser);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('My QR'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InviteQrView(
                code: code,
                label: store.currentUser.displayName,
                size: 220,
              ),
              const SizedBox(height: 16),
              Text(
                store.currentUser.displayName,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

Future<void> showCreateGroupDialog(BuildContext context) async {
  final store = StoreScope.of(context);
  final name = TextEditingController(text: 'Office Bhoj');
  var category = GroupCategory.bhoj;
  final selected = <String>{
    for (final user in store.activeConnectionUsers()) user.id,
  };
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final connections = store.activeConnectionUsers();
          return AlertDialog(
            title: const Text('Create Group'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Group name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<GroupCategory>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final item in GroupCategory.values)
                          DropdownMenuItem(
                            value: item,
                            child: Text(enumLabel(item)),
                          ),
                      ],
                      onChanged: (value) =>
                          setState(() => category = value ?? category),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Members',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final user in connections)
                          FilterChip(
                            selected: selected.contains(user.id),
                            avatar: UserAvatar(user: user, small: true),
                            label: Text(user.displayName),
                            onSelected: (checked) {
                              setState(() {
                                checked
                                    ? selected.add(user.id)
                                    : selected.remove(user.id);
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  store.createGroup(
                    name: name.text.trim().isEmpty
                        ? 'New Group'
                        : name.text.trim(),
                    category: category,
                    memberIds: selected.toList(),
                  );
                  Navigator.pop(dialogContext);
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    },
  );
  name.dispose();
}

Future<void> showAddMemberDialog(BuildContext context, String groupId) async {
  final store = StoreScope.of(context);
  final existing = store
      .membersForGroup(groupId, activeOnly: true)
      .map((member) => member.userId)
      .toSet();
  final candidates = store
      .activeConnectionUsers()
      .where((user) => !existing.contains(user.id))
      .toList();
  String? selected = candidates.isEmpty ? null : candidates.first.id;
  var role = MemberRole.member;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Member'),
            content: SizedBox(
              width: 420,
              child: candidates.isEmpty
                  ? const EmptyState(
                      icon: Icons.person_off_outlined,
                      title: 'No eligible connections',
                      body: 'Only active connections can be invited.',
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: selected,
                          decoration: const InputDecoration(
                            labelText: 'Connection',
                          ),
                          items: [
                            for (final user in candidates)
                              DropdownMenuItem(
                                value: user.id,
                                child: Text(user.displayName),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => selected = value),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<MemberRole>(
                          initialValue: role,
                          decoration: const InputDecoration(labelText: 'Role'),
                          items: [
                            for (final item in MemberRole.values)
                              DropdownMenuItem(
                                value: item,
                                child: Text(enumLabel(item)),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => role = value ?? role),
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selected == null
                    ? null
                    : () {
                        store.addGroupMember(groupId, selected!, role);
                        Navigator.pop(dialogContext);
                      },
                child: const Text('Add'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showRoleDialog(
  BuildContext context,
  String groupId,
  GroupMember member,
) async {
  final store = StoreScope.of(context);
  var role = member.role;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Role for ${store.nameOf(member.userId)}'),
            content: DropdownButtonFormField<MemberRole>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: [
                for (final item in MemberRole.values)
                  DropdownMenuItem(value: item, child: Text(enumLabel(item))),
              ],
              onChanged: (value) => setState(() => role = value ?? role),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  store.updateMemberRole(groupId, member.userId, role);
                  Navigator.pop(dialogContext);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> showAddExpenseDialog(BuildContext context, String groupId) async {
  final store = StoreScope.of(context);
  final members = store.membersForGroup(groupId, activeOnly: true);
  if (members.isEmpty ||
      !store.isActiveGroupMember(groupId, store.currentUserId)) {
    showSnack(context, 'Only active group members can add expenses.');
    return;
  }

  final title = TextEditingController(text: 'Shared expense');
  final amount = TextEditingController(text: '1200');
  final note = TextEditingController();
  final receipt = TextEditingController();
  var splitMode = SplitMode.equal;
  final payerRows = <_PayerDraft>[
    _PayerDraft(userId: store.currentUserId, amountText: amount.text),
  ];
  final participants = <String>{for (final member in members) member.userId};
  final custom = <String, String>{};
  final percentages = <String, String>{};
  final shares = <String, String>{};
  var equalPreview = <String, int>{};
  var parsedItems = parseControlledReceipt('');
  final itemAssignments = <int, String>{};

  void refreshEqualPreview() {
    final ids = participants.toList();
    final amounts = equalShares(parseMoneyToMinor(amount.text), ids);
    equalPreview = {
      for (var index = 0; index < ids.length; index++)
        ids[index]: amounts[index],
    };
  }

  void syncSinglePayerToTotal() {
    if (payerRows.length == 1) {
      payerRows.first.amount.text = amount.text;
    }
  }

  refreshEqualPreview();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          final total = parseMoneyToMinor(amount.text);
          final selectedParticipants = participants.toList();
          final payerAmounts = <String, int>{};
          var hasMissingPayer = false;
          var hasZeroPayerAmount = false;
          for (final payer in payerRows) {
            final paid = parseMoneyToMinor(payer.amount.text);
            if (payer.userId == null) {
              hasMissingPayer = true;
            }
            if (paid <= 0) {
              hasZeroPayerAmount = true;
            }
            if (payer.userId != null && paid > 0) {
              payerAmounts[payer.userId!] = paid;
            }
          }
          final payerTotal = payerAmounts.values.fold<int>(
            0,
            (sum, value) => sum + value,
          );
          final splitPreview = _splitPreviewFor(
            total: total,
            participants: selectedParticipants,
            splitMode: splitMode,
            equalPreview: equalPreview,
            custom: custom,
            percentages: percentages,
            shares: shares,
            receiptItems: splitMode == SplitMode.item
                ? parseControlledReceipt(receipt.text)
                : parsedItems,
            itemAssignments: itemAssignments,
          );
          final splitTotal = splitPreview.values.fold<int>(
            0,
            (sum, value) => sum + value,
          );
          final payerError = _payerValidationMessage(
            total: total,
            payerTotal: payerTotal,
            hasMissingPayer: hasMissingPayer,
            hasZeroPayerAmount: hasZeroPayerAmount,
          );
          final splitError = selectedParticipants.isEmpty
              ? 'Choose at least one participant.'
              : splitTotal != total
              ? 'Participant split amounts must add up to the total expense.'
              : null;
          final readyToSave =
              total > 0 &&
              payerError == null &&
              splitError == null &&
              splitPreview.isNotEmpty;

          return AlertDialog(
            title: const Text('Add Expense'),
            content: SizedBox(
              width: 780,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialogSection(
                      title: 'Participants',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final id in selectedParticipants)
                                InputChip(
                                  avatar: UserAvatar(
                                    user: store.userById(id),
                                    small: true,
                                  ),
                                  label: Text(store.nameOf(id)),
                                  onDeleted: () {
                                    setState(() {
                                      participants.remove(id);
                                      custom.remove(id);
                                      percentages.remove(id);
                                      shares.remove(id);
                                      refreshEqualPreview();
                                    });
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final member in members)
                                FilterChip(
                                  selected: participants.contains(
                                    member.userId,
                                  ),
                                  avatar: UserAvatar(
                                    user: store.userById(member.userId),
                                    small: true,
                                  ),
                                  label: Text(store.nameOf(member.userId)),
                                  onSelected: (checked) {
                                    setState(() {
                                      checked
                                          ? participants.add(member.userId)
                                          : participants.remove(member.userId);
                                      refreshEqualPreview();
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DialogSection(
                      title: 'Expense details',
                      child: Column(
                        children: [
                          TextField(
                            controller: title,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: amount,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Total amount',
                              prefixText: 'NPR ',
                            ),
                            onChanged: (_) {
                              setState(() {
                                syncSinglePayerToTotal();
                                refreshEqualPreview();
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: note,
                            decoration: const InputDecoration(
                              labelText: 'Note',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DialogSection(
                      title: 'Who paid?',
                      child: Column(
                        children: [
                          for (var index = 0; index < payerRows.length; index++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: index == payerRows.length - 1 ? 0 : 8,
                              ),
                              child: _PayerInputRow(
                                members: members,
                                payer: payerRows[index],
                                selectedByOtherRows: {
                                  for (
                                    var other = 0;
                                    other < payerRows.length;
                                    other++
                                  )
                                    if (other != index &&
                                        payerRows[other].userId != null)
                                      payerRows[other].userId!,
                                },
                                canRemove: index > 0,
                                onChanged: () => setState(() {}),
                                onRemove: () {
                                  setState(() {
                                    final removed = payerRows.removeAt(index);
                                    removed.dispose();
                                  });
                                },
                              ),
                            ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: payerRows.length >= members.length
                                  ? null
                                  : () {
                                      setState(() {
                                        final selected = payerRows
                                            .map((payer) => payer.userId)
                                            .whereType<String>()
                                            .toSet();
                                        final next = members
                                            .map((member) => member.userId)
                                            .firstWhere(
                                              (id) => !selected.contains(id),
                                              orElse: () =>
                                                  members.first.userId,
                                            );
                                        payerRows.add(
                                          _PayerDraft(userId: next),
                                        );
                                      });
                                    },
                              icon: const Icon(Icons.add),
                              label: const Text('Add another payer'),
                            ),
                          ),
                          if (payerError != null) ...[
                            const SizedBox(height: 8),
                            _ValidationText(payerError),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DialogSection(
                      title: 'Split mode',
                      child: DropdownButtonFormField<SplitMode>(
                        initialValue: splitMode,
                        decoration: const InputDecoration(
                          labelText: 'Split mode',
                        ),
                        items: [
                          for (final item in SplitMode.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(enumLabel(item)),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => splitMode = value ?? splitMode),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DialogSection(
                      title: 'Split preview',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (splitMode == SplitMode.equal)
                            _AmountPreview(
                              title: 'Calculated equal split',
                              amounts: equalPreview,
                            ),
                          if (splitMode == SplitMode.custom)
                            _AmountGrid(
                              ids: selectedParticipants,
                              label: 'Custom amount',
                              values: custom,
                              suffix: 'NPR',
                              onChanged: () => setState(() {}),
                            ),
                          if (splitMode == SplitMode.percentage)
                            _AmountGrid(
                              ids: selectedParticipants,
                              label: 'Percentage',
                              values: percentages,
                              suffix: '%',
                              onChanged: () => setState(() {}),
                            ),
                          if (splitMode == SplitMode.shares)
                            _AmountGrid(
                              ids: selectedParticipants,
                              label: 'Share units',
                              values: shares,
                              suffix: 'x',
                              onChanged: () => setState(() {}),
                            ),
                          if (splitMode == SplitMode.item) ...[
                            TextField(
                              controller: receipt,
                              minLines: 3,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                labelText: 'Controlled receipt text',
                                hintText: 'Khasi meat 6000\nMasala 650',
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  parsedItems = parseControlledReceipt(
                                    receipt.text,
                                  );
                                  amount.text =
                                      (parsedItems.fold<int>(
                                                0,
                                                (sum, item) =>
                                                    sum + item.amountMinor,
                                              ) /
                                              100)
                                          .toStringAsFixed(0);
                                  syncSinglePayerToTotal();
                                  refreshEqualPreview();
                                });
                              },
                              icon: const Icon(Icons.document_scanner_outlined),
                              label: const Text('Parse receipt'),
                            ),
                            const SizedBox(height: 8),
                            for (var i = 0; i < parsedItems.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: DropdownButtonFormField<String>(
                                  initialValue: itemAssignments[i] ?? 'all',
                                  decoration: InputDecoration(
                                    labelText:
                                        '${parsedItems[i].label} • ${statementMoney(parsedItems[i].amountMinor)}',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'all',
                                      child: Text('Shared by all selected'),
                                    ),
                                    for (final id in selectedParticipants)
                                      DropdownMenuItem(
                                        value: id,
                                        child: Text(store.nameOf(id)),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    setState(
                                      () => itemAssignments[i] = value ?? 'all',
                                    );
                                  },
                                ),
                              ),
                          ],
                          if (splitError != null) ...[
                            const SizedBox(height: 8),
                            _ValidationText(splitError),
                          ],
                          const SizedBox(height: 8),
                          _ExpenseSplitPreview(
                            payerAmounts: payerAmounts,
                            participantShares: splitPreview,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _SaveSummary(
                      expenseTotal: total,
                      payerTotal: payerTotal,
                      splitTotal: splitTotal,
                      ready: readyToSave,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: readyToSave
                    ? () {
                        try {
                          final ids = participants.toList();
                          final parsed = splitMode == SplitMode.item
                              ? parseControlledReceipt(receipt.text)
                              : <ParsedReceiptItem>[];
                          store.addExpense(
                            groupId: groupId,
                            title: title.text.trim().isEmpty
                                ? 'Shared expense'
                                : title.text.trim(),
                            totalMinor: total == 0 && parsed.isNotEmpty
                                ? parsed.fold<int>(
                                    0,
                                    (sum, item) => sum + item.amountMinor,
                                  )
                                : total,
                            payerId: payerAmounts.keys.first,
                            payerAmounts: payerAmounts,
                            category: store.groupById(groupId).category.name,
                            splitMode: splitMode,
                            participantIds: ids,
                            note: note.text,
                            equalAmounts: splitMode == SplitMode.equal
                                ? equalPreview
                                : null,
                            customAmounts: custom.map(
                              (key, value) =>
                                  MapEntry(key, parseMoneyToMinor(value)),
                            ),
                            percentages: percentages.map(
                              (key, value) =>
                                  MapEntry(key, double.tryParse(value) ?? 0),
                            ),
                            shareUnits: shares.map(
                              (key, value) =>
                                  MapEntry(key, int.tryParse(value) ?? 1),
                            ),
                            receiptItems: parsed,
                            itemAssignments: {
                              for (final entry in itemAssignments.entries)
                                entry.key: entry.value == 'all'
                                    ? ids
                                    : <String>[entry.value],
                            },
                          );
                          Navigator.pop(dialogContext);
                        } on ArgumentError catch (error) {
                          showSnack(context, error.message.toString());
                        }
                      }
                    : null,
                child: const Text('Save expense'),
              ),
            ],
          );
        },
      );
    },
  );

  title.dispose();
  amount.dispose();
  note.dispose();
  receipt.dispose();
  for (final payer in payerRows) {
    payer.dispose();
  }
}

class _PayerDraft {
  _PayerDraft({this.userId, String amountText = ''})
    : amount = TextEditingController(text: amountText);

  String? userId;
  final TextEditingController amount;

  void dispose() {
    amount.dispose();
  }
}

class _DialogSection extends StatelessWidget {
  const _DialogSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _PayerInputRow extends StatelessWidget {
  const _PayerInputRow({
    required this.members,
    required this.payer,
    required this.selectedByOtherRows,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final List<GroupMember> members;
  final _PayerDraft payer;
  final Set<String> selectedByOtherRows;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final available = members
        .where(
          (member) =>
              member.userId == payer.userId ||
              !selectedByOtherRows.contains(member.userId),
        )
        .toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final selector = DropdownButtonFormField<String>(
          initialValue: payer.userId,
          decoration: const InputDecoration(labelText: 'Who paid?'),
          items: [
            for (final member in available)
              DropdownMenuItem(
                value: member.userId,
                child: Text(store.nameOf(member.userId)),
              ),
          ],
          onChanged: (value) {
            payer.userId = value;
            onChanged();
          },
        );
        final amount = TextField(
          controller: payer.amount,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount paid',
            prefixText: 'NPR ',
          ),
          onChanged: (_) => onChanged(),
        );
        final remove = IconButton(
          tooltip: 'Remove payer',
          onPressed: canRemove ? onRemove : null,
          icon: const Icon(Icons.close),
        );
        if (compact) {
          return Column(
            children: [
              selector,
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: amount),
                  remove,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: selector),
            const SizedBox(width: 8),
            Expanded(child: amount),
            remove,
          ],
        );
      },
    );
  }
}

class _ValidationText extends StatelessWidget {
  const _ValidationText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        color: Theme.of(context).colorScheme.error,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ExpenseSplitPreview extends StatelessWidget {
  const _ExpenseSplitPreview({
    required this.payerAmounts,
    required this.participantShares,
  });

  final Map<String, int> payerAmounts;
  final Map<String, int> participantShares;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final people = <String>{...payerAmounts.keys, ...participantShares.keys};
    if (people.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No preview yet',
        body: 'Select participants and payer amounts to preview balances.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in payerAmounts.entries)
              Chip(
                avatar: UserAvatar(
                  user: store.userById(entry.key),
                  small: true,
                ),
                label: Text(
                  '${store.nameOf(entry.key)} paid ${statementMoney(entry.value)}',
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in participantShares.entries)
              Chip(
                avatar: UserAvatar(
                  user: store.userById(entry.key),
                  small: true,
                ),
                label: Text(
                  '${store.nameOf(entry.key)} share ${statementMoney(entry.value)}',
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final id in people)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              _netPreviewLine(store, id, payerAmounts, participantShares),
            ),
          ),
      ],
    );
  }
}

class _SaveSummary extends StatelessWidget {
  const _SaveSummary({
    required this.expenseTotal,
    required this.payerTotal,
    required this.splitTotal,
    required this.ready,
  });

  final int expenseTotal;
  final int payerTotal;
  final int splitTotal;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final tone = ready ? Tone.success : Tone.warning;
    final color = toneColor(context, tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Expense total: ${statementMoney(expenseTotal)}'),
          Text('Total paid by payers: ${statementMoney(payerTotal)}'),
          Text('Total split among participants: ${statementMoney(splitTotal)}'),
          Text(
            ready
                ? 'Status: Ready to save'
                : 'Status: Fix totals before saving',
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

Map<String, int> _splitPreviewFor({
  required int total,
  required List<String> participants,
  required SplitMode splitMode,
  required Map<String, int> equalPreview,
  required Map<String, String> custom,
  required Map<String, String> percentages,
  required Map<String, String> shares,
  required List<ParsedReceiptItem> receiptItems,
  required Map<int, String> itemAssignments,
}) {
  if (participants.isEmpty) {
    return <String, int>{};
  }
  try {
    return switch (splitMode) {
      SplitMode.equal => {
        for (final id in participants) id: equalPreview[id] ?? 0,
      },
      SplitMode.custom => {
        for (final id in participants) id: parseMoneyToMinor(custom[id] ?? ''),
      },
      SplitMode.percentage => _amountMapFromList(
        participants,
        percentageShares(total, [
          for (final id in participants)
            double.tryParse(percentages[id] ?? '') ?? 0,
        ]),
      ),
      SplitMode.shares => _amountMapFromList(
        participants,
        unitShares(total, [
          for (final id in participants) int.tryParse(shares[id] ?? '') ?? 1,
        ]),
      ),
      SplitMode.item => _itemSplitPreview(
        total,
        participants,
        receiptItems,
        itemAssignments,
      ),
    };
  } on ArgumentError {
    return <String, int>{};
  }
}

Map<String, int> _amountMapFromList(List<String> ids, List<int> amounts) {
  return {
    for (var index = 0; index < ids.length; index++) ids[index]: amounts[index],
  };
}

Map<String, int> _itemSplitPreview(
  int total,
  List<String> participants,
  List<ParsedReceiptItem> receiptItems,
  Map<int, String> itemAssignments,
) {
  final preview = <String, int>{for (final id in participants) id: 0};
  for (var itemIndex = 0; itemIndex < receiptItems.length; itemIndex++) {
    final assigned = itemAssignments[itemIndex];
    final users = assigned == null || assigned == 'all'
        ? participants
        : <String>[assigned];
    final splits = equalShares(receiptItems[itemIndex].amountMinor, users);
    for (var index = 0; index < users.length; index++) {
      preview[users[index]] = (preview[users[index]] ?? 0) + splits[index];
    }
  }
  final current = preview.values.fold<int>(0, (sum, value) => sum + value);
  final delta = total - current;
  if (delta != 0 && participants.isNotEmpty) {
    final adjustments = equalShares(delta.abs(), participants);
    for (var index = 0; index < participants.length; index++) {
      preview[participants[index]] =
          (preview[participants[index]] ?? 0) +
          (delta.isNegative ? -adjustments[index] : adjustments[index]);
    }
  }
  return preview;
}

String? _payerValidationMessage({
  required int total,
  required int payerTotal,
  required bool hasMissingPayer,
  required bool hasZeroPayerAmount,
}) {
  if (hasMissingPayer) {
    return 'Please select who paid.';
  }
  if (hasZeroPayerAmount) {
    return 'Enter the amount paid by each payer.';
  }
  final delta = total - payerTotal;
  if (delta > 0) {
    return 'Paid amount is ${statementMoney(delta)} less than the total expense.';
  }
  if (delta < 0) {
    return 'Paid amount is ${statementMoney(delta.abs())} more than the total expense.';
  }
  return null;
}

String _netPreviewLine(
  AppStore store,
  String userId,
  Map<String, int> payerAmounts,
  Map<String, int> participantShares,
) {
  final paid = payerAmounts[userId] ?? 0;
  final share = participantShares[userId] ?? 0;
  final net = paid - share;
  final name = store.nameOf(userId);
  if (paid > 0 && share > 0 && net > 0) {
    return '$name paid ${statementMoney(paid)} and owes ${statementMoney(share)}, so they get back ${statementMoney(net)}.';
  }
  if (paid > 0 && share > 0 && net < 0) {
    return '$name paid ${statementMoney(paid)} and owes ${statementMoney(share)}, so they still owe ${statementMoney(net.abs())}.';
  }
  if (paid > 0 && share == 0) {
    return '$name paid ${statementMoney(paid)} and did not participate, so they get back ${statementMoney(paid)}.';
  }
  if (paid == 0 && share > 0) {
    return '$name participated and owes ${statementMoney(share)}.';
  }
  return '$name is balanced for this expense.';
}

class _AmountGrid extends StatelessWidget {
  const _AmountGrid({
    required this.ids,
    required this.label,
    required this.values,
    required this.suffix,
    this.onChanged,
  });

  final List<String> ids;
  final String label;
  final Map<String, String> values;
  final String suffix;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ResponsiveWrap(
        children: [
          for (final id in ids)
            TextFormField(
              initialValue: values[id],
              decoration: InputDecoration(
                labelText: '${store.nameOf(id)} $label',
                suffixText: suffix,
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                values[id] = value;
                onChanged?.call();
              },
            ),
        ],
      ),
    );
  }
}

class _AmountPreview extends StatelessWidget {
  const _AmountPreview({required this.title, required this.amounts});

  final String title;
  final Map<String, int> amounts;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in amounts.entries)
                Chip(
                  avatar: UserAvatar(
                    user: store.userById(entry.key),
                    small: true,
                  ),
                  label: Text(
                    '${store.nameOf(entry.key)}: ${money(entry.value)}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showEditExpenseDialog(
  BuildContext context,
  Expense expense,
) async {
  final store = StoreScope.of(context);
  final title = TextEditingController(text: expense.title);
  final note = TextEditingController(text: expense.note);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Edit Expense'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              if (expense.lockedAt != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'This expense is locked by a paid settlement. Saving will show an adjustment-required notice.',
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final ok = store.editExpenseTitle(
                expense.id,
                title.text.trim().isEmpty ? expense.title : title.text.trim(),
                note.text,
              );
              Navigator.pop(dialogContext);
              showSnack(
                context,
                ok ? 'Expense updated.' : 'Adjustment required.',
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
  title.dispose();
  note.dispose();
}

Future<void> showAdjustmentDialog(
  BuildContext context,
  String groupId,
  String defaultCreditUserId,
) async {
  final store = StoreScope.of(context);
  final members = store.membersForGroup(groupId);
  var creditUserId = defaultCreditUserId;
  var debitUserId = store.currentUserId;
  final amount = TextEditingController(text: '100');
  final reason = TextEditingController(text: 'Locked expense correction');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Zero-sum Adjustment'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: creditUserId,
                    decoration: const InputDecoration(labelText: 'Credit'),
                    items: [
                      for (final member in members)
                        DropdownMenuItem(
                          value: member.userId,
                          child: Text(store.nameOf(member.userId)),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => creditUserId = value ?? creditUserId),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: debitUserId,
                    decoration: const InputDecoration(labelText: 'Debit'),
                    items: [
                      for (final member in members)
                        DropdownMenuItem(
                          value: member.userId,
                          child: Text(store.nameOf(member.userId)),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => debitUserId = value ?? debitUserId),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amount,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'NPR ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  try {
                    store.createZeroSumAdjustment(
                      groupId: groupId,
                      creditUserId: creditUserId,
                      debitUserId: debitUserId,
                      amountMinor: parseMoneyToMinor(amount.text),
                      reason: reason.text,
                    );
                    Navigator.pop(dialogContext);
                  } on ArgumentError catch (error) {
                    showSnack(context, error.message.toString());
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    },
  );
  amount.dispose();
  reason.dispose();
}

Future<void> showStatementDialog(BuildContext context, String groupId) async {
  final store = StoreScope.of(context);
  final group = store.groupById(groupId);
  final statement = GroupStatementData.fromStore(store, groupId);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final size = MediaQuery.sizeOf(dialogContext);
      return AlertDialog(
        title: Text('${group.name} Statement'),
        content: SizedBox(
          width: math.min(1100, size.width * 0.92),
          height: math.min(560, size.height * 0.58),
          child: GroupStatementTable(statement: statement),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: statement.toCsv()));
              showSnack(context, 'CSV statement copied.');
            },
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download CSV'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: statement.toPrintableText()),
              );
              showSnack(context, 'Printable statement copied for PDF export.');
            },
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Download PDF'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}

class GroupStatementData {
  GroupStatementData({
    required this.rows,
    required this.totalGroupExpenses,
    required this.totalPaidByUser,
    required this.totalUserShare,
    required this.totalSettled,
    required this.remainingBalance,
  });

  final List<GroupStatementRow> rows;
  final int totalGroupExpenses;
  final int totalPaidByUser;
  final int totalUserShare;
  final int totalSettled;
  final int remainingBalance;

  factory GroupStatementData.fromStore(AppStore store, String groupId) {
    final userId = store.currentUserId;
    final rows = <GroupStatementRow>[];
    var totalGroupExpenses = 0;
    var totalPaidByUser = 0;
    var totalUserShare = 0;
    var totalSettled = 0;

    for (final expense in store.expenses.where(
      (item) => item.groupId == groupId,
    )) {
      final userShare = expense.shares
          .where((share) => share.userId == userId)
          .fold<int>(0, (sum, share) => sum + share.amountMinor);
      final userPaid = expense.payers.isEmpty
          ? (expense.payerId == userId ? expense.totalMinor : 0)
          : expense.payers
                .where((payer) => payer.userId == userId)
                .fold<int>(0, (sum, payer) => sum + payer.amountMinor);
      if (expense.status == ExpenseStatus.active) {
        totalGroupExpenses += expense.totalMinor;
        totalPaidByUser += userPaid;
        totalUserShare += userShare;
      }
      rows.add(
        GroupStatementRow(
          date: expense.createdAt,
          type: 'Expense',
          description: expense.title,
          paidBy: payerSummary(store, expense),
          participants: '${expense.shares.length} members',
          totalAmountMinor: expense.totalMinor,
          splitMode: enumLabel(expense.splitMode),
          yourShareMinor: userShare,
          status: enumLabel(expense.status),
        ),
      );
    }

    for (final settlement in store.settlements.where(
      (item) => item.groupId == groupId,
    )) {
      if (settlement.status == PaymentStatus.paid &&
          (settlement.payerId == userId || settlement.payeeId == userId)) {
        totalSettled += settlement.amountMinor;
      }
      rows.add(
        GroupStatementRow(
          date: settlement.paidAt ?? settlement.createdAt,
          type: 'Settlement',
          description:
              '${store.nameOf(settlement.payerId)} paid ${store.nameOf(settlement.payeeId)}',
          paidBy: store.nameOf(settlement.payerId),
          participants: store.nameOf(settlement.payeeId),
          totalAmountMinor: settlement.amountMinor,
          splitMode: 'Settlement',
          yourShareMinor: 0,
          status: enumLabel(settlement.status),
        ),
      );
    }

    for (final adjustment in store.adjustments.where(
      (item) => item.groupId == groupId,
    )) {
      final amount = adjustment.entries
          .where((entry) => entry.direction == 'credit')
          .fold<int>(0, (sum, entry) => sum + entry.amountMinor);
      final userImpact = adjustment.entries
          .where((entry) => entry.userId == userId)
          .fold<int>(
            0,
            (sum, entry) =>
                sum +
                (entry.direction == 'credit'
                    ? entry.amountMinor
                    : -entry.amountMinor),
          );
      totalUserShare += userImpact;
      rows.add(
        GroupStatementRow(
          date: adjustment.createdAt,
          type: 'Adjustment',
          description: adjustment.reason,
          paidBy: 'System',
          participants: '${adjustment.entries.length} members',
          totalAmountMinor: amount,
          splitMode: enumLabel(adjustment.adjustmentType),
          yourShareMinor: userImpact,
          status: 'Applied',
        ),
      );
    }

    rows.sort((a, b) => b.date.compareTo(a.date));
    return GroupStatementData(
      rows: rows,
      totalGroupExpenses: totalGroupExpenses,
      totalPaidByUser: totalPaidByUser,
      totalUserShare: totalUserShare,
      totalSettled: totalSettled,
      remainingBalance: store.balanceForUserInGroup(groupId, userId),
    );
  }

  String toCsv() {
    final buffer = StringBuffer();
    buffer.writeln(
      'Date,Type,Description,Paid By,Participants,Total Amount,Split Mode,Your Share,Status',
    );
    for (final row in rows) {
      buffer.writeln(
        [
          statementDate(row.date),
          row.type,
          row.description,
          row.paidBy,
          row.participants,
          statementMoney(row.totalAmountMinor),
          row.splitMode,
          statementMoney(row.yourShareMinor),
          row.status,
        ].map(_csvCell).join(','),
      );
    }
    buffer
      ..writeln()
      ..writeln('Total group expenses,${statementMoney(totalGroupExpenses)}')
      ..writeln('Total paid by user,${statementMoney(totalPaidByUser)}')
      ..writeln('Total user share,${statementMoney(totalUserShare)}')
      ..writeln('Total settled,${statementMoney(totalSettled)}')
      ..writeln('Remaining balance,${statementMoney(remainingBalance)}');
    return buffer.toString();
  }

  String toPrintableText() {
    final buffer = StringBuffer('Group Statement\n\n');
    for (final row in rows) {
      buffer.writeln(
        '${statementDate(row.date)} | ${row.type} | ${row.description} | ${row.paidBy} | ${row.participants} | ${statementMoney(row.totalAmountMinor)} | ${row.splitMode} | ${statementMoney(row.yourShareMinor)} | ${row.status}',
      );
    }
    buffer
      ..writeln()
      ..writeln('Total group expenses: ${statementMoney(totalGroupExpenses)}')
      ..writeln('Total paid by user: ${statementMoney(totalPaidByUser)}')
      ..writeln('Total user share: ${statementMoney(totalUserShare)}')
      ..writeln('Total settled: ${statementMoney(totalSettled)}')
      ..writeln('Remaining balance: ${statementMoney(remainingBalance)}');
    return buffer.toString();
  }
}

class GroupStatementRow {
  GroupStatementRow({
    required this.date,
    required this.type,
    required this.description,
    required this.paidBy,
    required this.participants,
    required this.totalAmountMinor,
    required this.splitMode,
    required this.yourShareMinor,
    required this.status,
  });

  final DateTime date;
  final String type;
  final String description;
  final String paidBy;
  final String participants;
  final int totalAmountMinor;
  final String splitMode;
  final int yourShareMinor;
  final String status;
}

class GroupStatementTable extends StatelessWidget {
  const GroupStatementTable({required this.statement, super.key});

  static const _columns = [
    ('Date', 112.0),
    ('Type', 112.0),
    ('Description', 220.0),
    ('Paid By', 180.0),
    ('Participants', 130.0),
    ('Total Amount', 140.0),
    ('Split Mode', 120.0),
    ('Your Share', 130.0),
    ('Status', 110.0),
  ];

  static const _tableWidth = 1254.0;

  final GroupStatementData statement;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: _tableWidth,
                    child: Column(
                      children: [
                        _StatementHeader(columns: _columns),
                        Expanded(
                          child: statement.rows.isEmpty
                              ? const EmptyState(
                                  icon: Icons.description_outlined,
                                  title: 'No statement rows',
                                  body:
                                      'Expenses, settlements, and adjustments appear here.',
                                )
                              : ListView.builder(
                                  itemCount: statement.rows.length,
                                  itemBuilder: (context, index) {
                                    final row = statement.rows[index];
                                    return _StatementTableRow(
                                      values: [
                                        statementDate(row.date),
                                        row.type,
                                        row.description,
                                        row.paidBy,
                                        row.participants,
                                        statementMoney(row.totalAmountMinor),
                                        row.splitMode,
                                        statementMoney(row.yourShareMinor),
                                        row.status,
                                      ],
                                      columns: _columns,
                                      shaded: index.isOdd,
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _StatementTotals(statement: statement),
      ],
    );
  }
}

class _StatementHeader extends StatelessWidget {
  const _StatementHeader({required this.columns});

  final List<(String, double)> columns;

  @override
  Widget build(BuildContext context) {
    return _StatementTableRow(
      values: [for (final column in columns) column.$1],
      columns: columns,
      header: true,
    );
  }
}

class _StatementTableRow extends StatelessWidget {
  const _StatementTableRow({
    required this.values,
    required this.columns,
    this.header = false,
    this.shaded = false,
  });

  final List<String> values;
  final List<(String, double)> columns;
  final bool header;
  final bool shaded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = header
        ? colorScheme.surfaceContainerHighest
        : shaded
        ? colorScheme.surfaceContainerLow
        : colorScheme.surface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < columns.length; index++)
          Container(
            width: columns[index].$2,
            constraints: BoxConstraints(minHeight: header ? 44 : 52),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: background,
              border: Border(
                right: BorderSide(color: colorScheme.outlineVariant),
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Text(
              values[index],
              style: header
                  ? Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    )
                  : Theme.of(context).textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

class _StatementTotals extends StatelessWidget {
  const _StatementTotals({required this.statement});

  final GroupStatementData statement;

  @override
  Widget build(BuildContext context) {
    final totals = [
      ('Total group expenses', statement.totalGroupExpenses),
      ('Total paid by user', statement.totalPaidByUser),
      ('Total user share', statement.totalUserShare),
      ('Total settled', statement.totalSettled),
      ('Remaining balance', statement.remainingBalance),
    ];
    return SizedBox(
      height: 104,
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < totals.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                SizedBox(
                  width: 210,
                  child: StatementTotalTile(
                    label: totals[index].$1,
                    value: statementMoney(totals[index].$2),
                    tone: totals[index].$2 < 0 ? Tone.warning : Tone.neutral,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class StatementTotalTile extends StatelessWidget {
  const StatementTotalTile({
    required this.label,
    required this.value,
    required this.tone,
    super.key,
  });

  final String label;
  final String value;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final color = toneColor(context, tone);
    return Container(
      height: 94,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.summarize_outlined, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String statementDate(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String dateTimeLabel(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');
  final minute = date.minute.toString().padLeft(2, '0');
  return '${statementDate(date)} $hour:$minute';
}

String statementMoney(int minor) {
  final sign = minor < 0 ? '-' : '';
  final absolute = minor.abs();
  final rupees = absolute ~/ 100;
  final paisa = absolute % 100;
  final rupeeText = rupees.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '${sign}NPR $rupeeText.${paisa.toString().padLeft(2, '0')}';
}

String _csvCell(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

Future<void> showCreateGiftPoolDialog(BuildContext context) async {
  final store = StoreScope.of(context);
  final groups = store.visibleGroups;
  String? groupId = groups.isEmpty ? null : groups.first.id;
  String? recipientId = store.activeConnectionUsers().isEmpty
      ? null
      : store.activeConnectionUsers().first.id;
  final title = TextEditingController(text: 'Group gift pool');
  final target = TextEditingController(text: '5000');
  final message = TextEditingController(text: 'Together from Sangai.');
  var template = 'Tihar';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create Gift Pool'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: groupId,
                      decoration: const InputDecoration(labelText: 'Group'),
                      items: [
                        for (final group in groups)
                          DropdownMenuItem(
                            value: group.id,
                            child: Text(group.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => groupId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: recipientId,
                      decoration: const InputDecoration(labelText: 'Recipient'),
                      items: [
                        for (final user in store.activeConnectionUsers())
                          DropdownMenuItem(
                            value: user.id,
                            child: Text(user.displayName),
                          ),
                      ],
                      onChanged: (value) => setState(() => recipientId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: template,
                      decoration: const InputDecoration(labelText: 'Template'),
                      items: [
                        for (final item in const [
                          'Dashain',
                          'Tihar',
                          'Birthday',
                          'Wedding',
                        ])
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      onChanged: (value) =>
                          setState(() => template = value ?? template),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: target,
                      decoration: const InputDecoration(
                        labelText: 'Target amount',
                        prefixText: 'NPR ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: message,
                      decoration: const InputDecoration(labelText: 'Message'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: groupId == null || recipientId == null
                    ? null
                    : () {
                        store.createGiftPool(
                          groupId: groupId!,
                          recipientId: recipientId!,
                          title: title.text,
                          template: template,
                          targetAmountMinor: parseMoneyToMinor(target.text),
                          message: message.text,
                        );
                        Navigator.pop(dialogContext);
                      },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    },
  );
  title.dispose();
  target.dispose();
  message.dispose();
}

Future<void> showContributeToGiftPoolDialog(
  BuildContext context,
  GiftPool pool,
) async {
  final store = StoreScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final amount = TextEditingController(text: '500');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (builderContext, setState) {
          final raised = store.giftPoolTotal(pool.id);
          final remaining = pool.targetAmountMinor - raised;
          final amountMinor = parseMoneyToMinor(amount.text);
          final exceedsRemaining = amountMinor > remaining;
          final canContribute =
              remaining > 0 && amountMinor > 0 && !exceedsRemaining;
          return AlertDialog(
            title: const Text('Contribute to gift pool'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pool.title,
                    style: Theme.of(builderContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${money(raised)} of ${money(pool.targetAmountMinor)} raised'
                    '${remaining > 0 ? ' • ${money(remaining)} to go' : ' • target reached'}',
                    style: Theme.of(builderContext).textTheme.bodySmall
                        ?.copyWith(
                          color: Theme.of(
                            builderContext,
                          ).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amount,
                    autofocus: true,
                    enabled: remaining > 0,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'NPR ',
                      errorText: exceedsRemaining
                          ? 'Cannot exceed the ${money(remaining)} remaining.'
                          : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in const [251, 500, 1100])
                        if (npr(preset) <= remaining)
                          ActionChip(
                            label: Text('Rs $preset'),
                            onPressed: () =>
                                setState(() => amount.text = preset.toString()),
                          ),
                      if (remaining > 0)
                        ActionChip(
                          label: Text('Remaining ${money(remaining)}'),
                          onPressed: () => setState(
                            () => amount.text = (remaining ~/ 100).toString(),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: canContribute
                    ? () {
                        final result = store.contributeToGiftPool(
                          pool.id,
                          amountMinor,
                        );
                        Navigator.pop(dialogContext);
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(result)));
                      }
                    : null,
                child: const Text('Contribute'),
              ),
            ],
          );
        },
      );
    },
  );
  amount.dispose();
}

Future<void> showCreateDhukutiDialog(BuildContext context) async {
  final store = StoreScope.of(context);
  final groups = store.visibleGroups;
  String? groupId = groups.isEmpty ? null : groups.first.id;
  final name = TextEditingController(text: 'New Digital Dhukuti');
  final contribution = TextEditingController(text: '2000');
  final members = <String>{
    for (final user in store.activeConnectionUsers()) user.id,
  };
  var frequency = 'monthly';
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create Dhukuti Pool'),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: groupId,
                      decoration: const InputDecoration(
                        labelText: 'Linked group',
                      ),
                      items: [
                        for (final group in groups)
                          DropdownMenuItem(
                            value: group.id,
                            child: Text(group.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => groupId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contribution,
                      decoration: const InputDecoration(
                        labelText: 'Contribution amount',
                        prefixText: 'NPR ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: frequency,
                      decoration: const InputDecoration(labelText: 'Frequency'),
                      items: [
                        for (final item in const ['monthly', 'weekly'])
                          DropdownMenuItem(value: item, child: Text(item)),
                      ],
                      onChanged: (value) =>
                          setState(() => frequency = value ?? frequency),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Invite members',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final user in store.activeConnectionUsers())
                          FilterChip(
                            selected: members.contains(user.id),
                            avatar: UserAvatar(user: user, small: true),
                            label: Text(user.displayName),
                            onSelected: (checked) {
                              setState(() {
                                checked
                                    ? members.add(user.id)
                                    : members.remove(user.id);
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: groupId == null
                    ? null
                    : () {
                        store.createDhukutiPool(
                          groupId: groupId!,
                          name: name.text,
                          contributionAmountMinor: parseMoneyToMinor(
                            contribution.text,
                          ),
                          frequency: frequency,
                          startDate: DateTime.now(),
                          memberIds: members.toList(),
                        );
                        Navigator.pop(dialogContext);
                      },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    },
  );
  name.dispose();
  contribution.dispose();
}

Future<void> showEmergencyExitDialog(
  BuildContext context,
  String poolId,
) async {
  final store = StoreScope.of(context);
  final reason = TextEditingController(text: 'Need to pause contributions');
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Emergency Exit Request'),
      content: SizedBox(
        width: 460,
        child: TextField(
          controller: reason,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason for organizer review',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            store.requestEmergencyExit(poolId, reason.text);
            Navigator.pop(dialogContext);
          },
          child: const Text('Request'),
        ),
      ],
    ),
  );
  reason.dispose();
}
