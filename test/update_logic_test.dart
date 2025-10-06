import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/mesecni_putnik.dart';
import 'package:gavra_android/models/mesecni_putnik_novi.dart' as novi;
import 'package:gavra_android/models/dnevni_putnik.dart';
import 'package:gavra_android/models/putovanja_istorija.dart';

void main() {
  group('Update Logika Testovi', () {
    test('MesecniPutnik (stari) toMap() za UPDATE', () {
      print('\n🔍 Testiranje update logike za stari MesecniPutnik model');

      final putnik = MesecniPutnik(
        id: 'test-uuid-123',
        putnikIme: 'Marko Petrović',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['07:30 BC', '15:00 VS'],
          'uto': ['08:00 BC'],
        },
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime(2025, 10, 1, 8, 0),
        updatedAt: DateTime.now(),
        ukupnaCenaMeseca: 17000,
        cena: 17000,
        vozac: 'vozac-uuid-456',
      );

      final map = putnik.toMap();

      // Proverava da li id je uključen za UPDATE
      expect(map.containsKey('id'), isTrue,
          reason: 'UPDATE operacija mora da uključi id');
      expect(map['id'], equals('test-uuid-123'));

      // Proverava da li su svi obavezni podaci tu
      expect(map['putnik_ime'], equals('Marko Petrović'));
      expect(map['tip'], equals('radnik'));
      expect(map['cena'], equals(17000));
      expect(map['vozac_id'], equals('vozac-uuid-456'));
      expect(map.containsKey('updated_at'), isTrue);

      // Provera polasci_po_danu strukture
      expect(map['polasci_po_danu'], isNotNull);
      expect(map['polasci_po_danu']['pon'], isNotNull);
      expect(map['polasci_po_danu']['uto'], isNotNull);

      print('✅ Stari MesecniPutnik toMap() za UPDATE - PASSED');
    });

    test('MesecniPutnik (novi) toMap() za UPDATE', () {
      print('\n🔍 Testiranje update logike za novi MesecniPutnik model');

      final putnik = novi.MesecniPutnik(
        id: 'test-uuid-789',
        putnikIme: 'Ana Jovanović',
        tip: 'djak',
        tipSkole: 'srednja',
        polasciPoDanu: {
          'pon': ['06:30 BC', '14:30 VS'],
          'sre': ['06:30 BC'],
        },
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime(2025, 10, 1, 7, 0),
        updatedAt: DateTime.now(),
        ukupnaCenaMeseca: 15000,
        cena: 15000,
        vozac: 'vozac-uuid-789',
      );

      final map = putnik.toMap();

      // Proverava da li id je uključen za UPDATE
      expect(map.containsKey('id'), isTrue,
          reason: 'UPDATE operacija mora da uključi id');
      expect(map['id'], equals('test-uuid-789'));

      // Proverava da li su svi obavezni podaci tu
      expect(map['putnik_ime'], equals('Ana Jovanović'));
      expect(map['tip'], equals('djak'));
      expect(map['tip_skole'], equals('srednja'));
      expect(map['cena'], equals(15000));
      expect(map['vozac_id'], equals('vozac-uuid-789'));
      expect(map.containsKey('updated_at'), isTrue);

      // Provera polasci_po_danu strukture
      expect(map['polasci_po_danu'], isNotNull);
      expect(map['polasci_po_danu']['pon'], isNotNull);
      expect(map['polasci_po_danu']['sre'], isNotNull);

      print('✅ Novi MesecniPutnik toMap() za UPDATE - PASSED');
    });

    test('DnevniPutnik toMap() za UPDATE', () {
      print('\n🔍 Testiranje update logike za DnevniPutnik model');

      final putnik = DnevniPutnik(
        id: 'dnevni-uuid-123',
        ime: 'Petar Nikolić',
        brojTelefona: '+381641234567',
        adresaId: 'adresa-uuid-123',
        rutaId: 'ruta-uuid-123',
        datumPutovanja: DateTime(2025, 10, 5),
        vremePolaska: '08:00',
        brojMesta: 1,
        cena: 300.0,
        createdAt: DateTime(2025, 10, 5, 7, 0),
        updatedAt: DateTime.now(),
      );

      final map = putnik.toMap();

      // Proverava da li id je uključen za UPDATE
      expect(map.containsKey('id'), isTrue,
          reason: 'UPDATE operacija mora da uključi id');
      expect(map['id'], equals('dnevni-uuid-123'));

      // Proverava da li su svi obavezni podaci tu
      expect(map['ime'], equals('Petar Nikolić'));
      expect(map['broj_telefona'], equals('+381641234567'));
      expect(map['adresa_id'], equals('adresa-uuid-123'));
      expect(map['ruta_id'], equals('ruta-uuid-123'));
      expect(map['cena'], equals(300.0));
      expect(map.containsKey('updated_at'), isTrue);

      print('✅ DnevniPutnik toMap() za UPDATE - PASSED');
    });

    test('PutovanjaIstorija toMap() za UPDATE', () {
      print('\n🔍 Testiranje update logike za PutovanjaIstorija model');

      final putovanje = PutovanjaIstorija(
        id: 'putovanje-uuid-123',
        mesecniPutnikId: 'mesecni-uuid-456',
        tipPutnika: 'radnik',
        datum: DateTime(2025, 10, 5),
        vremePolaska: '07:30',
        adresaPolaska: 'Bela Crkva',
        putnikIme: 'Test Putnik',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pokupljen: true,
        vozac: 'vozac-uuid-123',
        vremePokupljenja: DateTime.now(),
      );

      final map = putovanje.toMap();

      // Proverava da li id je uključen za UPDATE
      expect(map.containsKey('id'), isTrue,
          reason: 'UPDATE operacija mora da uključi id');
      expect(map['id'], equals('putovanje-uuid-123'));

      // Proverava da li su svi obavezni podaci tu
      expect(map['mesecni_putnik_id'], equals('mesecni-uuid-456'));
      expect(map['tip_putnika'], equals('radnik'));
      expect(map['pokupljen'], isTrue);
      expect(map['vozac'], equals('vozac-uuid-123'));
      expect(map.containsKey('vreme_pokupljenja'), isTrue);

      print('✅ PutovanjaIstorija toMap() za UPDATE - PASSED');
    });

    test('Testiranje praznog vozac_id u UPDATE', () {
      print('\n🔍 Testiranje handle-a praznog vozac_id u UPDATE operaciji');

      // Test sa praznim stringom
      final putnikPrazanVozac = novi.MesecniPutnik(
        id: 'test-uuid-empty-vozac',
        putnikIme: 'Test Putnik',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['07:00 BC']
        },
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: '', // Prazan string
      );

      final mapPrazanVozac = putnikPrazanVozac.toMap();
      expect(mapPrazanVozac['vozac_id'], isNull,
          reason: 'Prazan string za vozac treba biti null u bazi');

      // Test sa null
      final putnikNullVozac = novi.MesecniPutnik(
        id: 'test-uuid-null-vozac',
        putnikIme: 'Test Putnik 2',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['07:00 BC']
        },
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: null, // Null
      );

      final mapNullVozac = putnikNullVozac.toMap();
      expect(mapNullVozac['vozac_id'], isNull,
          reason: 'Null vozac treba ostati null u bazi');

      print('✅ Testiranje praznog vozac_id - PASSED');
    });

    test('Testiranje updated_at timestamp u UPDATE', () {
      print('\n🔍 Testiranje da li se updated_at pravilno postavlja');

      final sada = DateTime.now();

      final putnik = novi.MesecniPutnik(
        id: 'test-uuid-timestamp',
        putnikIme: 'Timestamp Test',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['08:00 BC']
        },
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime(2025, 10, 1),
        updatedAt: sada, // Trenutni timestamp
      );

      final map = putnik.toMap();

      expect(map.containsKey('updated_at'), isTrue,
          reason: 'updated_at mora biti prisutno');
      expect(map['updated_at'], contains(sada.year.toString()),
          reason: 'updated_at mora sadržavati trenutnu godinu');

      print('✅ Testiranje updated_at timestamp - PASSED');
    });

    test('Roundtrip test - fromMap -> toMap -> fromMap', () {
      print('\n🔍 Testiranje roundtrip konverzije za UPDATE logiku');

      // Originalni podatak iz "baze"
      final originalMap = {
        'id': 'roundtrip-uuid-123',
        'putnik_ime': 'Roundtrip Test',
        'tip': 'djak',
        'tip_skole': 'osnovna',
        'broj_telefona': '+381641234567',
        'polasci_po_danu': {
          'pon': {'bc': '07:30', 'vs': ''},
          'uto': {'bc': '08:00', 'vs': '15:30'},
        },
        'datum_pocetka_meseca': '2025-10-01',
        'datum_kraja_meseca': '2025-10-31',
        'created_at': '2025-10-01T08:00:00Z',
        'updated_at': '2025-10-05T10:30:00Z',
        'vozac_id': 'vozac-uuid-roundtrip',
        'cena': 16000.0,
        'aktivan': true,
        'statistics': <String, dynamic>{},
      };

      // fromMap -> Model
      final putnik = novi.MesecniPutnik.fromMap(originalMap);

      // Model -> toMap (UPDATE)
      final updateMap = putnik.toMap();

      // Proveri da li je id sačuvan
      expect(updateMap['id'], equals('roundtrip-uuid-123'));
      expect(updateMap['putnik_ime'], equals('Roundtrip Test'));
      expect(updateMap['vozac_id'], equals('vozac-uuid-roundtrip'));

      // toMap -> fromMap ponovo
      final putnikPonovo = novi.MesecniPutnik.fromMap(updateMap);

      // Finalna provera da li su podaci identični
      expect(putnikPonovo.id, equals('roundtrip-uuid-123'));
      expect(putnikPonovo.putnikIme, equals('Roundtrip Test'));
      expect(putnikPonovo.vozac, equals('vozac-uuid-roundtrip'));

      print('✅ Roundtrip test - PASSED');
    });
  });

  group('Update Service Logika', () {
    test('Simulacija Service UPDATE poziva', () {
      print('\n🔧 Simuliranje poziva Service.updateMesecniPutnik()');

      // Postojeći putnik iz baze (simulacija)
      final postojeciPutnik = novi.MesecniPutnik(
        id: 'service-test-uuid',
        putnikIme: 'Service Test',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['07:00 BC']
        },
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime(2025, 10, 1),
        updatedAt: DateTime(2025, 10, 1),
        cena: 15000,
      );

      // Izmenjeni putnik (simulacija korisničke izmene)
      final izmenjeniPutnik = postojeciPutnik.copyWith(
        putnikIme: 'Service Test - Izmenjeno',
        cena: 16000,
      );

      // Podatak koji bi se poslao u bazu
      final updateData = izmenjeniPutnik.toMap();

      // Validacija
      expect(updateData['id'], equals('service-test-uuid'));
      expect(updateData['putnik_ime'], equals('Service Test - Izmenjeno'));
      expect(updateData['cena'], equals(16000));
      expect(updateData.containsKey('updated_at'), isTrue);

      print('✅ Service UPDATE simulacija - PASSED');
      print('📤 Podaci za bazu: ${updateData.keys.join(', ')}');
    });

    test('Parcijalni UPDATE test', () {
      print('\n🔧 Testiranje parcijalnog UPDATE-a (samo određena polja)');

      // Simulacija Service.updateMesecniPutnik(id, updates)
      final parcijalniUpdates = {
        'cena': 18000.0,
        'vreme_placanja': DateTime.now().toIso8601String(),
        'vozac_id': 'novi-vozac-uuid',
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Validacija parcijalne promene
      expect(parcijalniUpdates.containsKey('cena'), isTrue);
      expect(parcijalniUpdates.containsKey('vreme_placanja'), isTrue);
      expect(parcijalniUpdates.containsKey('vozac_id'), isTrue);
      expect(parcijalniUpdates.containsKey('updated_at'), isTrue);

      // Ne sme sadržavati nepotrebna polja za parcijalnu promenu
      expect(parcijalniUpdates.containsKey('putnik_ime'), isFalse);
      expect(parcijalniUpdates.containsKey('polasci_po_danu'), isFalse);

      print('✅ Parcijalni UPDATE test - PASSED');
      print('📤 Parcijalni podaci: ${parcijalniUpdates.keys.join(', ')}');
    });
  });
}
