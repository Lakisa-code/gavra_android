import 'package:flutter_test/flutter_test.dart';
import '../lib/services/geocoding_service.dart';

void main() {
  group('Nova mesta test', () {
    test('Potporanj i Orešac dozovljeni', () async {
      print('Testing Potporanj...');
      final potporanjResult =
          await GeocodingService.getKoordinateZaAdresu('Potporanj', 'Glavna 1');
      print(
          'Potporanj result: ${potporanjResult != null ? "✅ ALLOWED" : "❌ BLOCKED"}');

      print('Testing Orešac...');
      final oresacResult =
          await GeocodingService.getKoordinateZaAdresu('Orešac', 'Glavna 1');
      print(
          'Orešac result: ${oresacResult != null ? "✅ ALLOWED" : "❌ BLOCKED"}');

      // Također test i Vraćev Gaj problem
      print('Testing Vraćev Gaj...');
      final vracevResult = await GeocodingService.getKoordinateZaAdresu(
          'Vraćev Gaj', 'Glavna 1');
      print(
          'Vraćev Gaj result: ${vracevResult != null ? "✅ ALLOWED" : "❌ BLOCKED"}');
    });
  });
}
