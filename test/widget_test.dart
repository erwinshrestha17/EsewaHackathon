import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sangai/src/app.dart';
import 'package:sangai/src/app_state.dart';

void main() {
  testWidgets('Sangai shell renders seeded dashboard', (tester) async {
    await tester.pumpWidget(
      StoreScope(notifier: AppStore(), child: const SangaiApp()),
    );

    expect(find.text('Sangai'), findsOneWidget);
    expect(find.textContaining('Namaste'), findsOneWidget);
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
    expect(find.text('Groups'), findsOneWidget);
    expect(find.text('Select a group'), findsNothing);
  });

  testWidgets('inactive current member cannot open add expense flow', (
    tester,
  ) async {
    final store = AppStore()
      ..removeGroupMember('g-dashain', 'u-sita')
      ..selectedGroupId = 'g-dashain';

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    final addExpense = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add expense'),
    );
    expect(addExpense.onPressed, isNull);
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

    await tester.pumpWidget(
      StoreScope(
        notifier: store,
        child: const MaterialApp(home: GroupsScreen()),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Add expense'));
    await tester.pumpAndSettle();

    expect(find.text('Participants'), findsOneWidget);
    expect(find.text('Expense details'), findsOneWidget);
    expect(find.text('Who paid?'), findsWidgets);
    expect(find.text('Split preview'), findsOneWidget);
    expect(find.text('Status: Ready to save'), findsOneWidget);

    final addPayer = find.widgetWithText(OutlinedButton, 'Add another payer');
    await tester.ensureVisible(addPayer);
    await tester.tap(addPayer);
    await tester.pumpAndSettle();

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save expense'),
    );
    expect(save.onPressed, isNull);
    expect(find.text('Enter the amount paid by each payer.'), findsOneWidget);
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
