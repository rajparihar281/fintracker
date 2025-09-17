import 'package:flutter_test/flutter_test.dart';

Future<void> theyShouldSeeAGreetingMessage(WidgetTester tester) async {
  await tester.pumpAndSettle();
  expect(find.text('Welcome, Guest!'), findsOneWidget);
}
