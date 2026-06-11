// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:collected_issues/main.dart';
import 'package:collected_issues/repositories/local_issue_repository.dart';

void main() {
  testWidgets('Authentication gate screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(repository: LocalIssueRepository()));

    // Verify that the Authentication / PinScreen is shown first
    expect(find.text('COLLECTED ISSUE'), findsOneWidget);
    expect(find.text('Enter PIN to Access Database'), findsOneWidget);

    // Verify presence of number keys on the pin screen keypad
    expect(find.text('1'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
  });
}
