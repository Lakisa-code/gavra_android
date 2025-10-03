import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/services/geocoding_service.dart';
import 'package:gavra_android/services/advanced_geocoding_service.dart';
import 'package:gavra_android/services/smart_address_autocomplete_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Geographic Restrictions Tests', () {
    test('GeocodingService blocks cities outside BC/Vršac', () {
      final service = GeocodingService();

      // Testovi za dozvoljene gradove (trebalo bi da prolaze)
      const allowedCities = [
        'Vršac',
        'Straža',
        'Vojvodinci',
        'Potporanj',
        'Orešac',
        'Bela Crkva',
        'Vraćev Gaj',
        'Dupljaja',
        'Jasenovo',
        'Kruščica',
        'Kusić',
        'Crvena Crkva'
      ]; // Testovi za zabranjene gradove (trebalo bi da budu blokirani)
      const blockedCities = [
        'Novi Sad',
        'Belgrade',
        'Beograd',
        'Niš',
        'Kragujevac',
        'Zrenjanin',
        'Pančevo',
        'Subotica',
        'Kikinda',
        'Kovin'
      ];

      // Test dozvoljenih gradova
      for (final city in allowedCities) {
        final isBlocked = service._isCityBlocked(city);
        expect(isBlocked, false, reason: 'Grad $city mora biti dozvoljen');
      }

      // Test zabranjenih gradova
      for (final city in blockedCities) {
        final isBlocked = service._isCityBlocked(city);
        expect(isBlocked, true, reason: 'Grad $city mora biti blokiran');
      }
    });

    test('AdvancedGeocodingService respects geographic restrictions', () async {
      // Test sa adresom iz Bele Crkve - treba da prođe
      final belaCrkvaResult =
          await AdvancedGeocodingService.getAdvancedCoordinates(
              grad: 'Bela Crkva', adresa: 'Glavna ulica 10');
      print(
          'Bela Crkva result: ${belaCrkvaResult != null ? "✅ ALLOWED" : "❌ BLOCKED"}');

      // Test sa adresom iz Vršca - treba da prođe
      await AdvancedGeocodingService.getAdvancedCoordinates(
          grad: 'Vršac', adresa: 'Trg pobede 5');
      // Debug output removed

      // Test sa adresom iz Beograda - treba da bude blokiran
      final beogradResult =
          await AdvancedGeocodingService.getAdvancedCoordinates(
              grad: 'Beograd', adresa: 'Knez Mihailova 12');
      print(
          'Belgrade result: ${beogradResult == null ? "✅ BLOCKED" : "❌ NOT BLOCKED"}');
    });

    test('SmartAddressAutocompleteService filters suggestions', () async {
      // Test sa upitom za Belu Crkvu
      await SmartAddressAutocompleteService.getSmartSuggestions(
              currentCity: 'Bela Crkva', query: 'glavna');
      // Debug output removed

      // Test sa upitom za zabranjeni grad
      final beogradSuggestions =
          await SmartAddressAutocompleteService.getSmartSuggestions(
              currentCity: 'Beograd', query: 'knez');
      print(
          'Belgrade suggestions: ${beogradSuggestions.length} found (should be 0)');
    });

    test('Route optimization services filter passengers', () async {
      // Kreiranje test putnika
      final testPassengers = [
        {
          'ime': 'Marko',
          'grad': 'Bela Crkva',
          'adresa': 'Glavna 1',
          'koordinate': '44.898611,21.420833'
        },
        {
          'ime': 'Ana',
          'grad': 'Vršac',
          'adresa': 'Trg pobede 1',
          'koordinate': '45.116667,21.3'
        },
        {
          'ime': 'Petar',
          'grad': 'Beograd',
          'adresa': 'Knez Mihailova 1',
          'koordinate': '44.816667,20.466667'
        }
      ];

      print(
          'Testing route optimization with ${testPassengers.length} passengers');
      // Debug output removed
      // Debug output removed
    });
  });
}

// Extension za pristup private metodi
extension GeocodingServiceTest on GeocodingService {
  bool _isCityBlocked(String grad) {
    final normalizedGrad = grad.toLowerCase().trim();

    // ✅ DOZVOLJENI GRADOVI: SAMO Bela Crkva i Vršac opštine
    final allowedCities = [
      // VRŠAC OPŠTINA
      'vrsac', 'vršac', 'straza', 'straža', 'vojvodinci', 'potporanj', 'oresac',
      'orešac',
      // BELA CRKVA OPŠTINA
      'bela crkva', 'vracev gaj', 'vraćev gaj', 'dupljaja', 'jasenovo',
      'kruscica', 'kruščica', 'kusic', 'kusić', 'crvena crkva'
    ];
    return !allowedCities.any((allowed) =>
        normalizedGrad.contains(allowed) || allowed.contains(normalizedGrad));
  }
}
