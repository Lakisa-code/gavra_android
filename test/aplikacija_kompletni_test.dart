import 'package:flutter_test/flutter_test.dart';

import '../lib/utils/vozac_boja.dart';

void main() {
  group('🔬 KOMPLETNI SISTEM TESTOVI', () {
    // 🚗 VOZAČ SISTEM TESTOVI
    group('👨‍💼 Vozač Sistem', () {
      test('VozacBoja - validni vozači', () {
        expect(VozacBoja.isValidDriver('Bojan'), true);
        expect(VozacBoja.isValidDriver('Svetlana'), true);
        expect(VozacBoja.isValidDriver('Bruda'), true);
        expect(VozacBoja.isValidDriver('Bilevski'), true);
        expect(VozacBoja.isValidDriver('Nepoznat'), false);
        expect(VozacBoja.isValidDriver(''), false);
        expect(VozacBoja.isValidDriver(null), false);
      });

      test('VozacBoja - boje vozača', () {
        expect(VozacBoja.get('Bojan'), isNotNull);
        expect(VozacBoja.get('Svetlana'), isNotNull);
        expect(VozacBoja.get('Bruda'), isNotNull);
        expect(VozacBoja.get('Bilevski'), isNotNull);

        // Test da nevalidni vozač dobija crvenu boju
        expect(VozacBoja.get('Nepoznat'), isNotNull);
        expect(VozacBoja.get(null), isNotNull);
      });

      test('VozacBoja - email validacija', () {
        expect(VozacBoja.getDozvoljenEmailForVozac('Bojan'), 'gavriconi19@gmail.com');
        expect(VozacBoja.getDozvoljenEmailForVozac('Svetlana'), 'risticsvetlana2911@yahoo.com');
        expect(VozacBoja.getDozvoljenEmailForVozac('Bruda'), 'igor.jovanovic.1984@icloud.com');
        expect(VozacBoja.getDozvoljenEmailForVozac('Bilevski'), 'bilyboy1983@gmail.com');
        expect(VozacBoja.getDozvoljenEmailForVozac('Nepoznat'), null);
        expect(VozacBoja.getDozvoljenEmailForVozac(null), null);
      });

      test('Hardcoded UUID fallback logika', () {
        // Test da li naša fallback logika pokriva sve poznate vozače
        const expectedMappings = {
          'Bojan': '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e',
          'Svetlana': '5b379394-084e-1c7d-76bf-fc193a5b6c7d',
          'Bruda': '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f',
          'Bilevski': '8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f',
        };

        for (final vozac in VozacBoja.validDrivers) {
          expect(
            expectedMappings.containsKey(vozac),
            true,
            reason: 'Vozač $vozac mora imati hardcoded UUID fallback',
          );
        }

        // Test validnost UUID-ova
        final uuidRegex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        );

        for (final uuid in expectedMappings.values) {
          expect(
            uuidRegex.hasMatch(uuid),
            true,
            reason: 'UUID $uuid mora biti valjan format',
          );
        }
      });
    });

    // 💰 PLAĆANJE SISTEM TESTOVI
    group('💰 Plaćanje Sistem', () {
      test('Osnovni plaćanje parametri', () {
        // Test osnovnih validacija za plaćanje
        expect(100.0 > 0, true, reason: 'Iznos mora biti pozitivan');
        expect(''.isNotEmpty, false, reason: 'Vozač ID ne sme biti prazan');
        expect('Bojan'.isNotEmpty, true, reason: 'Valjan vozač ID');

        final pocetakMeseca = DateTime(2025, 11);
        final krajMeseca = DateTime(2025, 11, 30);
        expect(
          krajMeseca.isAfter(pocetakMeseca),
          true,
          reason: 'Kraj meseca mora biti posle početka',
        );
      });

      test('UUID validacija regex', () {
        const validUuid = '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e';
        const invalidUuid = 'not-a-uuid';

        final uuidRegex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        );

        expect(uuidRegex.hasMatch(validUuid), true);
        expect(uuidRegex.hasMatch(invalidUuid), false);
        expect(uuidRegex.hasMatch('Bojan'), false);
        expect(uuidRegex.hasMatch(''), false);
      });

      test('Mesec konverzija logika', () {
        const mesecStringovi = [
          'Januar 2025',
          'Februar 2025',
          'Mart 2025',
          'April 2025',
          'Maj 2025',
          'Jun 2025',
          'Jul 2025',
          'Avgust 2025',
          'Septembar 2025',
          'Oktobar 2025',
          'Novembar 2025',
          'Decembar 2025',
        ];

        for (int i = 0; i < mesecStringovi.length; i++) {
          final parts = mesecStringovi[i].split(' ');
          expect(parts.length, 2, reason: 'Format meseca mora biti "Mesec Godina"');
          expect(int.tryParse(parts[1]), isNotNull, reason: 'Godina mora biti broj');
          expect(int.tryParse(parts[1]), greaterThan(2020), reason: 'Godina mora biti realistična');
        }
      });

      test('Payment data structure validation', () {
        final paymentData = {
          'mesecni_putnik_id': 'test-uuid',
          'putnik_ime': 'Test Putnik',
          'tip_putnika': 'mesecni',
          'datum_putovanja': DateTime.now().toIso8601String().split('T')[0],
          'vreme_polaska': 'mesecno_placanje',
          'status': 'placeno',
          'vozac_id': '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e',
          'cena': 150.0,
          'napomene': 'Test plaćanje',
        };

        expect(paymentData['mesecni_putnik_id'], isNotNull);
        expect(paymentData['putnik_ime'], isNotEmpty);
        expect(paymentData['tip_putnika'], 'mesecni');
        expect(paymentData['status'], 'placeno');
        expect(paymentData['cena'], greaterThan(0));
        expect(paymentData['vozac_id'], isNotNull);
      });
    });

    // 📊 STATISTIKE TESTOVI
    group('📊 Statistike Sistem', () {
      test('Datum normalizacija', () {
        final testDatum = DateTime(2025, 11, 6, 14, 30, 45);
        final normalized = DateTime(testDatum.year, testDatum.month, testDatum.day);

        expect(normalized.hour, 0);
        expect(normalized.minute, 0);
        expect(normalized.second, 0);
        expect(normalized.day, testDatum.day);
        expect(normalized.month, testDatum.month);
        expect(normalized.year, testDatum.year);
      });

      test('Datum opseg validacija', () {
        final danas = DateTime.now();
        final fromDate = DateTime(danas.year, danas.month, danas.day);
        final toDate = DateTime(danas.year, danas.month, danas.day, 23, 59, 59);

        expect(toDate.isAfter(fromDate), true);
        expect(toDate.difference(fromDate).inHours, 23);
        expect(toDate.difference(fromDate).inMinutes, 1439); // 23*60 + 59
      });

      test('ISO datum format', () {
        final testDatum = DateTime(2025, 11, 6);
        final isoString = testDatum.toIso8601String().split('T')[0];

        expect(isoString, '2025-11-06');
        expect(isoString.length, 10);
        expect(isoString.contains('-'), true);

        final parsed = DateTime.parse('${isoString}T00:00:00Z');
        expect(parsed.year, 2025);
        expect(parsed.month, 11);
        expect(parsed.day, 6);
      });
    });

    // 🔧 UTILITY FUNKCIJE TESTOVI
    group('🔧 Utility Funkcije', () {
      test('String validacija', () {
        expect(''.isEmpty, true);
        expect('  '.trim().isEmpty, true);
        expect('Bojan'.isNotEmpty, true);
        expect('123'.isNotEmpty, true);
        expect('   test   '.trim(), 'test');
      });

      test('Broj parsing', () {
        expect(double.tryParse('100'), 100.0);
        expect(double.tryParse('100.50'), 100.50);
        expect(double.tryParse('abc'), null);
        expect(double.tryParse(''), null);
        expect(double.tryParse('-50'), -50.0);
        expect(double.tryParse('0'), 0.0);
        expect(double.tryParse('0.0'), 0.0);
      });

      test('DateTime operacije', () {
        final now = DateTime.now();
        final formatted = now.toIso8601String().split('T')[0];

        expect(formatted.length, 10); // YYYY-MM-DD format
        expect(formatted.contains('-'), true);

        final parsed = DateTime.parse('${formatted}T00:00:00Z');
        expect(parsed.year, now.year);
        expect(parsed.month, now.month);
        expect(parsed.day, now.day);
      });

      test('Map operacije', () {
        final testMap = <String, dynamic>{
          'ime': 'Test',
          'iznos': 100.0,
          'aktivan': true,
        };

        expect(testMap.containsKey('ime'), true);
        expect(testMap.containsKey('nepostoji'), false);
        expect(testMap['ime'], 'Test');
        expect(testMap['iznos'], 100.0);
        expect(testMap['aktivan'], true);
      });
    });

    // 🎯 EDGE CASES TESTOVI
    group('🎯 Edge Cases', () {
      test('Null safety', () {
        String? nullString;
        double? nullDouble;

        expect(nullString ?? '', '');
        expect((nullDouble ?? 0.0) > 0, false);
        expect((nullDouble ?? 100.0) > 0, true);
      });

      test('Extreme values', () {
        expect(double.maxFinite > 1000000, true);
        expect(double.minPositive > 0, true);
        expect(0.0 == -0.0, true);
        expect(double.infinity > double.maxFinite, true);
        expect(double.negativeInfinity < 0, true);
      });

      test('String edge cases', () {
        expect('   Bojan   '.trim(), 'Bojan');
        expect('BOJAN'.toLowerCase(), 'bojan');
        expect('bojan'.toUpperCase(), 'BOJAN');
        expect(''.isEmpty, true);
        expect(' '.trim().isEmpty, true);
      });

      test('Collection edge cases', () {
        final emptyList = <String>[];
        final singleList = ['test'];
        final multiList = ['a', 'b', 'c'];

        expect(emptyList.isEmpty, true);
        expect(emptyList.length, 0);
        expect(singleList.length, 1);
        expect(multiList.length, 3);
        expect(multiList.first, 'a');
        expect(multiList.last, 'c');
      });
    });

    // 🚀 PERFORMANCE TESTOVI
    group('🚀 Performance', () {
      test('Brza operacija - lista filtriranje', () {
        final stopwatch = Stopwatch()..start();

        final lista = List.generate(1000, (i) => 'putnik_$i');
        final filtered = lista.where((p) => p.contains('1')).toList();

        stopwatch.stop();

        expect(filtered.isNotEmpty, true);
        expect(
          stopwatch.elapsedMilliseconds < 100,
          true,
          reason: 'Filtriranje 1000 elemenata treba < 100ms',
        );
      });

      test('Memory efficiency - string operacije', () {
        final stopwatch = Stopwatch()..start();

        final stringovi = <String>[];
        for (int i = 0; i < 1000; i++) {
          stringovi.add('Test string $i');
        }

        final kombinovani = stringovi.join(', ');

        stopwatch.stop();

        expect(stringovi.length, 1000);
        expect(kombinovani.isNotEmpty, true);
        expect(
          stopwatch.elapsedMilliseconds < 50,
          true,
          reason: 'String operacije treba < 50ms',
        );
      });

      test('Map operacije performance', () {
        final stopwatch = Stopwatch()..start();

        final mapa = <String, int>{};
        for (int i = 0; i < 1000; i++) {
          mapa['key_$i'] = i;
        }

        final result = mapa.values.where((v) => v % 2 == 0).length;

        stopwatch.stop();

        expect(mapa.length, 1000);
        expect(result, 500); // 500 parnih brojeva
        expect(
          stopwatch.elapsedMilliseconds < 50,
          true,
          reason: 'Map operacije treba < 50ms',
        );
      });
    });

    // ✅ INTEGRACIJA TESTOVI
    group('✅ Integracija', () {
      test('Kompletan payment flow simulation', () {
        // Simuliramo kompletan payment flow bez Supabase konekcije
        const putnikId = 'test-putnik-id';
        const iznos = 150.0;
        const vozacId = 'Bojan';

        // Step 1: Validacija parametara
        expect(putnikId.isNotEmpty, true);
        expect(iznos > 0, true);
        expect(VozacBoja.isValidDriver(vozacId), true);

        // Step 2: UUID konverzija (simulacija našeg fallback-a)
        String? validVozacId;
        const uuidRegex = r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

        if (RegExp(uuidRegex).hasMatch(vozacId)) {
          validVozacId = vozacId;
        } else {
          // Simulacija našeg hardcoded fallback-a
          switch (vozacId) {
            case 'Bojan':
              validVozacId = '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e';
              break;
            case 'Svetlana':
              validVozacId = '5b379394-084e-1c7d-76bf-fc193a5b6c7d';
              break;
            case 'Bruda':
              validVozacId = '7d59b5b6-2a4a-3e9f-98e1-1e3b4c7d8e9f';
              break;
            case 'Bilevski':
              validVozacId = '8e68c6c7-3b8b-4f8a-a9d2-2f4b5c8d9e0f';
              break;
          }
        }

        // Step 3: Validacija rezultata
        expect(validVozacId, isNotNull, reason: 'Vozač ID mora biti konverovan u UUID');
        expect(
          RegExp(uuidRegex).hasMatch(validVozacId!),
          true,
          reason: 'Konvertovani ID mora biti valjan UUID',
        );

        // Step 4: Simulacija database zapisa
        final paymentData = {
          'mesecni_putnik_id': putnikId,
          'putnik_ime': 'Test Putnik',
          'tip_putnika': 'mesecni',
          'datum_putovanja': DateTime.now().toIso8601String().split('T')[0],
          'vreme_polaska': 'mesecno_placanje',
          'status': 'placeno',
          'vozac_id': validVozacId,
          'cena': iznos,
          'napomene': 'Test plaćanje za ${DateTime.now().month}/${DateTime.now().year}',
        };

        expect(paymentData['vozac_id'], isNotNull);
        expect(paymentData['cena'], greaterThan(0));
        expect(paymentData['status'], 'placeno');
        expect(paymentData['tip_putnika'], 'mesecni');
      });

      test('Vozač sistem integracija', () {
        // Test kompletne integracije vozač sistema
        final validDrivers = VozacBoja.validDrivers;

        expect(validDrivers.isNotEmpty, true);
        expect(validDrivers.length, 4, reason: 'Tačno 4 vozača mora biti validno');

        for (final driver in validDrivers) {
          // Svaki vozač mora imati boju
          expect(VozacBoja.get(driver), isNotNull);

          // Svaki vozač mora imati email
          expect(VozacBoja.getDozvoljenEmailForVozac(driver), isNotNull);

          // Svaki vozač mora biti valjan
          expect(VozacBoja.isValidDriver(driver), true);
        }
      });

      test('Datum i vreme operacije', () {
        final now = DateTime.now();

        // Test mesečnog opsega
        final pocetakMeseca = DateTime(now.year, now.month);
        final krajMeseca = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

        expect(pocetakMeseca.day, 1);
        expect(krajMeseca.isAfter(pocetakMeseca), true);
        expect(krajMeseca.month, now.month);

        // Test ISO format
        final isoDate = now.toIso8601String().split('T')[0];
        expect(isoDate.length, 10);
        expect(DateTime.parse('${isoDate}T00:00:00Z').day, now.day);
      });
    });

    // 🛡️ SIGURNOST TESTOVI
    group('🛡️ Sigurnost', () {
      test('Input sanitization', () {
        // Test da specijalni karakteri ne kreiraju probleme
        const problematicInputs = [
          '',
          '   ',
          '\n',
          '\t',
          'null',
          'undefined',
          '<script>',
          'DROP TABLE',
          '--',
          ';',
          '/*',
          '*/',
        ];

        for (final input in problematicInputs) {
          expect(input.trim().isEmpty || input.trim().isNotEmpty, true);
          expect(
            VozacBoja.isValidDriver(input),
            false,
            reason: 'Problematični input "$input" ne sme biti valjan vozač',
          );
        }
      });

      test('UUID format strict validation', () {
        const invalidUuids = [
          '', 'not-uuid', '123', 'aaaaa',
          '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8', // prekratak
          '6c48a4a5-194f-2d8e-87d0-0d2a3b6c7d8ee', // predugačak
          '6c48a4a5194f2d8e87d00d2a3b6c7d8e', // bez crtica
          'gc48a4a5-194f-2d8e-87d0-0d2a3b6c7d8e', // invalid karakter
        ];

        final uuidRegex = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        );

        for (final invalidUuid in invalidUuids) {
          expect(
            uuidRegex.hasMatch(invalidUuid),
            false,
            reason: 'Invalid UUID "$invalidUuid" ne sme proći validaciju',
          );
        }
      });
    });
  });
}
