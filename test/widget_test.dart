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
}
