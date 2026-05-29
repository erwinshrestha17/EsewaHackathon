import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangai/features/auth/auth_controller.dart';
import 'package:sangai/features/auth/models/user_profile.dart';
import 'package:sangai/features/auth/screens/login_form.dart';
import 'package:sangai/src/app.dart';
import 'package:sangai/src/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('login accepts only Nepal mobile numbers', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = AuthController();

    expect(
      () =>
          controller.login(identifier: 'demo@esewa', password: 'demo-password'),
      throwsA(isA<AuthValidationException>()),
    );
    expect(
      () =>
          controller.login(identifier: '980000001', password: 'demo-password'),
      throwsA(isA<AuthValidationException>()),
    );
    expect(
      () => controller.login(
        identifier: '98000000011',
        password: 'demo-password',
      ),
      throwsA(isA<AuthValidationException>()),
    );
    expect(
      () => controller.login(
        identifier: '+977 9800000001',
        password: 'demo-password',
      ),
      throwsA(isA<AuthValidationException>()),
    );

    await controller.login(identifier: '9800000001', password: 'demo-password');

    expect(controller.state.isLoggedIn, isTrue);
    expect(controller.state.activeUser?.phone, '9800000001');
  });

  testWidgets('login form asks for Nepal mobile and removes QR login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      AuthScope(
        notifier: AuthController(),
        child: const MaterialApp(home: Scaffold(body: LoginForm())),
      ),
    );

    expect(find.text('Nepal mobile number'), findsOneWidget);
    expect(find.text('+977 '), findsOneWidget);
    expect(find.text('Login with QR'), findsNothing);

    await tester.enterText(find.byType(TextFormField).first, '98000000011');
    await tester.pump();

    final phoneField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(phoneField.controller?.text, '9800000001');
  });

  Future<void> pumpGroupsForAddExpense(
    WidgetTester tester,
    AppStore store,
  ) async {
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
        child: StoreScope(notifier: AppStore(), child: const SangaiApp()),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Sajha Kharcha'), findsOneWidget);
    expect(find.text('Namaste, Erwin'), findsOneWidget);
    expect(find.text('Fast Demo Flow'), findsOneWidget);
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
    final store = AppStore();

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    expect(find.text('Festival Mode'), findsNothing);
    expect(find.text('Dashain Khasi Split'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Statement'));
    await tester.pumpAndSettle();

    expect(find.text('Date'), findsOneWidget);
    expect(find.text('Paid By'), findsOneWidget);
    expect(find.text('Your Share'), findsOneWidget);
    expect(find.text('Total group expenses'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add expense starts with participants and supports payer rows', (
    tester,
  ) async {
    final store = AppStore();

    await pumpGroupsForAddExpense(tester, store);
    await openManualEntry(tester);

    expect(find.text('Participants'), findsOneWidget);
    expect(find.text('Expense details'), findsOneWidget);
    expect(find.text('Who paid?'), findsWidgets);
    expect(find.text('Split preview'), findsOneWidget);
    expect(find.text('Calculated equal split'), findsOneWidget);
    expect(find.text('Participants & shares'), findsOneWidget);
    expect(find.text('Paid by'), findsOneWidget);
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
    expect(find.text('Enter the amount paid by each payer.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add expense participant cards toggle split preview', (
    tester,
  ) async {
    final store = AppStore();

    await pumpGroupsForAddExpense(tester, store);
    await openManualEntry(tester);

    final participantCards = find.byType(ParticipantSelectorCard);
    final cardCount = participantCards.evaluate().length;
    expect(cardCount, greaterThan(0));

    for (var index = 0; index < cardCount; index++) {
      await tester.ensureVisible(participantCards.at(index));
      await tester.tap(participantCards.at(index));
      await tester.pump();
    }

    expect(find.text('Please select participants.'), findsWidgets);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save expense'),
    );
    expect(save.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add expense percentage split rejects values above 100', (
    tester,
  ) async {
    final store = AppStore();

    await pumpGroupsForAddExpense(tester, store);
    await openManualEntry(tester);

    final splitModeDropdown = find.byWidgetPredicate(
      (widget) =>
          widget.runtimeType.toString().startsWith('DropdownButtonFormField'),
    );
    await tester.ensureVisible(splitModeDropdown.last);
    await tester.tap(splitModeDropdown.last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Percentage').last);
    await tester.pumpAndSettle();

    final percentageField = find.widgetWithText(
      TextFormField,
      'Sita Shrestha Percentage',
    );
    expect(percentageField, findsWidgets);

    await tester.enterText(percentageField.first, '101');
    await tester.pump();
    expect(find.text('101'), findsNothing);

    await tester.enterText(percentageField.first, '100');
    await tester.pump();
    expect(find.text('100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Group detail shows latest activity summary with full view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 4200);
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
}
