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
  testWidgets('App widget creation test', (WidgetTester tester) async {
    // Verify that MyApp widget can be created
    const app = MyApp();
    expect(app, isA<MyApp>());
    expect(app.runtimeType, MyApp);
  });

  testWidgets('Gavra Android app builds without crashing',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Wait for the app to settle after initial build
    await tester.pump();

    // Verify that the app built successfully by checking for MaterialApp
    expect(find.byType(MaterialApp), findsOneWidget);

    // The app should build without throwing exceptions
    // No need to check for specific widgets since they depend on external services
  });
}
