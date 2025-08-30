// This is a basic Flutter widget test for Gavra Android app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gavra_android/main.dart';

void main() {
  testWidgets('Gavra Android app basic test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Give the app time to initialize async operations
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify that the app starts without crashing
    // Look for CircularProgressIndicator (loading state)
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('App widget creation test', (WidgetTester tester) async {
    // Verify that MyApp widget can be created
    const app = MyApp();
    expect(app, isA<MyApp>());
    expect(app.runtimeType, MyApp);
  });
}
