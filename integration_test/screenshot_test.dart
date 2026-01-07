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
      // Pokreni app (SCREENSHOT_MODE=true preskače permissions dialog)
      app.main();

      // Čekaj da se app učita
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Proveri da li je permissions dialog prikazan (ne bi trebalo u SCREENSHOT_MODE)
      final preskociButton = find.text('PRESKOČI');
      if (preskociButton.evaluate().isNotEmpty) {
        print('⚠️ Permissions dialog shown, tapping PRESKOČI...');
        await tester.tap(preskociButton);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
        await tester.pumpAndSettle();
      }

      // Screenshot 1: Welcome Screen (DOBRODOŠLI)
      print('📸 Taking screenshot 1: Welcome');
      await takeScreenshot(binding, '01_welcome');

      // Sačekaj da se animacije završe
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Klikni na "O nama" dugme
      print('🔍 Looking for O nama button...');
      final oNamaText = find.text('O nama');
      print('   Text finder: ${oNamaText.evaluate().length} found');

      if (oNamaText.evaluate().isNotEmpty) {
        print('✅ Found O nama, tapping...');
        await tester.tap(oNamaText);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 3));
        await tester.pumpAndSettle();

        // Screenshot 2: O nama Screen
        print('📸 Taking screenshot 2: O nama');
        await takeScreenshot(binding, '02_onama');
      } else {
        print('❌ O nama not found!');
      }

      // Vrati se nazad na Welcome
      final backButton = find.byType(BackButton);
      final iconBack = find.byIcon(Icons.arrow_back);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
      } else if (iconBack.evaluate().isNotEmpty) {
        await tester.tap(iconBack);
      } else {
        // Probaj Navigator.pop simulaciju
        print('⚠️ No back button found, using Navigator.pop...');
      }
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Screenshot 3: Welcome opet ili nešto drugo
      print('📸 Taking screenshot 3: Final');
      await takeScreenshot(binding, '03_screen');

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

  // takeScreenshot čuva screenshot automatski - ne treba ručno čuvanje
  await binding.takeScreenshot(name);
  print('📸 Screenshot taken: $name');
}
