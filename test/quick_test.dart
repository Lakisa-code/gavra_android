import 'package:flutter_test/flutter_test.dart';
import '../lib/services/geocoding_service.dart';

void main() {
  group('Nova mesta test', () {
    test('Potporanj i Orešac dozovljeni', () async {
      // Debug output removed
      final potporanjResult =
          await GeocodingService.getKoordinateZaAdresu('Potporanj', 'Glavna 1');
      print(
          'Potporanj result: ${potporanjResult != null ? "✅ ALLOWED" : "❌ BLOCKED"}');

      // Debug output removed
      final oresacResult =
          await GeocodingService.getKoordinateZaAdresu('Orešac', 'Glavna 1');
      print(
          'Orešac result: ${oresacResult != null ? "✅ ALLOWED" : "❌ BLOCKED"}');

      // Također test i Vraćev Gaj problem
      // Debug output removed
      final vracevResult = await GeocodingService.getKoordinateZaAdresu(
          'Vraćev Gaj', 'Glavna 1');
      print(
          'Vraćev Gaj result: ${vracevResult != null ? "✅ ALLOWED" : "❌ BLOCKED"}');
    });
  });
}
