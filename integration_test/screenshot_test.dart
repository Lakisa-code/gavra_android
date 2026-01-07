import 'dart:io';

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
      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // Screenshot 1: Permission Screen (dozvole)
      await takeScreenshot(binding, '01_permissions');

      // Sačekaj malo
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Klikni na PRESKOČI ili ODOBRI dugme
      final preskociButton = find.text('PRESKOČI');
      final odobriButton = find.text('ODOBRI');

      if (preskociButton.evaluate().isNotEmpty) {
        await tester.tap(preskociButton);
      } else if (odobriButton.evaluate().isNotEmpty) {
        await tester.tap(odobriButton);
      }

      await tester.pumpAndSettle();
      await Future.delayed(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Screenshot 2: Welcome Screen
      await takeScreenshot(binding, '02_welcome');

      // Sačekaj da se animacije završe
      await Future.delayed(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Klikni na "O nama" dugme
      final oNamaButton = find.text('O nama');
      if (oNamaButton.evaluate().isNotEmpty) {
        await tester.tap(oNamaButton);
        await tester.pumpAndSettle();
        await Future.delayed(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // Screenshot 3: O nama Screen
        await takeScreenshot(binding, '03_onama');
      } else {
        // Fallback - još jedan welcome screenshot
        await takeScreenshot(binding, '03_welcome_alt');
      }
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
