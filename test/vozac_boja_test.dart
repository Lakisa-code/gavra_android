import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/utils/vozac_boja.dart';
import '../lib/services/vozac_mapping_service.dart';

/// Test konzistentnosti boja vozača između svih servisa i ekrana
void main() {
  group('🎨 Provjera boja za svakog vozača', () {

    // Očekivane boje za svakog vozača
    final Map<String, int> expectedColors = {
      'Bilevski': 0xFFFF9800, // narandžasta
      'Bruda': 0xFF7C4DFF,    // ljubičasta
      'Bojan': 0xFF00E5FF,    // svetla cyan plava
      'Svetlana': 0xFFFF1493, // deep pink
    };

    group('🔍 VozacBoja klasa - centralni servis boja', () {
      test('Svi vozači iz VozacMappingService imaju boje u VozacBoja', () {
        final vozaci = VozacMappingService.getAllVozacNames();

        for (final vozac in vozaci) {
          final boja = VozacBoja.get(vozac);
          expect(boja, isNotNull, reason: 'Vozač $vozac mora imati boju u VozacBoja');
          expect(boja, isNot(Colors.transparent), reason: 'Vozač $vozac ne smije imati transparentnu boju');

          // Provjeri da li je boja očekivana
          final expectedColor = expectedColors[vozac];
          expect(expectedColor, isNotNull, reason: 'Vozač $vozac mora imati definisanu očekivanu boju');

          final expectedColorObj = Color(expectedColor!);
          expect(boja, expectedColorObj, reason: 'Boja za $vozac ne odgovara očekivanoj');
        }
      });

      test('VozacBoja ima samo vozače iz VozacMappingService', () {
        final vozacBojaDrivers = VozacBoja.validDrivers;
        final mappingDrivers = VozacMappingService.getAllVozacNames();

        expect(vozacBojaDrivers.length, mappingDrivers.length,
            reason: 'VozacBoja mora imati isti broj vozača kao VozacMappingService');

        for (final driver in vozacBojaDrivers) {
          expect(mappingDrivers, contains(driver),
              reason: 'Vozač $driver iz VozacBoja mora postojati u VozacMappingService');
        }
      });

      test('Validacija vozača radi ispravno', () {
        final validDrivers = VozacMappingService.getAllVozacNames();

        for (final driver in validDrivers) {
          expect(VozacBoja.isValidDriver(driver), true,
              reason: 'Vozač $driver mora biti validan u VozacBoja');
        }

        // Test nevalidnih vozača
        expect(VozacBoja.isValidDriver('Marko'), false);
        expect(VozacBoja.isValidDriver(null), false);
        expect(VozacBoja.isValidDriver(''), false);
      });
    });

    group('🔍 Test za svakog vozača posebno - BOJE', () {

      test('BILEVSKI - boja', () {
        final boja = VozacBoja.get('Bilevski');
        expect(boja, Color(0xFFFF9800)); // narandžasta
        expect(boja, isNot(Colors.transparent));
        expect(VozacBoja.isValidDriver('Bilevski'), true);
        print('✅ BILEVSKI: Boja = ${boja.toString()}');
      });

      test('BRUDA - boja', () {
        final boja = VozacBoja.get('Bruda');
        expect(boja, Color(0xFF7C4DFF)); // ljubičasta
        expect(boja, isNot(Colors.transparent));
        expect(VozacBoja.isValidDriver('Bruda'), true);
        print('✅ BRUDA: Boja = ${boja.toString()}');
      });

      test('BOJAN - boja', () {
        final boja = VozacBoja.get('Bojan');
        expect(boja, Color(0xFF00E5FF)); // svetla cyan plava
        expect(boja, isNot(Colors.transparent));
        expect(VozacBoja.isValidDriver('Bojan'), true);
        print('✅ BOJAN: Boja = ${boja.toString()}');
      });

      test('SVETLANA - boja', () {
        final boja = VozacBoja.get('Svetlana');
        expect(boja, Color(0xFFFF1493)); // deep pink
        expect(boja, isNot(Colors.transparent));
        expect(VozacBoja.isValidDriver('Svetlana'), true);
        print('✅ SVETLANA: Boja = ${boja.toString()}');
      });
    });

    group('❌ Test nevalidnih vozača - BOJE', () {
      test('Nevalidni vozači dobijaju transparentnu boju', () {
        final nevalidniVozaci = ['Marko', 'Nikola', 'Petar', 'Gavra', null, ''];

        for (final vozac in nevalidniVozaci) {
          final boja = VozacBoja.get(vozac);
          expect(boja, Colors.transparent,
              reason: 'Nevalidni vozač "$vozac" mora dobiti transparentnu boju');
          expect(VozacBoja.isValidDriver(vozac), false,
              reason: 'Nevalidni vozač "$vozac" ne smije biti validan');
        }
      });
    });

    group('📊 Sažetak boja svih vozača', () {
      test('Prikaz svih boja', () {
        print('\n🎨 SAŽETAK BOJA SVIH VOZAČA:');
        print('=' * 50);

        final vozaci = VozacMappingService.getAllVozacNames();
        for (final vozac in vozaci) {
          final boja = VozacBoja.get(vozac);
          final hexColor = '#${boja.value.toRadixString(16).toUpperCase().padLeft(8, '0')}';
          print('🚗 $vozac: $hexColor');
        }
        print('');
      });
    });

    group('🔗 Integracija sa drugim servisima', () {
      test('VozacMappingService i VozacBoja su sinhronizovani', () {
        final mappingDrivers = VozacMappingService.getAllVozacNames();
        final bojaDrivers = VozacBoja.validDrivers;

        expect(mappingDrivers.length, bojaDrivers.length);
        expect(mappingDrivers.toSet(), bojaDrivers.toSet());
      });

      test('Svaki UUID iz VozacMappingService ima odgovarajuću boju', () {
        final uuids = VozacMappingService.getAllVozacUuids();

        for (final uuid in uuids) {
          final ime = VozacMappingService.getVozacIme(uuid);
          expect(ime, isNotNull);

          final boja = VozacBoja.get(ime);
          expect(boja, isNot(Colors.transparent),
              reason: 'UUID $uuid (vozač $ime) mora imati validnu boju');
        }
      });
    });
  });
}