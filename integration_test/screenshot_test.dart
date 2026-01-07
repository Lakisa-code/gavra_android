import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/main.dart' as app;
import 'package:integration_test/integration_test.dart';

/// 📸 Screenshot test za App Store
/// Pravi screenshots za iPhone i iPad
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Store Screenshots', () {
    testWidgets('Take screenshots for App Store', (tester) async {
      // Pokreni app
      app.main();
      
      // Čekaj da se app učita i permissions dialog prikaže
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Screenshot 1: Permission Screen (dozvole)
      print('📸 Taking screenshot 1: Permissions');
      await takeScreenshot(binding, '01_permissions');

      // Sačekaj malo pre klika
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Klikni na PRESKOČI dugme - traži TextButton sa tim tekstom
      final preskociButton = find.widgetWithText(TextButton, 'PRESKOČI');
      final preskociText = find.text('PRESKOČI');
      
      print('🔍 Looking for PRESKOČI button...');
      print('   TextButton finder: ${preskociButton.evaluate().length} found');
      print('   Text finder: ${preskociText.evaluate().length} found');

      if (preskociButton.evaluate().isNotEmpty) {
        print('✅ Found PRESKOČI TextButton, tapping...');
        await tester.tap(preskociButton);
      } else if (preskociText.evaluate().isNotEmpty) {
        print('✅ Found PRESKOČI text, tapping...');
        await tester.tap(preskociText);
      } else {
        print('❌ PRESKOČI not found, trying ODOBRI...');
        final odobriButton = find.widgetWithText(TextButton, 'ODOBRI');
        if (odobriButton.evaluate().isNotEmpty) {
          await tester.tap(odobriButton);
        }
      }

      // Čekaj da se dialog zatvori i WelcomeScreen prikaže
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Screenshot 2: Welcome Screen
      print('📸 Taking screenshot 2: Welcome');
      await takeScreenshot(binding, '02_welcome');

      // Sačekaj da se animacije završe
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Klikni na "O nama" dugme - koristi ancestor da nađe GestureDetector
      print('🔍 Looking for O nama button...');
      
      final oNamaText = find.text('O nama');
      print('   Text finder: ${oNamaText.evaluate().length} found');
      
      if (oNamaText.evaluate().isNotEmpty) {
        // Pronađi GestureDetector koji sadrži "O nama" text
        final oNamaGesture = find.ancestor(
          of: oNamaText,
          matching: find.byType(GestureDetector),
        );
        
        print('   GestureDetector finder: ${oNamaGesture.evaluate().length} found');
        
        if (oNamaGesture.evaluate().isNotEmpty) {
          print('✅ Found O nama GestureDetector, tapping...');
          await tester.tap(oNamaGesture.first);
        } else {
          print('⚠️ GestureDetector not found, tapping text directly...');
          await tester.tap(oNamaText);
        }
        
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // Screenshot 3: O nama Screen
        print('📸 Taking screenshot 3: O nama');
        await takeScreenshot(binding, '03_onama');
      } else {
        print('❌ O nama not found! Taking fallback screenshot...');
        // Fallback - još jedan welcome screenshot
        await takeScreenshot(binding, '03_welcome_alt');
      }
      
      print('✅ All screenshots completed!');
    });
  });
}

/// Helper funkcija za screenshot
Future<void> takeScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  // Za iOS simulator, koristimo convertFlutterSurfaceToImage
  await binding.convertFlutterSurfaceToImage();
  await Future.delayed(const Duration(milliseconds: 500));

  final List<int> bytes = await binding.takeScreenshot(name);

  // Sačuvaj screenshot
  final directory = Directory('screenshots');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  final file = File('screenshots/$name.png');
  await file.writeAsBytes(bytes);
  print('📸 Screenshot saved: ${file.path}');
}
