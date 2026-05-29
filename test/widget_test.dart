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
}
