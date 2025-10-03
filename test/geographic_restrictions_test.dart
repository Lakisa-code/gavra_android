import 'package:flutter_test/flutter_test.dart';
import '../lib/services/geocoding_service.dart';
import '../lib/services/advanced_geocoding_service.dart';
import '../lib/services/smart_address_autocomplete_service.dart';

void main() {
  group('Geographic Restrictions Tests', () {
    test('GeocodingService blocks cities outside BC/Vršac', () async {
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
        final result =
            await GeocodingService.getKoordinateZaAdresu(city, 'Glavna 1');
        print(
            'Allowed city $city: ${result != null ? "✅ PASSED" : "❌ FAILED"}');
      }

      // Test zabranjenih gradova
      for (final city in blockedCities) {
        final result =
            await GeocodingService.getKoordinateZaAdresu(city, 'Glavna 1');
        print(
            'Blocked city $city: ${result == null ? "✅ BLOCKED" : "❌ NOT BLOCKED"}');
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
