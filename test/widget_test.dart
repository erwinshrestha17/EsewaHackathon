import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sajha_kharcha/features/auth/auth_controller.dart';
import 'package:sajha_kharcha/features/auth/models/user_profile.dart';
import 'package:sajha_kharcha/features/auth/screens/login_form.dart';
import 'package:sajha_kharcha/features/auth/screens/register_form.dart';
import 'package:sajha_kharcha/shared/design_system/app_colors.dart';
import 'package:sajha_kharcha/src/app.dart';
import 'package:sajha_kharcha/src/app_state.dart';
import 'package:sajha_kharcha/src/finance.dart';
import 'package:sajha_kharcha/src/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'login accepts phone plus saved M-PIN and rejects invalid values',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = AuthController();

      expect(
        () => controller.loginWithMpin(phone: 'demo', mPin: '1234'),
        throwsA(isA<AuthValidationException>()),
      );
      expect(
        () => controller.loginWithMpin(phone: '9800000001', mPin: '12'),
        throwsA(isA<AuthValidationException>()),
      );
      expect(
        () => controller.loginWithMpin(phone: '9800000001', mPin: '9999'),
        throwsA(isA<AuthValidationException>()),
      );

      await controller.loginWithMpin(
        phone: '9800000001',
        mPin: AuthController.demoMpin,
      );

      expect(controller.state.isLoggedIn, isTrue);
      expect(controller.state.activeUser?.displayName, 'Erwin Shrestha');
      expect(controller.state.activeUser?.phone, '9800000001');
    },
  );

  test('delete account clears saved profile and login state', () async {
    SharedPreferences.setMockInitialValues({
      'auth.hasSeenIntro': true,
      'auth.isLoggedIn': true,
      'auth.activeUserProfile': UserProfile.demo().toJsonString(),
      'auth.mPin': '1234',
      'auth.biometricEnabled': true,
    });
    final controller = AuthController();

    await controller.initialize();
    expect(controller.state.isLoggedIn, isTrue);

    await controller.deleteAccount();

    expect(controller.state.isLoggedIn, isFalse);
    expect(controller.state.activeUser, isNull);
  });

  testWidgets('login form requires phone number and M-PIN', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(),
        child: const MaterialApp(home: Scaffold(body: LoginForm())),
      ),
    );

    expect(find.text('Nepal mobile number'), findsOneWidget);
    expect(find.text('M-PIN'), findsOneWidget);
    expect(find.text('Login with M-PIN'), findsOneWidget);
    expect(find.text('Login with biometric'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nepal mobile number'),
      '98000000011',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'M-PIN'),
      '12345',
    );
    await tester.pump();

    final phoneField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Nepal mobile number'),
    );
    final pinField = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'M-PIN'),
    );
    expect(phoneField.controller?.text, '9800000001');
    expect(pinField.controller?.text, '1234');
  });

  testWidgets('sign up requires mobile number dob M-PIN then verifies OTP', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AuthController();

    await tester.pumpWidget(
      AuthScope(
        notifier: controller,
        child: MaterialApp(
          home: const Scaffold(body: RegisterForm()),
          routes: {'/main': (_) => const Scaffold(body: Text('Main'))},
        ),
      ),
    );

    expect(find.text('Nepal mobile number'), findsOneWidget);
    expect(find.text('Date of birth'), findsOneWidget);
    expect(find.text('Create M-PIN'), findsOneWidget);
    expect(find.text('User name'), findsNothing);
    expect(find.text('Password'), findsNothing);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nepal mobile number'),
      '9800000001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Date of birth'),
      '2000-01-02',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Create M-PIN'),
      '2468',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('6-digit OTP'), findsOneWidget);
    expect(find.text('Verify OTP & Create Account'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(FilledButton, 'Verify OTP & Create Account'),
    );
    await tester.pumpAndSettle();

    expect(controller.state.isLoggedIn, isTrue);
    expect(controller.state.activeUser?.displayName, 'Sajha Member');
    expect(controller.state.activeUser?.phone, '9800000001');
    expect(controller.state.activeUser?.dateOfBirth, DateTime(2000, 1, 2));
  });

  Future<void> pumpGroupsForAddExpense(
    WidgetTester tester,
    AppStore store,
  ) async {
    store.selectedGroupId = 'g-dashain';
    tester.view.physicalSize = const Size(1000, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );
  }

  Future<void> openManualEntry(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Add expense'));
    await tester.pumpAndSettle();

    expect(find.text('Align the bill inside the frame'), findsOneWidget);
    expect(find.text('Manual Entry'), findsOneWidget);

    await tester.drag(find.text('Manual Entry'), const Offset(0, -1800));
    await tester.pumpAndSettle();
  }

  testWidgets('Sajha Kharcha shell renders seeded dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({
      'auth.hasSeenIntro': true,
      'auth.isLoggedIn': true,
      'auth.activeUserProfile': UserProfile.demo().toJsonString(),
    });

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(),
        child: StoreScope(notifier: AppStore(), child: const SajhaKharchaApp()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Sajha Kharcha'), findsOneWidget);
    expect(find.text('Namaste, Erwin'), findsOneWidget);
    expect(find.text('Fast Demo Flow'), findsOneWidget);
    expect(find.text('Scan Receipt'), findsNothing);
    expect(find.text('Settle Now'), findsNothing);
    expect(find.text('View Groups'), findsNothing);
    expect(find.text('Add Expense'), findsNothing);
    expect(find.text('Create Group'), findsNothing);
    expect(find.text('Send Gift'), findsWidgets);
    expect(find.text('Activity'), findsNothing);
  });

  testWidgets('Main navigation includes Connections and excludes Scan tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({
      'auth.hasSeenIntro': true,
      'auth.isLoggedIn': true,
      'auth.activeUserProfile': UserProfile.demo().toJsonString(),
    });

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(),
        child: StoreScope(notifier: AppStore(), child: const SajhaKharchaApp()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Scan'), findsNothing);
    expect(find.text('Connections'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Connections'));
    await tester.pumpAndSettle();

    expect(find.text('Mobile Contacts'), findsOneWidget);

    await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Account'), findsOneWidget);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);

    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();

    expect(find.text('Settle balances first'), findsOneWidget);
    expect(
      find.text('You cannot delete your account while money is unsettled.'),
      findsOneWidget,
    );
    expect(find.text('• You still owe NPR 4020.'), findsOneWidget);
    expect(find.text('• You are still owed NPR 3400.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('connection report dialog requires note and blocks duplicates', (
    tester,
  ) async {
    final store = AppStore();
    final connection = store.connectionBetween('u-sita', 'u-maya')!;
    final reportedUser = store.userById('u-maya');

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () => showReportConnectionDialog(
                    context,
                    connection,
                    reportedUser,
                  ),
                  child: const Text('Open report'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Open report'));
    await tester.pumpAndSettle();

    expect(find.text('Report Maya Gurung'), findsOneWidget);
    expect(find.text('Report note'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Submit report'),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Report note'),
      'Repeated unwanted payment messages',
    );
    await tester.pump();

    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Submit report'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Submit report'));
    await tester.pumpAndSettle();

    expect(connection.reports, hasLength(1));
    expect(
      connection.reports.single.details,
      'Repeated unwanted payment messages',
    );
    expect(find.text('Report submitted for Maya Gurung.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Open report'));
    await tester.pumpAndSettle();

    expect(find.text('Report Maya Gurung'), findsNothing);
    expect(find.text('You have already reported Maya Gurung.'), findsOneWidget);
    expect(connection.reports, hasLength(1));
  });

  testWidgets('gift pool dialog switches between equal and threshold amounts', (
    tester,
  ) async {
    final store = AppStore();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return FilledButton(
                  onPressed: () => showCreateGiftPoolDialog(context),
                  child: const Text('Open gift pool'),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Open gift pool'));
    await tester.pumpAndSettle();

    expect(find.text('Contribution rule'), findsOneWidget);
    expect(find.text('Equal amount'), findsOneWidget);
    expect(find.text('Equal amount per contributor'), findsOneWidget);
    expect(find.text('Target amount'), findsNothing);

    await tester.tap(find.text('Min / max'));
    await tester.pumpAndSettle();

    expect(find.text('Target amount'), findsOneWidget);
    expect(find.text('Minimum contribution'), findsOneWidget);
    expect(find.text('Maximum contribution'), findsOneWidget);
    expect(find.text('Equal amount per contributor'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(
      store.giftPools.last.contributionRule,
      GiftPoolContributionRule.threshold,
    );
    expect(store.giftPools.last.minContributionAmountMinor, npr(250));
    expect(store.giftPools.last.maxContributionAmountMinor, npr(1100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dhukuti quick action opens Dhukuti Groups inside Groups tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    SharedPreferences.setMockInitialValues({
      'auth.hasSeenIntro': true,
      'auth.isLoggedIn': true,
      'auth.activeUserProfile': UserProfile.demo().toJsonString(),
    });

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(),
        child: StoreScope(notifier: AppStore(), child: const SajhaKharchaApp()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final dhukutiAction = find.text('Dhukuti').first;
    await tester.ensureVisible(dhukutiAction);
    await tester.tap(dhukutiAction);
    await tester.pumpAndSettle();

    expect(find.text('Dhukuti Groups'), findsOneWidget);
    expect(find.text('Digital Dhukuti'), findsOneWidget);
    expect(
      find.text('Expense groups stay separate from Dhukuti commitments.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Groups screen tolerates a stale selected group', (tester) async {
    final store = AppStore()..selectedGroupId = 'missing-group';

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Expense Groups'), findsWidgets);
    expect(find.text('Select a group'), findsNothing);
    expect(find.text('Groups overview'), findsOneWidget);
  });

  testWidgets('Groups screen does not open an expense group by default', (
    tester,
  ) async {
    final store = AppStore();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    expect(store.selectedGroupId, isNull);
    expect(find.text('Groups overview'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add expense'), findsNothing);
  });

  testWidgets('group overview colors debit red and credit green', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              BalancePill(amountMinor: -100),
              BalancePill(amountMinor: 100),
              StatTile(
                label: 'Debit',
                value: 'NPR 1',
                icon: Icons.call_made_outlined,
                tone: Tone.danger,
                tintValue: true,
              ),
              StatTile(
                label: 'Credit',
                value: 'NPR 2',
                icon: Icons.call_received_outlined,
                tone: Tone.success,
                tintValue: true,
              ),
            ],
          ),
        ),
      ),
    );

    final pills = tester.widgetList<StatusPill>(find.byType(StatusPill));
    expect(pills.elementAt(0).tone, Tone.danger);
    expect(pills.elementAt(1).tone, Tone.success);
    expect(
      tester.widget<Text>(find.text('NPR 1')).style?.color,
      AppColors.error,
    );
    expect(
      tester.widget<Text>(find.text('NPR 2')).style?.color,
      AppColors.success,
    );
  });

  testWidgets('create group dialog starts with members unselected', (
    tester,
  ) async {
    final store = AppStore();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () => showCreateGroupDialog(context),
                  child: const Text('Open create'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Open create'));
    await tester.pumpAndSettle();

    expect(find.text('Create Expense Group'), findsWidgets);
    expect(find.text('Dhukuti Group'), findsNothing);
    final memberChips = tester.widgetList<FilterChip>(find.byType(FilterChip));
    expect(memberChips, isNotEmpty);
    expect(memberChips.every((chip) => !chip.selected), isTrue);
    expect(
      find.text(
        'You will be added automatically as admin. Select only the people you want to invite.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('dhukuti create flow uses dhukuti-specific setup', (
    tester,
  ) async {
    final store = AppStore();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () => showCreateDhukutiGroupDialog(context),
                  child: const Text('Open dhukuti create'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Open dhukuti create'));
    await tester.pumpAndSettle();

    expect(find.text('Create Dhukuti Group'), findsWidgets);
    expect(find.text('Contribution amount'), findsOneWidget);
    expect(find.text('Gross pot per cycle'), findsOneWidget);
    expect(find.text('Default split: Equal'), findsNothing);
    final memberCards = tester
        .widgetList<ParticipantSelectorCard>(
          find.byType(ParticipantSelectorCard),
        )
        .toList();
    expect(memberCards, isNotEmpty);
    expect(find.text(store.currentUser.displayName), findsOneWidget);
    expect(memberCards.where((card) => card.selected), hasLength(1));
    expect(memberCards.first.selected, isTrue);
    expect(memberCards.first.enabled, isFalse);
  });

  testWidgets('Groups screen separates expense and Dhukuti groups', (
    tester,
  ) async {
    final store = AppStore();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Dashain Khasi Split'),
      320,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Dashain Khasi Split'), findsOneWidget);
    expect(find.text('Shrestha Family'), findsNothing);

    final dhukutiTab = find.text('Dhukuti Groups');
    await tester.ensureVisible(dhukutiTab);
    await tester.tapAt(tester.getCenter(dhukutiTab));
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Family Dashain Dhukuti'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Family Dashain Dhukuti'), findsOneWidget);
    expect(find.text('Dashain Khasi Split'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inactive current member no longer sees group detail', (
    tester,
  ) async {
    final store = AppStore()
      ..switchUser('u-rina')
      ..removeGroupMember('g-dashain', 'u-rina')
      ..selectedGroupId = 'g-dashain';

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Add expense'), findsNothing);
    expect(find.text('Dashain Khasi Split'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Groups screen uses general flow and table statement', (
    tester,
  ) async {
    final store = AppStore()..selectedGroupId = 'g-dashain';

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    expect(find.text('Festival Mode'), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Statement'));
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Paid By'), findsOneWidget);
    expect(find.text('Your Share'), findsOneWidget);
    expect(find.text('Group total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin sees rename action in group detail', (tester) async {
    final store = AppStore()..selectedGroupId = 'g-dashain';

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    expect(find.widgetWithText(OutlinedButton, 'Rename'), findsOneWidget);
  });

  testWidgets('admin sees rename action in dhukuti group detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = AppStore();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    final dhukutiTab = find.text('Dhukuti Groups');
    await tester.tapAt(tester.getCenter(dhukutiTab));
    await tester.pumpAndSettle();

    expect(find.text('Family Dashain Dhukuti'), findsWidgets);
    expect(find.widgetWithText(OutlinedButton, 'Rename'), findsOneWidget);
  });

  testWidgets('Add expense starts with participants and supports payer rows', (
    tester,
  ) async {
    final store = AppStore()..selectedGroupId = 'g-dashain';

    await pumpGroupsForAddExpense(tester, store);
    await openManualEntry(tester);

    // Select all participants to make split ready
    final participantCards = find.byType(ParticipantSelectorCard);
    final cardCount = participantCards.evaluate().length;
    for (var index = 0; index < cardCount; index++) {
      await tester.ensureVisible(participantCards.at(index));
      await tester.tap(participantCards.at(index));
      await tester.pumpAndSettle();
    }

    expect(find.text('Participants'), findsOneWidget);
    expect(find.text('Expense details'), findsOneWidget);
    expect(find.text('Who paid?'), findsWidgets);
    expect(find.text('Split preview'), findsOneWidget);
    expect(find.text('Calculated equal split'), findsOneWidget);
    expect(find.text('Net result'), findsOneWidget);
    expect(find.text('Status: Ready to save'), findsOneWidget);

    final addPayer = find.widgetWithText(OutlinedButton, 'Add another payer');
    await tester.ensureVisible(addPayer);
    expect(tester.widget<OutlinedButton>(addPayer).onPressed, isNull);

    final payerAmountField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Amount paid',
    );
    await tester.enterText(payerAmountField, '1300');
    await tester.pump();
    expect(tester.widget<OutlinedButton>(addPayer).onPressed, isNull);

    await tester.enterText(payerAmountField, '600');
    await tester.pump();
    expect(tester.widget<OutlinedButton>(addPayer).onPressed, isNotNull);

    tester.widget<OutlinedButton>(addPayer).onPressed!();
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save expense'),
    );
    expect(save.onPressed, isNull);
    expect(find.text('Enter a valid amount to continue.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manual entry places split mode before item list', (
    tester,
  ) async {
    final store = AppStore()..selectedGroupId = 'g-dashain';

    await pumpGroupsForAddExpense(tester, store);
    await openManualEntry(tester);

    final whoPaidTop = tester.getTopLeft(find.text('Who paid?').first).dy;
    final splitModeTop = tester.getTopLeft(find.text('Split mode').first).dy;
    final itemListTop = tester.getTopLeft(find.text('Item list').first).dy;

    expect(whoPaidTop, lessThan(splitModeTop));
    expect(splitModeTop, lessThan(itemListTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Manual entry defaults who paid to current user and remains editable',
    (tester) async {
      final store = AppStore()
        ..switchUser('u-arjun')
        ..selectedGroupId = 'g-dashain';

      await pumpGroupsForAddExpense(tester, store);
      await openManualEntry(tester);

      final payerDropdown = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Who paid?',
      );
      expect(payerDropdown, findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(payerDropdown)
            .initialValue,
        'u-arjun',
      );

      await tester.tap(payerDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sita Shrestha').last);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<DropdownButtonFormField<String>>(payerDropdown)
            .initialValue,
        'u-sita',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Add expense participant cards toggle split preview', (
    tester,
  ) async {
    final store = AppStore()..selectedGroupId = 'g-dashain';

    await pumpGroupsForAddExpense(tester, store);
    await openManualEntry(tester);

    // Initially, no participants are selected
    expect(find.text('Select at least one participant.'), findsWidgets);

    final participantCards = find.byType(ParticipantSelectorCard);
    final cardCount = participantCards.evaluate().length;
    expect(cardCount, greaterThan(0));

    // Select all participants
    for (var index = 0; index < cardCount; index++) {
      await tester.ensureVisible(participantCards.at(index));
      await tester.tap(participantCards.at(index));
      await tester.pumpAndSettle();
    }

    // Now they are selected, error should disappear
    expect(find.text('Select at least one participant.'), findsNothing);

    // Deselect all participants
    for (var index = 0; index < cardCount; index++) {
      await tester.ensureVisible(participantCards.at(index));
      await tester.tap(participantCards.at(index));
      await tester.pumpAndSettle();
    }

    // Error should show again
    expect(find.text('Select at least one participant.'), findsWidgets);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save expense'),
    );
    expect(save.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Group detail shows latest activity summary with full view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final store = AppStore();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: MaterialApp(
          home: GroupDetail(
            group: store.groupById('g-dashain'),
            activityTimelineLimit: 5,
          ),
        ),
      ),
    );

    expect(find.text('View all activity'), findsOneWidget);
    expect(find.byIcon(Icons.timeline).evaluate().length <= 5, isTrue);

    final viewAll = find.widgetWithText(OutlinedButton, 'View all activity');
    await tester.tap(viewAll);
    await tester.pumpAndSettle();

    expect(find.text('All'), findsOneWidget);
    expect(find.text('Expenses'), findsWidgets);
    expect(find.text('Settlements'), findsOneWidget);
    expect(find.text('Members'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add expense item list row has only Name and Amount fields', (
    tester,
  ) async {
    final store = AppStore()..selectedGroupId = 'g-dashain';

    await pumpGroupsForAddExpense(tester, store);
    await openManualEntry(tester);

    final skipItemSplitSwitch = find.widgetWithText(
      SwitchListTile,
      'Skip item split and use total amount',
    );
    await tester.ensureVisible(skipItemSplitSwitch);
    await tester.tap(skipItemSplitSwitch);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, '+ Add item'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '+ Add item'));
    await tester.pumpAndSettle();

    final itemName = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Item name',
    );
    expect(itemName, findsWidgets);
    expect(tester.widget<TextField>(itemName.first).controller?.text, isEmpty);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Amount',
      ),
      findsWidgets,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Qty',
      ),
      findsNothing,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Unit price',
      ),
      findsNothing,
    );
    expect(find.text('Split this item by shares'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            (widget.decoration?.labelText ?? '').endsWith('shares'),
      ),
      findsNothing,
    );
    expect(find.text('Service charge, VAT, and discount'), findsOneWidget);
    expect(find.text('Service charge'), findsWidgets);
    expect(find.text('VAT'), findsOneWidget);
    expect(find.text('Discount'), findsOneWidget);
    expect(find.text('Line type'), findsNothing);
    expect(
      find.widgetWithText(OutlinedButton, 'Add VAT/adjustment'),
      findsNothing,
    );
    expect(find.byTooltip('Delete adjustment'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Manual entry includes service charge in bill total', (
    tester,
  ) async {
    final store = AppStore()..selectedGroupId = 'g-dashain';

    await pumpGroupsForAddExpense(tester, store);
    await openManualEntry(tester);

    final skipItemSplitSwitch = find.widgetWithText(
      SwitchListTile,
      'Skip item split and use total amount',
    );
    await tester.ensureVisible(skipItemSplitSwitch);
    await tester.tap(skipItemSplitSwitch);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '+ Add item'));
    await tester.pumpAndSettle();

    final itemAmount = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Amount',
    );
    await tester.enterText(itemAmount.first, '100');
    await tester.pump();

    final serviceChargeAmount = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Service charge amount',
    );
    await tester.enterText(serviceChargeAmount, '50');
    await tester.pump();

    final totalAmountField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Total amount',
    );
    expect(
      tester.widget<TextField>(totalAmountField).controller?.text,
      '150.00',
    );
    expect(find.text('Service charge'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Add expense total amount and paid fields are editable in item split mode',
    (tester) async {
      final store = AppStore()..selectedGroupId = 'g-dashain';

      await pumpGroupsForAddExpense(tester, store);
      await openManualEntry(tester);

      // Toggle skip item split off to activate item split mode
      final skipItemSplitSwitch = find.widgetWithText(
        SwitchListTile,
        'Skip item split and use total amount',
      );
      await tester.ensureVisible(skipItemSplitSwitch);
      await tester.tap(skipItemSplitSwitch);
      await tester.pumpAndSettle();

      // Verify total amount field is editable in item split mode
      final totalAmountField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Total amount',
      );
      expect(totalAmountField, findsOneWidget);

      await tester.enterText(totalAmountField, '1500');
      await tester.pump();

      final totalTextField = tester.widget<TextField>(totalAmountField);
      expect(totalTextField.controller?.text, '1500');

      // Verify paid amount field is editable
      final payerAmountField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Amount paid',
      );
      expect(payerAmountField, findsOneWidget);

      await tester.enterText(payerAmountField, '1000');
      await tester.pump();

      final payerTextField = tester.widget<TextField>(payerAmountField);
      expect(payerTextField.controller?.text, '1000');

      expect(tester.takeException(), isNull);
    },
  );
}
