import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/mesecni_putnik_novi.dart' as novi;

void main() {
  group('🔧 Update Logika - Error Handling i Edge Cases', () {
    test('Error Handling - Null Safety u toMap()', () {
      print('\n🔍 Testiranje null safety u toMap() generisanju');

      // Test sa null vrednostima
      final putnikSaNullovima = novi.MesecniPutnik(
        id: 'test-null-safety',
        putnikIme: 'Null Safety Test',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['08:00 BC']
        },
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        // Sva opciona polja null
        brojTelefona: null,
        tipSkole: null,
        adresaBelaCrkva: null,
        adresaVrsac: null,
        cena: null,
        vozac: null,
        vremePlacanja: null,
      );

      final map = putnikSaNullovima.toMap();

      // Validacija null handling
      expect(map['broj_telefona'], isNull);
      expect(map['tip_skole'], isNull);
      expect(map['adresa_bela_crkva'], isNull);
      expect(map['adresa_vrsac'], isNull);
      expect(map['cena'], isNull);
      expect(map['vozac_id'], isNull);
      expect(map['vreme_placanja'], isNull);

      // Obavezna polja ne smeju biti null
      expect(map['putnik_ime'], isNotNull);
      expect(map['tip'], isNotNull);
      expect(map['polasci_po_danu'], isNotNull);

      print('✅ Null safety test - PASSED');
    });

    test('Edge Case - Prazni polasci_po_danu', () {
      print('\n🔍 Testiranje praznih polazaka u UPDATE');

      final putnikPrazniPolasci = novi.MesecniPutnik(
        id: 'test-empty-polasci',
        putnikIme: 'Empty Polasci Test',
        tip: 'radnik',
        polasciPoDanu: {}, // Prazan Map
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = putnikPrazniPolasci.toMap();

      expect(map['polasci_po_danu'], isNotNull);
      expect(map['polasci_po_danu'], isEmpty);

      print('✅ Prazni polasci_po_danu test - PASSED');
    });

    test('Edge Case - Ekstremne date vrednosti', () {
      print('\n🔍 Testiranje ekstremnih datuma u UPDATE');

      final putnikEkstremniDatumi = novi.MesecniPutnik(
        id: 'test-extreme-dates',
        putnikIme: 'Extreme Dates Test',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['08:00 BC']
        },
        datumPocetkaMeseca: DateTime(1900, 1, 1), // Vrlo stari datum
        datumKrajaMeseca: DateTime(2100, 12, 31), // Daleka budućnost
        createdAt: DateTime(2000, 1, 1),
        updatedAt: DateTime(2030, 6, 15),
        poslednjePutovanje: DateTime(2025, 12, 31, 23, 59, 59), // Kraj godine
      );

      final map = putnikEkstremniDatumi.toMap();

      expect(map['datum_pocetka_meseca'], equals('1900-01-01'));
      expect(map['datum_kraja_meseca'], equals('2100-12-31'));
      expect(map['created_at'], contains('2000-01-01'));
      expect(map['updated_at'], contains('2030-06-15'));
      expect(map['poslednje_putovanje'], contains('2025-12-31'));

      print('✅ Ekstremni datumi test - PASSED');
    });

    test('Edge Case - Veliki brojevi u statistikama', () {
      print('\n🔍 Testiranje velikih brojeva u UPDATE');

      final putnikVelikiBrojevi = novi.MesecniPutnik(
        id: 'test-large-numbers',
        putnikIme: 'Large Numbers Test',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['08:00 BC']
        },
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        cena: 999999.99, // Veliki iznos
        brojPutovanja: 999999, // Veliki broj putovanja
        brojOtkazivanja: 888888, // Veliki broj otkazivanja
        ukupnaCenaMeseca: 1000000.0, // Milion dinara
      );

      final map = putnikVelikiBrojevi.toMap();

      expect(map['cena'], equals(999999.99));
      expect(map['broj_putovanja'], equals(999999));
      expect(map['broj_otkazivanja'], equals(888888));
      expect(map['ukupna_cena_meseca'], equals(1000000.0));

      // Validacija da su brojevi u razumnim granicama
      expect(map['cena'], lessThan(10000000)); // Manje od 10 miliona
      expect(map['broj_putovanja'], lessThan(10000000));

      print('✅ Veliki brojevi test - PASSED');
    });

    test('Edge Case - Unicode karakteri u imenima', () {
      print('\n🔍 Testiranje Unicode karaktera u UPDATE');

      final putnikUnicode = novi.MesecniPutnik(
        id: 'test-unicode-chars',
        putnikIme: 'Милош Đorđević 🚌', // Ćirilica + emoji
        tip: 'đak', // Unicode karakter
        polasciPoDanu: {
          'понедељак': ['08:00 BC']
        }, // Ćirilica dan
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        brojTelefona: '+381-64-123-4567', // Sa crticama
        adresaBelaCrkva: 'Улица Милоша Обреновића 123', // Ćirilica adresa
      );

      final map = putnikUnicode.toMap();

      expect(map['putnik_ime'], equals('Милош Đorđević 🚌'));
      expect(map['tip'], equals('đak'));
      expect(map['broj_telefona'], equals('+381-64-123-4567'));
      expect(map['adresa_bela_crkva'], equals('Улица Милоша Обреновића 123'));
      expect(map['polasci_po_danu']['понедељак'], isNotNull);

      print('✅ Unicode karakteri test - PASSED');
    });

    test('Performance Test - Veliki polasci_po_danu Map', () {
      print('\n🔍 Testiranje performansi sa velikim polasci_po_danu');

      // Generiši veliki map sa svim danima i više polazaka
      final velikiPolasci = <String, List<String>>{};
      final dani = ['pon', 'uto', 'sre', 'cet', 'pet', 'sub', 'ned'];

      for (final dan in dani) {
        velikiPolasci[dan] = [];
        // Dodaj 10 polazaka po danu (edge case)
        for (int i = 6; i <= 15; i++) {
          velikiPolasci[dan]!.add('${i.toString().padLeft(2, '0')}:00 BC');
          velikiPolasci[dan]!.add('${i.toString().padLeft(2, '0')}:30 VS');
        }
      }

      final putnikVelikiPolasci = novi.MesecniPutnik(
        id: 'test-large-polasci',
        putnikIme: 'Large Polasci Test',
        tip: 'radnik',
        polasciPoDanu: velikiPolasci,
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final stopwatch = Stopwatch()..start();
      final map = putnikVelikiPolasci.toMap();
      stopwatch.stop();

      expect(map['polasci_po_danu'], isNotNull);
      expect(map['polasci_po_danu'].keys.length, equals(7));

      // Performance check - mora biti brže od 100ms
      expect(stopwatch.elapsedMilliseconds, lessThan(100),
          reason: 'toMap() mora biti brž od 100ms čak i sa velikim podacima');

      print('✅ Performance test - PASSED (${stopwatch.elapsedMilliseconds}ms)');
    });

    test('Business Logic - Konzistentnost cena u UPDATE', () {
      print('\n🔍 Testiranje konzistentnosti cena u UPDATE');

      final putnikCene = novi.MesecniPutnik(
        id: 'test-price-consistency',
        putnikIme: 'Price Consistency Test',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['08:00 BC']
        },
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        cena: 15000.0, // Glavna cena
        ukupnaCenaMeseca: 17000.0, // Ukupna cena (različita)
      );

      final map = putnikCene.toMap();

      // cena polje treba da bude glavno
      expect(map['cena'], equals(15000.0));
      expect(map['ukupna_cena_meseca'], equals(17000.0));

      // Proveri da li iznosPlacanja getter radi pravilno
      expect(putnikCene.iznosPlacanja, equals(15000.0),
          reason:
              'iznosPlacanja treba da vrati cena umesto ukupnaCenaMeseca ako postoji');

      print('✅ Konzistentnost cena test - PASSED');
    });

    test('copyWith Method - Parcijalne promene', () {
      print('\n🔍 Testiranje copyWith metode za parcijalne UPDATE-e');

      final originalniPutnik = novi.MesecniPutnik(
        id: 'test-copywith',
        putnikIme: 'Original Name',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['08:00 BC']
        },
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime(2025, 10, 1),
        updatedAt: DateTime(2025, 10, 1),
        cena: 15000.0,
        vozac: 'stari-vozac-uuid',
      );

      // Parcijalnu promenu samo imena i cene
      final izmenjeniPutnik = originalniPutnik.copyWith(
        putnikIme: 'New Name',
        cena: 16000.0,
      );

      // Proveri da li su SAMO promenjeni podaci različiti
      expect(izmenjeniPutnik.putnikIme, equals('New Name'));
      expect(izmenjeniPutnik.cena, equals(16000.0));

      // Ostali podaci treba da ostanu isti
      expect(izmenjeniPutnik.id, equals('test-copywith'));
      expect(izmenjeniPutnik.tip, equals('radnik'));
      expect(izmenjeniPutnik.vozac, equals('stari-vozac-uuid'));
      expect(izmenjeniPutnik.createdAt, equals(DateTime(2025, 10, 1)));

      // Ali updatedAt treba da bude nov
      expect(izmenjeniPutnik.updatedAt, isNot(equals(DateTime(2025, 10, 1))));

      print('✅ copyWith method test - PASSED');
    });
  });
}
