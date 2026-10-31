// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.



import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:testing/main.dart';

void main() {
  testWidgets('SideQuest app starts successfully',
      (WidgetTester tester) async {

    // Launch the application.
    await tester.pumpWidget(const SideQuestApp());

    // Verify the splash screen appears.
    expect(find.text('SideQuest'), findsOneWidget);

    // Advance the test clock by 10 seconds.
    await tester.pump(const Duration(seconds: 10));

    // Process the navigation to the login screen.
    await tester.pump();

    // Verify that the application is still running.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}

