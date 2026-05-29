import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

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
          'A local eSewa-style prototype with seeded demo data and no backend calls.',
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
                        : 'Confirmed $count mock eSewa settlement(s).',
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
                'The recommended story arc is ready: create a Dashain group, add an expense, split it, settle through mock eSewa, send a gift, then show the Digital Dhukuti ledger.',
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
    final activeMembers = store.membersForGroup(group.id, activeOnly: true);
    final currentMember = store.memberForGroup(group.id, store.currentUserId);
    final isCurrentMember = currentMember?.status == MemberStatus.active;
    final isAdmin = store.isGroupAdmin(group.id, store.currentUserId);
    final balances = store.balancesForGroup(group.id);
    final suggestions = store.suggestionsForGroup(group.id);
    final canAddExpense = isCurrentMember && !group.isDisbanded;
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
                  ? () => showAddExpenseOcrFlow(context, group.id)
                  : null,
              icon: const Icon(Icons.receipt_long),
              label: const Text('Add expense'),
            ),
            OutlinedButton.icon(
              onPressed: () => showStatementDialog(context, group.id),
              icon: const Icon(Icons.description_outlined),
              label: const Text('Statement'),
            ),
            OutlinedButton.icon(
              onPressed: isCurrentMember
                  ? () => showLeaveGroupDialog(context, group.id)
                  : null,
              icon: const Icon(Icons.logout),
              label: const Text('Leave group'),
            ),
            if (isAdmin)
              FilledButton.tonalIcon(
                onPressed: () => showDisbandGroupDialog(context, group.id),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Disband'),
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
            label: 'Active members',
            value: '${activeMembers.length}',
            icon: Icons.group_outlined,
            tone: Tone.neutral,
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
          onPressed: isAdmin && !group.isDisbanded
              ? () => showAddMemberDialog(context, group.id)
              : null,
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
                    isAdmin &&
                        member.userId != store.currentUserId &&
                        member.status == MemberStatus.active
                    ? () => showRemoveMemberDialog(context, group.id, member)
                    : null,
                onPressed: isAdmin && member.status == MemberStatus.active
                    ? () => showRoleDialog(context, group.id, member)
                    : null,
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
  final _amount = TextEditingController(text: '1000');
  final _message = TextEditingController(text: 'Sangai gift for you.');
  var _template = 'Dashain';
  String? _recipientId;

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
    _recipientId ??= connections.isEmpty ? null : connections.first.id;
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
              'Send themed money envelopes to active connections and run P1 group gift pools.',
          icon: Icons.card_giftcard,
        ),
        ResponsiveWrap(
          children: [
            SectionPanel(
              title: 'Send Gift Card',
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _recipientId,
                    decoration: const InputDecoration(labelText: 'Recipient'),
                    items: [
                      for (final user in connections)
                        DropdownMenuItem(
                          value: user.id,
                          child: Text(user.displayName),
                        ),
                    ],
                    onChanged: (value) => setState(() => _recipientId = value),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _template,
                    decoration: const InputDecoration(labelText: 'Template'),
                    items: [
                      for (final template in const [
                        'Dashain',
                        'Tihar',
                        'Birthday',
                        'Wedding',
                        'Thank you',
                        'Custom',
                      ])
                        DropdownMenuItem(
                          value: template,
                          child: Text(template),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _template = value ?? _template),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'NPR ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _message,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Private message',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _recipientId == null
                          ? null
                          : () {
                              final message = store.sendGift(
                                recipientId: _recipientId!,
                                template: _template,
                                amountMinor: parseMoneyToMinor(_amount.text),
                                message: _message.text,
                              );
                              showSnack(context, message);
                            },
                      icon: const Icon(Icons.send),
                      label: const Text('Send via eSewa'),
                    ),
                  ),
                ],
              ),
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
                                      ? () => store.contributeToGiftPool(
                                          pool.id,
                                          npr(500),
                                        )
                                      : null,
                                  child: const Text('Add NPR 500'),
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
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Icon(
                            gift.template == 'Tihar'
                                ? Icons.light_mode_outlined
                                : Icons.card_giftcard,
                          ),
                        ),
                        title: Text(
                          '${gift.template} • ${store.nameOf(gift.senderId)} to ${store.nameOf(gift.recipientId)}',
                        ),
                        subtitle: Text(gift.message),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            BalancePill(amountMinor: gift.amountMinor),
                            StatusPill(
                              label: enumLabel(gift.status),
                              tone: gift.status == GiftStatus.opened
                                  ? Tone.success
                                  : Tone.neutral,
                            ),
                            if (gift.recipientId == store.currentUserId &&
                                gift.status == GiftStatus.sent)
                              FilledButton(
                                onPressed: () => store.openGift(gift.id),
                                child: const Text('Open'),
                              ),
                            if (gift.senderId == store.currentUserId &&
                                gift.status == GiftStatus.sent)
                              OutlinedButton(
                                onPressed: () => store.refundGift(gift.id),
                                child: const Text('Refund'),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
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
        final compact = constraints.maxWidth < 840;
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
            Flexible(
              child: Align(alignment: Alignment.topRight, child: action!),
            ),
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
    return '${item.body.replaceAll(' via mock eSewa.', '')}.';
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

Future<void> showAddExpenseOcrFlow(BuildContext context, String groupId) async {
  final store = StoreScope.of(context);
  final members = store.membersForGroup(groupId, activeOnly: true);
  if (members.isEmpty ||
      !store.isActiveGroupMember(groupId, store.currentUserId)) {
    showSnack(context, 'Only active group members can add expenses.');
    return;
  }

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Add expense OCR scanner',
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _AddExpenseOcrScreen(groupId: groupId);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _AddExpenseOcrScreen extends StatefulWidget {
  const _AddExpenseOcrScreen({required this.groupId});

  final String groupId;

  @override
  State<_AddExpenseOcrScreen> createState() => _AddExpenseOcrScreenState();
}

class _AddExpenseOcrScreenState extends State<_AddExpenseOcrScreen> {
  static const _scannerMethodChannel = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/method',
  );

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  late final MobileScannerController _cameraController =
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);

  var _cameraReady = false;
  var _runningOcr = false;
  var _autoOcrStarted = false;
  var _flashOn = false;
  var _scanVersion = 0;
  String? _cameraIssue;
  String? _scanMessage;
  List<_ExpenseItemDraft> _scannedItems = <_ExpenseItemDraft>[];

  bool get _desktopWeb {
    if (!kIsWeb) {
      return false;
    }
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  @override
  void initState() {
    super.initState();
    unawaited(_prepareCamera());
  }

  @override
  void dispose() {
    unawaited(_cameraController.dispose());
    _sheetController.dispose();
    for (final item in _scannedItems) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _prepareCamera() async {
    if (kIsWeb && !_hasSecureWebCameraContext()) {
      if (!mounted) {
        return;
      }
      setState(() {
        _cameraReady = false;
        _cameraIssue =
            'Camera access is needed to scan bills. Use HTTPS, localhost, upload, or Manual Entry.';
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
          _cameraReady = false;
          _cameraIssue =
              'Camera access is needed to scan bills. The scanner plugin is not ready in this app process.';
        });
        return;
      } on PlatformException catch (error) {
        if (!mounted) {
          return;
        }
        setState(() {
          _cameraReady = false;
          _cameraIssue =
              error.message ?? 'Camera access is needed to scan bills.';
        });
        return;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _cameraReady = true;
      _cameraIssue = null;
    });
    _scheduleAutoBillDetection();
  }

  void _scheduleAutoBillDetection() {
    if (_autoOcrStarted || !_cameraReady) {
      return;
    }
    _autoOcrStarted = true;
    setState(() => _scanMessage = 'Looking for a bill in the frame...');
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted ||
          !_cameraReady ||
          _runningOcr ||
          _scannedItems.isNotEmpty) {
        return;
      }
      unawaited(_runOcr());
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

  void _handleCameraError(Object error, StackTrace stackTrace) {
    if (!mounted) {
      return;
    }
    setState(() {
      _cameraReady = false;
      _cameraIssue = switch (error) {
        MobileScannerException(:final errorDetails, :final errorCode) =>
          errorDetails?.message ?? errorCode.message,
        PlatformException(:final message) =>
          message ?? 'Camera access is needed to scan bills.',
        _ => 'Camera access is needed to scan bills.',
      };
    });
  }

  Future<void> _runOcr({bool fromUpload = false}) async {
    if (_runningOcr) {
      return;
    }
    setState(() {
      _runningOcr = true;
      _scanMessage = 'Reading bill items...';
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) {
        return;
      }

      for (final item in _scannedItems) {
        item.dispose();
      }
      _scannedItems = _demoScannedBillItems();
      setState(() {
        _runningOcr = false;
        _scanVersion += 1;
        _scanMessage =
            'Some items may need correction. Please review before continuing.';
      });
      await _sheetController.animateTo(
        0.92,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
      );
    } catch (_) {
      if (mounted) {
        _showOcrFailure();
      }
    }
  }

  void _showOcrFailure() {
    setState(() {
      _runningOcr = false;
      _scanMessage =
          'Couldn’t read the bill clearly. Try again or use Manual Entry.';
    });
  }

  Future<void> _toggleFlash() async {
    try {
      await _cameraController.toggleTorch();
      if (!mounted) {
        return;
      }
      setState(() => _flashOn = !_flashOn);
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Flash is not available on this device.');
      }
    }
  }

  Widget _cameraFallback(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: const Color(0xFF101814),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.no_photography_outlined,
                color: scheme.error,
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                _cameraIssue ?? 'Camera access is needed to scan bills.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      setState(() => _cameraIssue = null);
                      unawaited(_prepareCamera());
                    },
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Allow camera'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _sheetController.animateTo(
                      0.92,
                      duration: const Duration(milliseconds: 320),
                      curve: Curves.easeOutCubic,
                    ),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: const Text('Use Manual Entry'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerError(
    BuildContext context,
    MobileScannerException error,
  ) {
    final message =
        error.errorDetails?.message ?? 'Camera access is needed to scan bills.';
    return Container(
      color: const Color(0xFF101814),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: _cameraReady
                  ? MobileScanner(
                      controller: _cameraController,
                      fit: BoxFit.cover,
                      onDetect: (_) {},
                      onDetectError: _handleCameraError,
                      errorBuilder: _buildScannerError,
                      placeholderBuilder: (context) => const ColoredBox(
                        color: Color(0xFF101814),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  : _cameraFallback(context),
            ),
            Positioned.fill(child: _BillScanOverlay(accent: accent)),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: _cameraReady ? _toggleFlash : null,
                    icon: Icon(_flashOn ? Icons.flash_on : Icons.flash_off),
                    tooltip: 'Flash',
                  ),
                ],
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: MediaQuery.sizeOf(context).height * 0.17,
              child: const Text(
                'Align the bill inside the frame',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 126,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_scanMessage != null)
                    _ScanStatusPill(
                      message: _scanMessage!,
                      loading: _runningOcr,
                      failed: _scanMessage!.startsWith('Couldn’t'),
                      onScanAgain: () => _runOcr(),
                      onUseManual: () => _sheetController.animateTo(
                        0.92,
                        duration: const Duration(milliseconds: 320),
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  if (_scanMessage != null) const SizedBox(height: 12),
                  if (_desktopWeb)
                    FilledButton.icon(
                      onPressed: _runningOcr
                          ? null
                          : () => _runOcr(fromUpload: true),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Upload bill image'),
                    ),
                ],
              ),
            ),
            ScrollConfiguration(
              behavior: const _ManualSheetScrollBehavior(),
              child: DraggableScrollableSheet(
                controller: _sheetController,
                expand: true,
                initialChildSize: _ManualEntrySheet.collapsedExtent,
                minChildSize: _ManualEntrySheet.minExtent,
                maxChildSize: _ManualEntrySheet.expandedExtent,
                snap: true,
                snapSizes: const [
                  _ManualEntrySheet.collapsedExtent,
                  _ManualEntrySheet.expandedExtent,
                ],
                shouldCloseOnMinExtent: false,
                builder: (context, scrollController) {
                  return _ManualEntrySheet(
                    key: ValueKey(_scanVersion),
                    groupId: widget.groupId,
                    sheetController: _sheetController,
                    scrollController: scrollController,
                    scannedItems: _scannedItems,
                    reviewMessage: _scannedItems.isEmpty
                        ? null
                        : 'Review scanned items before saving.',
                    onSaved: () => Navigator.pop(context),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillScanOverlay extends StatelessWidget {
  const _BillScanOverlay({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final frameWidth = math.min(constraints.maxWidth - 48, 430.0);
        final frameHeight = math.min(constraints.maxHeight * 0.48, 520.0);
        return IgnorePointer(
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _ScanScrimPainter(
                    frame: Rect.fromCenter(
                      center: Offset(
                        constraints.maxWidth / 2,
                        constraints.maxHeight * 0.43,
                      ),
                      width: frameWidth,
                      height: frameHeight,
                    ),
                    radius: 26,
                  ),
                ),
              ),
              Positioned(
                left: (constraints.maxWidth - frameWidth) / 2,
                top: constraints.maxHeight * 0.43 - frameHeight / 2,
                width: frameWidth,
                height: frameHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: accent, width: 3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScanScrimPainter extends CustomPainter {
  const _ScanScrimPainter({required this.frame, required this.radius});

  final Rect frame;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final cutout = Path()
      ..addRRect(RRect.fromRectAndRadius(frame, Radius.circular(radius)));
    final path = Path.combine(PathOperation.difference, full, cutout);
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.56),
    );
  }

  @override
  bool shouldRepaint(covariant _ScanScrimPainter oldDelegate) {
    return oldDelegate.frame != frame || oldDelegate.radius != radius;
  }
}

class _ScanStatusPill extends StatelessWidget {
  const _ScanStatusPill({
    required this.message,
    required this.loading,
    required this.failed,
    required this.onScanAgain,
    required this.onUseManual,
  });

  final String message;
  final bool loading;
  final bool failed;
  final VoidCallback onScanAgain;
  final VoidCallback onUseManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading) ...[
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (failed) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: onScanAgain,
                  child: const Text('Scan again'),
                ),
                FilledButton(
                  onPressed: onUseManual,
                  child: const Text('Use Manual Entry'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ManualSheetScrollBehavior extends MaterialScrollBehavior {
  const _ManualSheetScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.trackpad,
  };
}

enum _BillLineKind { item, serviceCharge, tax, discount, rounding }

class _ExpenseItemDraft {
  _ExpenseItemDraft({
    required String name,
    required int amountMinor,
    int quantity = 1,
    int? unitAmountMinor,
    this.kind = _BillLineKind.item,
    this.confidence = 1,
    Iterable<String>? assignedTo,
  }) : name = TextEditingController(text: name),
       quantity = TextEditingController(text: quantity.toString()),
       unitPrice = TextEditingController(
         text: ((unitAmountMinor ?? amountMinor) / 100).toStringAsFixed(2),
       ),
       amount = TextEditingController(
         text: (amountMinor / 100).toStringAsFixed(2),
       ),
       assignedTo = assignedTo == null
           ? <String>{}
           : Set<String>.from(assignedTo);

  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unitPrice;
  final TextEditingController amount;
  final Set<String> assignedTo;
  _BillLineKind kind;
  double confidence;

  int get amountMinor => parseMoneyToMinor(amount.text);
  int get quantityValue => int.tryParse(quantity.text.trim()) ?? 1;
  int get unitAmountMinor => parseMoneyToMinor(unitPrice.text);

  void dispose() {
    name.dispose();
    quantity.dispose();
    unitPrice.dispose();
    amount.dispose();
  }
}

List<_ExpenseItemDraft> _demoScannedBillItems() {
  return <_ExpenseItemDraft>[
    _ExpenseItemDraft(
      name: 'Chicken momo',
      amountMinor: npr(300),
      confidence: 0.96,
    ),
    _ExpenseItemDraft(
      name: 'Veg chowmein',
      amountMinor: npr(180),
      confidence: 0.94,
    ),
    _ExpenseItemDraft(
      name: 'Cold drinks',
      amountMinor: npr(240),
      quantity: 3,
      unitAmountMinor: npr(80),
      confidence: 0.92,
    ),
    _ExpenseItemDraft(
      name: 'Service charge',
      amountMinor: npr(72),
      kind: _BillLineKind.serviceCharge,
      confidence: 0.86,
    ),
    _ExpenseItemDraft(
      name: 'VAT',
      amountMinor: npr(93.60),
      kind: _BillLineKind.tax,
      confidence: 0.72,
    ),
  ];
}

class _ManualEntrySheet extends StatefulWidget {
  const _ManualEntrySheet({
    required this.groupId,
    required this.sheetController,
    required this.scrollController,
    required this.scannedItems,
    required this.onSaved,
    this.reviewMessage,
    super.key,
  });

  static const minExtent = 0.13;
  static const collapsedExtent = 0.16;
  static const expandedExtent = 0.92;

  final String groupId;
  final DraggableScrollableController sheetController;
  final ScrollController scrollController;
  final List<_ExpenseItemDraft> scannedItems;
  final String? reviewMessage;
  final VoidCallback onSaved;

  @override
  State<_ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends State<_ManualEntrySheet> {
  final _title = TextEditingController(text: 'Shared expense');
  final _amount = TextEditingController(text: '1200.00');
  final _note = TextEditingController();
  final _payerRows = <_PayerDraft>[];
  final _participants = <String>{};
  final _custom = <String, String>{};
  final _percentages = <String, String>{};
  final _shares = <String, String>{};
  final _items = <_ExpenseItemDraft>[];

  var _splitMode = SplitMode.equal;
  var _skipItemSplit = true;
  var _equalPreview = <String, int>{};
  var _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    final store = StoreScope.of(context);
    final members = store.membersForGroup(widget.groupId, activeOnly: true);
    _participants.addAll(members.map((member) => member.userId));
    _payerRows.add(
      _PayerDraft(userId: store.currentUserId, amountText: _amount.text),
    );
    if (widget.scannedItems.isNotEmpty) {
      _items.addAll(widget.scannedItems.map(_cloneDraft));
      _splitMode = SplitMode.item;
      _skipItemSplit = false;
      _syncTotalFromItems();
    }
    _refreshEqualPreview();
    _initialized = true;
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    for (final payer in _payerRows) {
      payer.dispose();
    }
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  _ExpenseItemDraft _cloneDraft(_ExpenseItemDraft draft) {
    return _ExpenseItemDraft(
      name: draft.name.text,
      amountMinor: draft.amountMinor,
      quantity: draft.quantityValue,
      unitAmountMinor: draft.unitAmountMinor,
      kind: draft.kind,
      confidence: draft.confidence,
      assignedTo: draft.assignedTo,
    );
  }

  void _refreshEqualPreview() {
    final ids = _participants.toList();
    final amounts = equalShares(parseMoneyToMinor(_amount.text), ids);
    _equalPreview = {
      for (var index = 0; index < ids.length; index++)
        ids[index]: amounts[index],
    };
  }

  void _syncSinglePayerToTotal() {
    if (_payerRows.length == 1) {
      _payerRows.first.amount.text = _amount.text;
    }
  }

  void _syncTotalFromItems() {
    _amount.text = (_billTotals.finalTotalMinor / 100).toStringAsFixed(2);
    _syncSinglePayerToTotal();
  }

  _BillTotals get _billTotals => _BillTotals.fromDrafts(_items);

  List<ParsedReceiptItem> _receiptItems() {
    return [
      for (final item in _items)
        if (item.name.text.trim().isNotEmpty)
          ParsedReceiptItem(
            label: item.name.text.trim(),
            amountMinor: item.amountMinor,
            quantity: item.quantityValue,
            unitAmountMinor: item.unitAmountMinor,
            confidence: item.confidence,
          ),
    ];
  }

  Map<int, List<String>> _itemAssignments(List<String> selectedParticipants) {
    return {
      for (var index = 0; index < _items.length; index++)
        index: _assignmentUsers(_items[index], selectedParticipants),
    };
  }

  List<String> _assignmentUsers(
    _ExpenseItemDraft item,
    List<String> selectedParticipants,
  ) {
    final users = item.assignedTo
        .where(selectedParticipants.contains)
        .toList(growable: false);
    return users.isEmpty ? selectedParticipants : users;
  }

  void _removeParticipant(String userId) {
    _participants.remove(userId);
    _custom.remove(userId);
    _percentages.remove(userId);
    _shares.remove(userId);
    for (final item in _items) {
      item.assignedTo.remove(userId);
    }
  }

  Future<void> _changeSplitMode(SplitMode value) async {
    if (_splitMode == SplitMode.item && value != SplitMode.item) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Change split mode?'),
          content: const Text(
            'Changing split mode may remove item assignments. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
      for (final item in _items) {
        item.assignedTo.clear();
      }
      _skipItemSplit = true;
    }
    setState(() {
      _splitMode = value;
      if (value == SplitMode.item) {
        _skipItemSplit = false;
        _syncTotalFromItems();
      }
      _refreshEqualPreview();
    });
  }

  void _addItem() {
    setState(() {
      _items.add(_ExpenseItemDraft(name: 'New item', amountMinor: 0));
      _skipItemSplit = false;
      _splitMode = SplitMode.item;
      _syncTotalFromItems();
      _refreshEqualPreview();
    });
  }

  Future<void> _toggleSheet() async {
    if (!widget.sheetController.isAttached) {
      return;
    }
    final target =
        widget.sheetController.size <
            (_ManualEntrySheet.collapsedExtent +
                    _ManualEntrySheet.expandedExtent) /
                2
        ? _ManualEntrySheet.expandedExtent
        : _ManualEntrySheet.collapsedExtent;
    await widget.sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _dragSheet(DragUpdateDetails details) {
    if (!widget.sheetController.isAttached) {
      return;
    }
    final height = MediaQuery.sizeOf(context).height;
    if (height <= 0) {
      return;
    }
    final delta = -(details.primaryDelta ?? 0) / height;
    final next = (widget.sheetController.size + delta).clamp(
      _ManualEntrySheet.minExtent,
      _ManualEntrySheet.expandedExtent,
    );
    widget.sheetController.jumpTo(next);
  }

  Future<void> _settleSheet(DragEndDetails details) async {
    if (!widget.sheetController.isAttached) {
      return;
    }
    final velocity = details.primaryVelocity ?? 0;
    final midpoint =
        (_ManualEntrySheet.collapsedExtent + _ManualEntrySheet.expandedExtent) /
        2;
    final target = velocity < -250
        ? _ManualEntrySheet.expandedExtent
        : velocity > 250
        ? _ManualEntrySheet.collapsedExtent
        : widget.sheetController.size >= midpoint
        ? _ManualEntrySheet.expandedExtent
        : _ManualEntrySheet.collapsedExtent;
    await widget.sheetController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _save({
    required int total,
    required Map<String, int> payerAmounts,
    required List<String> selectedParticipants,
  }) {
    final store = StoreScope.of(context);
    final effectiveSplitMode = _skipItemSplit && _splitMode == SplitMode.item
        ? SplitMode.equal
        : _splitMode;
    final totals = _billTotals;
    try {
      store.addExpense(
        groupId: widget.groupId,
        title: _title.text.trim().isEmpty
            ? 'Shared expense'
            : _title.text.trim(),
        totalMinor: total,
        payerId: payerAmounts.keys.first,
        payerAmounts: payerAmounts,
        category: store.groupById(widget.groupId).category.name,
        splitMode: effectiveSplitMode,
        participantIds: selectedParticipants,
        note: _note.text,
        equalAmounts: effectiveSplitMode == SplitMode.equal
            ? _equalPreview
            : null,
        customAmounts: _custom.map(
          (key, value) => MapEntry(key, parseMoneyToMinor(value)),
        ),
        percentages: _percentages.map(
          (key, value) => MapEntry(key, double.tryParse(value) ?? 0),
        ),
        shareUnits: _shares.map(
          (key, value) => MapEntry(key, int.tryParse(value) ?? 1),
        ),
        receiptItems: effectiveSplitMode == SplitMode.item
            ? _receiptItems()
            : <ParsedReceiptItem>[],
        itemAssignments: effectiveSplitMode == SplitMode.item
            ? _itemAssignments(selectedParticipants)
            : null,
        taxMinor: totals.taxMinor,
        serviceChargeMinor: totals.serviceChargeMinor,
        discountMinor: totals.discountMinor.abs(),
        roundingAdjustmentMinor: totals.roundingAdjustmentMinor,
      );
      widget.onSaved();
    } on ArgumentError catch (error) {
      showSnack(context, error.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final members = store.membersForGroup(widget.groupId, activeOnly: true);
    final selectedParticipants = _participants.toList();
    final total = parseMoneyToMinor(_amount.text);
    final billTotals = _billTotals;
    final itemModeActive = !_skipItemSplit && _splitMode == SplitMode.item;
    final payerAmounts = <String, int>{};
    var hasMissingPayer = false;
    var hasZeroPayerAmount = false;
    for (final payer in _payerRows) {
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
    final splitPreview = _manualSplitPreviewFor(
      total: total,
      participants: selectedParticipants,
      splitMode: itemModeActive ? SplitMode.item : _splitMode,
      equalPreview: _equalPreview,
      custom: _custom,
      percentages: _percentages,
      shares: _shares,
      itemDrafts: _items,
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
    final itemError = itemModeActive
        ? _itemValidationMessage(
            total: total,
            totals: billTotals,
            items: _items,
          )
        : null;
    final splitError = selectedParticipants.isEmpty
        ? 'Please select participants.'
        : itemError ??
              (splitTotal != total
                  ? 'Participant split amounts must add up to the total expense.'
                  : null);
    final readyToSave =
        total > 0 &&
        payerError == null &&
        splitError == null &&
        splitPreview.isNotEmpty;
    final canAddAnotherPayer =
        _payerRows.length < members.length && payerTotal < total;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 16,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      child: CustomScrollView(
        controller: widget.scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_toggleSheet()),
              onVerticalDragUpdate: _dragSheet,
              onVerticalDragEnd: (details) => unawaited(_settleSheet(details)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.edit_note_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manual Entry',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const Text(
                                'Enter bill manually or edit scanned items',
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_up_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
            sliver: SliverList.list(
              children: [
                if (widget.reviewMessage != null) ...[
                  _ReviewMessage(widget.reviewMessage!),
                  const SizedBox(height: 12),
                ],
                _DialogSection(
                  title: 'Participants',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final member in members)
                        ParticipantSelectorCard(
                          user: store.userById(member.userId),
                          selected: _participants.contains(member.userId),
                          onTap: () {
                            setState(() {
                              if (_participants.contains(member.userId)) {
                                _removeParticipant(member.userId);
                              } else {
                                _participants.add(member.userId);
                              }
                              _refreshEqualPreview();
                            });
                          },
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
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'Title'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amount,
                        enabled: !itemModeActive,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total amount',
                          prefixText: 'NPR ',
                        ),
                        onChanged: (_) {
                          setState(() {
                            _syncSinglePayerToTotal();
                            _refreshEqualPreview();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _note,
                        decoration: const InputDecoration(labelText: 'Note'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DialogSection(
                  title: 'Who paid?',
                  child: Column(
                    children: [
                      for (var index = 0; index < _payerRows.length; index++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: index == _payerRows.length - 1 ? 0 : 8,
                          ),
                          child: _PayerInputRow(
                            members: members,
                            payer: _payerRows[index],
                            selectedByOtherRows: {
                              for (
                                var other = 0;
                                other < _payerRows.length;
                                other++
                              )
                                if (other != index &&
                                    _payerRows[other].userId != null)
                                  _payerRows[other].userId!,
                            },
                            canRemove: index > 0,
                            onChanged: () => setState(() {}),
                            onRemove: () {
                              setState(() {
                                final removed = _payerRows.removeAt(index);
                                removed.dispose();
                              });
                            },
                          ),
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: canAddAnotherPayer
                              ? () {
                                  setState(() {
                                    final selected = _payerRows
                                        .map((payer) => payer.userId)
                                        .whereType<String>()
                                        .toSet();
                                    final next = members
                                        .map((member) => member.userId)
                                        .firstWhere(
                                          (id) => !selected.contains(id),
                                          orElse: () => members.first.userId,
                                        );
                                    _payerRows.add(_PayerDraft(userId: next));
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.add),
                          label: const Text('Add another payer'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DialogSection(
                  title: 'Item list',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _skipItemSplit,
                        title: const Text(
                          'Skip item split and use total amount',
                        ),
                        onChanged: (value) {
                          setState(() {
                            _skipItemSplit = value;
                            _splitMode = value
                                ? SplitMode.equal
                                : SplitMode.item;
                            if (!value) {
                              _syncTotalFromItems();
                            }
                            _refreshEqualPreview();
                          });
                        },
                      ),
                      if (!_skipItemSplit) ...[
                        for (var index = 0; index < _items.length; index++)
                          _ExpenseItemDraftRow(
                            key: ValueKey(_items[index]),
                            item: _items[index],
                            selectedParticipants: selectedParticipants,
                            onChanged: () {
                              setState(() {
                                _syncTotalFromItems();
                                _refreshEqualPreview();
                              });
                            },
                            onRemove: () {
                              setState(() {
                                final removed = _items.removeAt(index);
                                removed.dispose();
                                _syncTotalFromItems();
                                _refreshEqualPreview();
                              });
                            },
                          ),
                        const SizedBox(height: 8),
                      ],
                      OutlinedButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text('+ Add item'),
                      ),
                      if (!_skipItemSplit) ...[
                        const SizedBox(height: 12),
                        _BillTotalsCard(totals: billTotals),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DialogSection(
                  title: 'Split mode',
                  child: DropdownButtonFormField<SplitMode>(
                    initialValue: _splitMode,
                    decoration: const InputDecoration(labelText: 'Split mode'),
                    items: [
                      for (final item in SplitMode.values)
                        DropdownMenuItem(
                          value: item,
                          child: Text(enumLabel(item)),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        unawaited(_changeSplitMode(value));
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _DialogSection(
                  title: 'Split preview',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_splitMode == SplitMode.custom)
                        _AmountGrid(
                          ids: selectedParticipants,
                          label: 'Custom amount',
                          values: _custom,
                          suffix: 'NPR',
                          onChanged: () => setState(() {}),
                        ),
                      if (_splitMode == SplitMode.percentage)
                        _AmountGrid(
                          ids: selectedParticipants,
                          label: 'Percentage',
                          values: _percentages,
                          suffix: '%',
                          maxValue: 100,
                          onChanged: () => setState(() {}),
                        ),
                      if (_splitMode == SplitMode.shares)
                        _AmountGrid(
                          ids: selectedParticipants,
                          label: 'Share units',
                          values: _shares,
                          suffix: 'x',
                          onChanged: () => setState(() {}),
                        ),
                      SplitPreview(
                        subtitle: _splitMode == SplitMode.equal
                            ? 'Calculated equal split'
                            : '${enumLabel(_splitMode)} split',
                        expenseTotal: total,
                        payerAmounts: payerAmounts,
                        participantShares: splitPreview,
                        participants: selectedParticipants,
                        showRoundingNote:
                            _splitMode == SplitMode.equal &&
                            selectedParticipants.isNotEmpty &&
                            total % selectedParticipants.length != 0,
                        payerError: payerError,
                        splitError: splitError,
                        ready: readyToSave,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: readyToSave
                            ? () => _save(
                                total: total,
                                payerAmounts: payerAmounts,
                                selectedParticipants: selectedParticipants,
                              )
                            : null,
                        child: const Text('Save expense'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewMessage extends StatelessWidget {
  const _ReviewMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: accent, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseItemDraftRow extends StatefulWidget {
  const _ExpenseItemDraftRow({
    required this.item,
    required this.selectedParticipants,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final _ExpenseItemDraft item;
  final List<String> selectedParticipants;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_ExpenseItemDraftRow> createState() => _ExpenseItemDraftRowState();
}

class _ExpenseItemDraftRowState extends State<_ExpenseItemDraftRow> {
  final _nameFocus = FocusNode();

  @override
  void dispose() {
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final item = widget.item;
    final lowConfidence = item.confidence < 0.85;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lowConfidence
            ? toneColor(context, Tone.warning).withValues(alpha: 0.07)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: lowConfidence
              ? toneColor(context, Tone.warning).withValues(alpha: 0.35)
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  focusNode: _nameFocus,
                  controller: item.name,
                  decoration: const InputDecoration(labelText: 'Item name'),
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
              SizedBox(
                width: 86,
                child: TextField(
                  controller: item.quantity,
                  decoration: const InputDecoration(labelText: 'Qty'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
              SizedBox(
                width: 132,
                child: TextField(
                  controller: item.unitPrice,
                  decoration: const InputDecoration(
                    labelText: 'Unit price',
                    prefixText: 'NPR ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
              SizedBox(
                width: 132,
                child: TextField(
                  controller: item.amount,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: 'NPR ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => widget.onChanged(),
                ),
              ),
              IconButton(
                onPressed: _nameFocus.requestFocus,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit item',
              ),
              IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete item',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 190,
                child: DropdownButtonFormField<_BillLineKind>(
                  initialValue: item.kind,
                  decoration: const InputDecoration(labelText: 'Line type'),
                  items: [
                    for (final kind in _BillLineKind.values)
                      DropdownMenuItem(
                        value: kind,
                        child: Text(_billLineKindLabel(kind)),
                      ),
                  ],
                  onChanged: (value) {
                    item.kind = value ?? item.kind;
                    widget.onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Total ${statementMoney(item.amountMinor)}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Assign participants',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in widget.selectedParticipants)
                FilterChip(
                  selected: item.assignedTo.contains(id),
                  avatar: UserAvatar(user: store.userById(id), small: true),
                  label: Text(store.nameOf(id)),
                  onSelected: (selected) {
                    if (selected) {
                      item.assignedTo.add(id);
                    } else {
                      item.assignedTo.remove(id);
                    }
                    widget.onChanged();
                  },
                ),
              if (widget.selectedParticipants.isEmpty)
                const Text('Select participants before assigning items.'),
            ],
          ),
          if (lowConfidence) ...[
            const SizedBox(height: 8),
            Text(
              'Some items may need correction. Please review before continuing.',
              style: TextStyle(
                color: toneColor(context, Tone.warning),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BillTotals {
  const _BillTotals({
    required this.subtotalMinor,
    required this.serviceChargeMinor,
    required this.taxMinor,
    required this.discountMinor,
    required this.roundingAdjustmentMinor,
  });

  factory _BillTotals.fromDrafts(List<_ExpenseItemDraft> drafts) {
    var subtotal = 0;
    var service = 0;
    var tax = 0;
    var discount = 0;
    var rounding = 0;
    for (final draft in drafts) {
      final amount = draft.amountMinor;
      switch (draft.kind) {
        case _BillLineKind.item:
          subtotal += amount;
        case _BillLineKind.serviceCharge:
          service += amount;
        case _BillLineKind.tax:
          tax += amount;
        case _BillLineKind.discount:
          discount += amount.isNegative ? amount : -amount;
        case _BillLineKind.rounding:
          rounding += amount;
      }
    }
    return _BillTotals(
      subtotalMinor: subtotal,
      serviceChargeMinor: service,
      taxMinor: tax,
      discountMinor: discount,
      roundingAdjustmentMinor: rounding,
    );
  }

  final int subtotalMinor;
  final int serviceChargeMinor;
  final int taxMinor;
  final int discountMinor;
  final int roundingAdjustmentMinor;

  int get finalTotalMinor =>
      subtotalMinor +
      serviceChargeMinor +
      taxMinor +
      discountMinor +
      roundingAdjustmentMinor;
}

class _BillTotalsCard extends StatelessWidget {
  const _BillTotalsCard({required this.totals});

  final _BillTotals totals;

  @override
  Widget build(BuildContext context) {
    return PreviewCard(
      icon: Icons.receipt_long_outlined,
      title: 'Bill total calculation',
      child: Column(
        children: [
          _BillTotalLine('Items subtotal', totals.subtotalMinor),
          _BillTotalLine('Service charge', totals.serviceChargeMinor),
          _BillTotalLine('VAT/Tax', totals.taxMinor),
          _BillTotalLine('Discount', totals.discountMinor),
          _BillTotalLine('Rounding adjustment', totals.roundingAdjustmentMinor),
          const Divider(),
          _BillTotalLine(
            'Final total',
            totals.finalTotalMinor,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _BillTotalLine extends StatelessWidget {
  const _BillTotalLine(this.label, this.amountMinor, {this.emphasized = false});

  final String label;
  final int amountMinor;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          Text(
            statementMoney(amountMinor),
            style: TextStyle(
              fontWeight: emphasized ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Map<String, int> _manualSplitPreviewFor({
  required int total,
  required List<String> participants,
  required SplitMode splitMode,
  required Map<String, int> equalPreview,
  required Map<String, String> custom,
  required Map<String, String> percentages,
  required Map<String, String> shares,
  required List<_ExpenseItemDraft> itemDrafts,
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
      SplitMode.item => _manualItemSplitPreview(
        total,
        participants,
        itemDrafts,
      ),
    };
  } on ArgumentError {
    return <String, int>{};
  }
}

Map<String, int> _manualItemSplitPreview(
  int total,
  List<String> participants,
  List<_ExpenseItemDraft> itemDrafts,
) {
  final preview = <String, int>{for (final id in participants) id: 0};
  for (final item in itemDrafts) {
    final users = item.assignedTo.where(participants.contains).toList();
    final safeUsers = users.isEmpty ? participants : users;
    final splits = equalShares(item.amountMinor, safeUsers);
    for (var index = 0; index < safeUsers.length; index++) {
      preview[safeUsers[index]] =
          (preview[safeUsers[index]] ?? 0) + splits[index];
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

String? _itemValidationMessage({
  required int total,
  required _BillTotals totals,
  required List<_ExpenseItemDraft> items,
}) {
  if (items.isEmpty) {
    return 'Add at least one bill item or skip item split.';
  }
  if (items.any((item) => item.name.text.trim().isEmpty)) {
    return 'Every item needs a name.';
  }
  if (items.any((item) => item.amountMinor == 0)) {
    return 'Every item needs an amount.';
  }
  if (totals.finalTotalMinor != total) {
    return 'Total item amount must equal the final expense total.';
  }
  return null;
}

String _billLineKindLabel(_BillLineKind kind) {
  return switch (kind) {
    _BillLineKind.item => 'Item',
    _BillLineKind.serviceCharge => 'Service charge',
    _BillLineKind.tax => 'VAT/Tax',
    _BillLineKind.discount => 'Discount',
    _BillLineKind.rounding => 'Rounding',
  };
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
  if (!store.isGroupAdmin(groupId, store.currentUserId)) {
    showSnack(context, 'Only group admins can add members.');
    return;
  }
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

Future<void> showLeaveGroupDialog(BuildContext context, String groupId) async {
  final store = StoreScope.of(context);
  final group = store.groupById(groupId);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Leave group?'),
        content: Text(
          'You will stop participating in new expenses for ${group.name}. Existing history remains available to the group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final error = store.leaveGroup(groupId);
              Navigator.pop(dialogContext);
              showSnack(context, error ?? 'You left ${group.name}.');
            },
            child: const Text('Leave group'),
          ),
        ],
      );
    },
  );
}

Future<void> showDisbandGroupDialog(
  BuildContext context,
  String groupId,
) async {
  final store = StoreScope.of(context);
  final group = store.groupById(groupId);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Disband group?'),
        content: Text(
          'This removes all active members from ${group.name} and hides the group from active group lists. Existing expense history is preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final error = store.disbandGroup(groupId);
              Navigator.pop(dialogContext);
              showSnack(context, error ?? '${group.name} was disbanded.');
            },
            child: const Text('Disband'),
          ),
        ],
      );
    },
  );
}

Future<void> showRemoveMemberDialog(
  BuildContext context,
  String groupId,
  GroupMember member,
) async {
  final store = StoreScope.of(context);
  final name = store.nameOf(member.userId);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text('Remove $name?'),
        content: Text(
          '$name will be inactive for new expenses. Existing balances and history are preserved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              store.removeGroupMember(groupId, member.userId);
              Navigator.pop(dialogContext);
              showSnack(context, '$name was removed from the group.');
            },
            child: const Text('Remove'),
          ),
        ],
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
  if (!store.isGroupAdmin(groupId, store.currentUserId)) {
    showSnack(context, 'Only group admins can change roles.');
    return;
  }
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
              ? 'Please select participants.'
              : splitTotal != total
              ? 'Participant split amounts must add up to the total expense.'
              : null;
          final readyToSave =
              total > 0 &&
              payerError == null &&
              splitError == null &&
              splitPreview.isNotEmpty;
          final canAddAnotherPayer =
              payerRows.length < members.length && payerTotal < total;

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
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final member in members)
                                ParticipantSelectorCard(
                                  user: store.userById(member.userId),
                                  selected: participants.contains(
                                    member.userId,
                                  ),
                                  onTap: () {
                                    setState(() {
                                      if (participants.contains(
                                        member.userId,
                                      )) {
                                        participants.remove(member.userId);
                                        custom.remove(member.userId);
                                        percentages.remove(member.userId);
                                        shares.remove(member.userId);
                                      } else {
                                        participants.add(member.userId);
                                      }
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
                              onPressed: canAddAnotherPayer
                                  ? () {
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
                                    }
                                  : null,
                              icon: const Icon(Icons.add),
                              label: const Text('Add another payer'),
                            ),
                          ),
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
                              maxValue: 100,
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
                          SplitPreview(
                            subtitle: splitMode == SplitMode.equal
                                ? 'Calculated equal split'
                                : '${enumLabel(splitMode)} split',
                            expenseTotal: total,
                            payerAmounts: payerAmounts,
                            participantShares: splitPreview,
                            participants: selectedParticipants,
                            showRoundingNote:
                                splitMode == SplitMode.equal &&
                                selectedParticipants.isNotEmpty &&
                                total % selectedParticipants.length != 0,
                            payerError: payerError,
                            splitError: splitError,
                            ready: readyToSave,
                          ),
                        ],
                      ),
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

class ParticipantSelectorCard extends StatelessWidget {
  const ParticipantSelectorCard({
    required this.user,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final AppUser user;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = toneColor(context, Tone.success);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 210, maxWidth: 260),
      child: Material(
        color: selected ? accent.withValues(alpha: 0.08) : scheme.surface,
        borderRadius: BorderRadius.circular(12),
        elevation: selected ? 1 : 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.70)
                    : scheme.outlineVariant,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                UserAvatar(user: user, small: true),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: selected ? accent : scheme.onSurface,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, size: 18, color: accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SplitPreview extends StatelessWidget {
  const SplitPreview({
    required this.subtitle,
    required this.expenseTotal,
    required this.payerAmounts,
    required this.participantShares,
    required this.participants,
    required this.showRoundingNote,
    required this.payerError,
    required this.splitError,
    required this.ready,
    super.key,
  });

  final String subtitle;
  final int expenseTotal;
  final Map<String, int> payerAmounts;
  final Map<String, int> participantShares;
  final List<String> participants;
  final bool showRoundingNote;
  final String? payerError;
  final String? splitError;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final people = <String>{
      ...payerAmounts.keys,
      ...participantShares.keys,
    }.toList()..sort((a, b) => store.nameOf(a).compareTo(store.nameOf(b)));
    final payerTotal = payerAmounts.values.fold<int>(
      0,
      (sum, amount) => sum + amount,
    );
    final splitTotal = participantShares.values.fold<int>(
      0,
      (sum, amount) => sum + amount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        PreviewCard(
          icon: Icons.groups_2_outlined,
          title: 'Participants & shares',
          trailing: _CountPill(
            label:
                '${participants.length} ${participants.length == 1 ? 'participant' : 'participants'}',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (participantShares.isEmpty)
                const _PreviewEmptyLine('Please select participants.')
              else
                _ResponsivePreviewGrid(
                  children: [
                    for (final entry in participantShares.entries)
                      ParticipantShareRow(
                        user: store.userById(entry.key),
                        amountMinor: entry.value,
                      ),
                  ],
                ),
              if (showRoundingNote) ...[
                const SizedBox(height: 10),
                _RoundingNote(
                  message:
                      'Rounded by ${statementMoney(1)} to match the total.',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        PreviewCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Paid by',
          trailing: _CountPill(
            label:
                '${payerAmounts.length} ${payerAmounts.length == 1 ? 'payer' : 'payers'}',
          ),
          child: payerAmounts.isEmpty
              ? const _PreviewEmptyLine('Please select who paid.')
              : Column(
                  children: [
                    for (final entry in payerAmounts.entries)
                      PayerRow(
                        user: store.userById(entry.key),
                        amountMinor: entry.value,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        PreviewCard(
          icon: Icons.balance_outlined,
          title: 'Net result',
          child: people.isEmpty
              ? const _PreviewEmptyLine(
                  'Select payers and participants to preview balances.',
                )
              : Column(
                  children: [
                    for (final id in people)
                      NetResultRow(
                        user: store.userById(id),
                        paidMinor: payerAmounts[id] ?? 0,
                        shareMinor: participantShares[id] ?? 0,
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        ValidationSummaryCard(
          expenseTotal: expenseTotal,
          payerTotal: payerTotal,
          splitTotal: splitTotal,
          payerError: payerError,
          splitError: splitError,
          ready: ready,
        ),
      ],
    );
  }
}

class PreviewCard extends StatelessWidget {
  const PreviewCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = toneColor(context, Tone.success);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class ParticipantShareRow extends StatelessWidget {
  const ParticipantShareRow({
    required this.user,
    required this.amountMinor,
    super.key,
  });

  final AppUser user;
  final int amountMinor;

  @override
  Widget build(BuildContext context) {
    return _PersonAmountRow(
      user: user,
      trailing: MoneyText(statementMoney(amountMinor)),
    );
  }
}

class PayerRow extends StatelessWidget {
  const PayerRow({required this.user, required this.amountMinor, super.key});

  final AppUser user;
  final int amountMinor;

  @override
  Widget build(BuildContext context) {
    return _PersonAmountRow(
      user: user,
      trailing: MoneyText('Paid ${statementMoney(amountMinor)}'),
    );
  }
}

class NetResultRow extends StatelessWidget {
  const NetResultRow({
    required this.user,
    required this.paidMinor,
    required this.shareMinor,
    super.key,
  });

  final AppUser user;
  final int paidMinor;
  final int shareMinor;

  @override
  Widget build(BuildContext context) {
    final net = paidMinor - shareMinor;
    final scheme = Theme.of(context).colorScheme;
    final accent = toneColor(context, Tone.success);
    final label = net > 0
        ? 'Gets back ${statementMoney(net)}'
        : net < 0
        ? 'Owes ${statementMoney(net.abs())}'
        : 'Settled';
    final color = net > 0 ? accent : scheme.onSurfaceVariant;
    final icon = net > 0
        ? Icons.call_received_rounded
        : net < 0
        ? Icons.call_made_rounded
        : Icons.check_circle_outline;
    return _PersonAmountRow(
      user: user,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class ValidationSummaryCard extends StatelessWidget {
  const ValidationSummaryCard({
    required this.expenseTotal,
    required this.payerTotal,
    required this.splitTotal,
    required this.payerError,
    required this.splitError,
    required this.ready,
    super.key,
  });

  final int expenseTotal;
  final int payerTotal;
  final int splitTotal;
  final String? payerError;
  final String? splitError;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final tone = ready ? Tone.success : Tone.warning;
    final color = toneColor(context, tone);
    final messages = [?payerError, ?splitError];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: ready ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: ready ? 0.42 : 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 560;
              final items = [
                _SummaryValue(
                  label: 'Expense total',
                  value: statementMoney(expenseTotal),
                ),
                _SummaryValue(
                  label: 'Total paid by payers',
                  value: statementMoney(payerTotal),
                ),
                _SummaryValue(
                  label: 'Total split among participants',
                  value: statementMoney(splitTotal),
                ),
              ];
              if (stacked) {
                return Column(
                  children: [
                    for (var index = 0; index < items.length; index++) ...[
                      if (index > 0) const SizedBox(height: 10),
                      items[index],
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var index = 0; index < items.length; index++) ...[
                    if (index > 0) const SizedBox(width: 12),
                    Expanded(child: items[index]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                ready ? Icons.check_circle : Icons.error_outline,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                ready
                    ? 'Status: Ready to save'
                    : 'Status: Fix totals before saving',
                style: TextStyle(color: color, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (messages.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final message in messages)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  message,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class MoneyText extends StatelessWidget {
  const MoneyText(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      value,
      textAlign: TextAlign.right,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
    );
  }
}

class _PersonAmountRow extends StatelessWidget {
  const _PersonAmountRow({required this.user, required this.trailing});

  final AppUser user;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          UserAvatar(user: user, small: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              user.displayName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(child: trailing),
        ],
      ),
    );
  }
}

class _ResponsivePreviewGrid extends StatelessWidget {
  const _ResponsivePreviewGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 560 ? 2 : 1;
        final spacing = columns == 1 ? 0.0 : 10.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 0,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth.isFinite ? itemWidth : null,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final accent = toneColor(context, Tone.success);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: TextStyle(color: accent, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RoundingNote extends StatelessWidget {
  const _RoundingNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final accent = toneColor(context, Tone.success);
    return Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            message,
            style: TextStyle(color: accent, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _PreviewEmptyLine extends StatelessWidget {
  const _PreviewEmptyLine(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
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

class _AmountGrid extends StatelessWidget {
  const _AmountGrid({
    required this.ids,
    required this.label,
    required this.values,
    required this.suffix,
    this.maxValue,
    this.onChanged,
  });

  final List<String> ids;
  final String label;
  final Map<String, String> values;
  final String suffix;
  final num? maxValue;
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
              inputFormatters: [
                if (maxValue != null) _MaxNumberInputFormatter(maxValue!),
              ],
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

class _MaxNumberInputFormatter extends TextInputFormatter {
  const _MaxNumberInputFormatter(this.maxValue);

  final num maxValue;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.trim();
    if (raw.isEmpty) {
      return newValue;
    }
    final value = num.tryParse(raw);
    if (value == null || value > maxValue) {
      return oldValue;
    }
    return newValue;
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
