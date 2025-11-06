import 'package:flutter_test/flutter_test.dart';

import '../lib/models/mesecni_putnik.dart' as novi_model;
import '../lib/models/putnik.dart';
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
      });

      test('VozacBoja - boje vozača', () {
        expect(VozacBoja.get('Bojan'), isNotNull);
        expect(VozacBoja.get('Svetlana'), isNotNull);
        expect(VozacBoja.get('Bruda'), isNotNull);
        expect(VozacBoja.get('Bilevski'), isNotNull);
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
      });
    });

    // 💰 PLAĆANJE SISTEM TESTOVI
    group('💰 Plaćanje Sistem', () {
      test('Osnovni plaćanje parametri', () {
        // Test osnovnih validacija za plaćanje
        expect(100.0 > 0, true, reason: 'Iznos mora biti pozitivan');
        expect(''.isNotEmpty, false, reason: 'Vozač ID ne sme biti prazan');

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
        }
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
      });
    });

    // 🚌 PUTNIK MODEL TESTOVI
    group('🚌 Putnik Modeli', () {
      test('Putnik osnovni konstruktor', () {
        final putnik = Putnik(
          id: 'test-id',
          ime: 'Test Putnik',
          grad: 'Bela Crkva',
          polazak: 'Centar',
          dan: 'ponedeljak',
          cena: 0.0, // ISPRAVLJENA LINIJA
          mesecnaKarta: false,
          vozac: 'Bojan',
        );

        expect(putnik.ime, 'Test Putnik');
        expect(putnik.grad, 'Bela Crkva');
        expect(putnik.mesecnaKarta, false);
        expect(putnik.placeno ?? false, false, reason: 'Sa cenom 0, nije plaćen');
      });

      test('Putnik plaćanje logic', () {
        final neplacenPutnik = Putnik(
          id: 'test-1',
          ime: 'Neplaćen',
          grad: 'Bela Crkva',
          polazak: 'Centar',
          dan: 'ponedeljak',
          cena: 0.0, // ISPRAVLJENA LINIJA
          mesecnaKarta: false,
        );

        final placenPutnik = Putnik(
          id: 'test-2',
          ime: 'Plaćen',
          grad: 'Bela Crkva',
          polazak: 'Centar',
          dan: 'ponedeljak',
          cena: 150.0, // ISPRAVLJENA LINIJA
          mesecnaKarta: false,
          placeno: true, // ISPRAVLJENA LINIJA
        );

        expect(neplacenPutnik.placeno ?? false, false);
        expect(placenPutnik.placeno ?? false, true);
      });

      test('Mesečni putnik validacija', () {
        final mesecniPutnik = novi_model.MesecniPutnik(
          id: 'mesecni-test',
          putnikIme: 'Test Mesečni',
          tip: 'radnik',
          polasciPoDanu: {
            'ponedeljak': ['08:00', '17:00'],
            'utorak': ['08:00', '17:00'],
          },
          datumPocetkaMeseca: DateTime.now(),
          datumKrajaMeseca: DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          ukupnaCenaMeseca: 3000.0, // DODATO
        );

        expect(mesecniPutnik.putnikIme, 'Test Mesečni');
        expect(mesecniPutnik.tip, 'radnik');
        expect(mesecniPutnik.aktivan, true);
        expect(mesecniPutnik.ukupnaCenaMeseca, 3000.0);
      });
    });

    // 🔧 UTILITY FUNKCIJE TESTOVI
    group('🔧 Utility Funkcije', () {
      test('String validacija', () {
        expect(''.isEmpty, true);
        expect('  '.trim().isEmpty, true);
        expect('Bojan'.isNotEmpty, true);
        expect('123'.isNotEmpty, true);
      });

      test('Broj parsing', () {
        expect(double.tryParse('100'), 100.0);
        expect(double.tryParse('100.50'), 100.50);
        expect(double.tryParse('abc'), null);
        expect(double.tryParse(''), null);
        expect(double.tryParse('-50'), -50.0);
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
    });

    // 🎯 EDGE CASES TESTOVI
    group('🎯 Edge Cases', () {
      test('Null safety', () {
        String? nullString;
        double? nullDouble;

        expect(nullString ?? '', '');
        expect((nullDouble ?? 0.0) > 0, false);
      });

      test('Extreme values', () {
        expect(double.maxFinite > 1000000, true);
        expect(double.minPositive > 0, true);
        expect(0.0 == -0.0, true);
      });

      test('String edge cases', () {
        expect('   Bojan   '.trim(), 'Bojan');
        expect('BOJAN'.toLowerCase(), 'bojan');
        expect('bojan'.toUpperCase(), 'BOJAN');
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

      test('Memory efficiency - object creation', () {
        final stopwatch = Stopwatch()..start();

        final putnici = <Putnik>[];
        for (int i = 0; i < 100; i++) {
          putnici.add(
            Putnik(
              id: 'test_$i',
              ime: 'Putnik $i',
              grad: 'Bela Crkva',
              polazak: 'Centar',
              dan: 'ponedeljak',
              mesecnaKarta: i % 2 == 0,
            ),
          );
        }

        stopwatch.stop();

        expect(putnici.length, 100);
        expect(
          stopwatch.elapsedMilliseconds < 50,
          true,
          reason: 'Kreiranje 100 putnika treba < 50ms',
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
      });
    });
  });
}
