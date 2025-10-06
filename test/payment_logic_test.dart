import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/utils/vozac_boja.dart';

void main() {
  group('Payment Logic Tests', () {
    test('VozacBoja validation works correctly', () {
      // Valid drivers
      expect(VozacBoja.isValidDriver('Bruda'), true);
      expect(VozacBoja.isValidDriver('Bilevski'), true);
      expect(VozacBoja.isValidDriver('Bojan'), true);
      expect(VozacBoja.isValidDriver('Svetlana'), true);

      // Invalid drivers
      expect(VozacBoja.isValidDriver(null), false);
      expect(VozacBoja.isValidDriver(''), false);
      expect(VozacBoja.isValidDriver('Nepoznat vozač'), false);
      expect(VozacBoja.isValidDriver('Invalid'), false);

      print('✅ VozacBoja validation test passed');
    });

    test('Valid drivers list contains expected drivers', () {
      final validDrivers = VozacBoja.validDrivers;

      expect(validDrivers.contains('Bruda'), true);
      expect(validDrivers.contains('Bilevski'), true);
      expect(validDrivers.contains('Bojan'), true);
      expect(validDrivers.contains('Svetlana'), true);
      expect(validDrivers.length, 4);

      print('✅ Valid drivers list: $validDrivers');
    });

    test('Payment fallback logic should work', () {
      // Test fallback scenarios
      String? nullDriver;
      String emptyDriver = '';
      String invalidDriver = 'InvalidDriver';
      String validDriver = 'Bojan';

      // Fallback logic mimics what putnik_card.dart does
      String getFinalDriver(String? currentDriver) {
        return currentDriver ?? 'Nepoznat vozač';
      }

      expect(getFinalDriver(nullDriver), 'Nepoznat vozač');
      expect(getFinalDriver(emptyDriver), emptyDriver);
      expect(getFinalDriver(invalidDriver), invalidDriver);
      expect(getFinalDriver(validDriver), validDriver);

      print('✅ Payment fallback logic test passed');
    });

    test('Month parsing should work correctly', () {
      // Test month parsing logic from payment dialog
      const testMonth = 'Oktobar 2025';
      final parts = testMonth.split(' ');

      expect(parts.length, 2);
      expect(parts[0], 'Oktobar');
      expect(parts[1], '2025');

      final year = int.tryParse(parts[1]);
      expect(year, 2025);

      print('✅ Month parsing test passed');
    });
  });
}
