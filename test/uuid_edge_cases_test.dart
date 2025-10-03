import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/mesecni_putnik_novi.dart';

void main() {
  group('Problematične UUID situacije', () {
    test('Simulira sve moguće problematične UUID vrednosti', () {
      print('\n🔍 Testiranje problematičnih UUID vrednosti...\n');

      // Test 1: Prazan string
      final putnik1 = MesecniPutnik(
        id: '123e4567-e89b-12d3-a456-426614174000',
        putnikIme: 'Test 1 - Prazan String',
        tip: 'djak',
        polasciPoDanu: {
          'pon': ['07:00 BC']
        },
        datumPocetkaMeseca: DateTime(2024, 1, 1),
        datumKrajaMeseca: DateTime(2024, 1, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: '', // PRAZAN STRING
      );

      final map1 = putnik1.toMap();
      print(
          '✅ Test 1: Prazan string vozac -> ${map1['vozac_id']} (${map1['vozac_id'].runtimeType})');
      expect(map1['vozac_id'], isNull);

      // Test 2: Null vrednost
      final putnik2 = MesecniPutnik(
        id: '123e4567-e89b-12d3-a456-426614174001',
        putnikIme: 'Test 2 - Null',
        tip: 'djak',
        polasciPoDanu: {
          'pon': ['07:00 BC']
        },
        datumPocetkaMeseca: DateTime(2024, 1, 1),
        datumKrajaMeseca: DateTime(2024, 1, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: null, // NULL
      );

      final map2 = putnik2.toMap();
      print(
          '✅ Test 2: Null vozac -> ${map2['vozac_id']} (${map2['vozac_id'].runtimeType})');
      expect(map2['vozac_id'], isNull);

      // Test 3: Validan UUID
      const validUuid = '550e8400-e29b-41d4-a716-446655440000';
      final putnik3 = MesecniPutnik(
        id: '123e4567-e89b-12d3-a456-426614174002',
        putnikIme: 'Test 3 - Valid UUID',
        tip: 'djak',
        polasciPoDanu: {
          'pon': ['07:00 BC']
        },
        datumPocetkaMeseca: DateTime(2024, 1, 1),
        datumKrajaMeseca: DateTime(2024, 1, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: validUuid, // VALIDAN UUID
      );

      final map3 = putnik3.toMap();
      print(
          '✅ Test 3: Valid UUID vozac -> ${map3['vozac_id']} (${map3['vozac_id'].runtimeType})');
      expect(map3['vozac_id'], equals(validUuid));

      // Test 4: Whitespace string (možda je to problem?)
      final putnik4 = MesecniPutnik(
        id: '123e4567-e89b-12d3-a456-426614174003',
        putnikIme: 'Test 4 - Whitespace',
        tip: 'djak',
        polasciPoDanu: {
          'pon': ['07:00 BC']
        },
        datumPocetkaMeseca: DateTime(2024, 1, 1),
        datumKrajaMeseca: DateTime(2024, 1, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: '   ', // WHITESPACE
      );

      final map4 = putnik4.toMap();
      print(
          '✅ Test 4: Whitespace vozac -> ${map4['vozac_id']} (${map4['vozac_id'].runtimeType})');
      // Trebalo bi da bude null jer trim() daje prazan string
      expect(map4['vozac_id'], isNull);

      print('\n🎯 SVI TESTOVI PROŠLI - UUID logika radi ispravno!');
    });

    test('Testira fromMap sa problematičnim podacima iz baze', () {
      print('\n🔍 Testiranje fromMap sa različitim podacima...\n');

      // Simulira podatke kako dolaze iz baze
      final problematicniPodaci = {
        'id': '123e4567-e89b-12d3-a456-426614174000',
        'putnik_ime': 'Test Putnik',
        'tip': 'djak',
        'polasci_po_danu': {
          'pon': ['07:00 BC']
        },
        'datum_pocetka_meseca': '2024-01-01',
        'datum_kraja_meseca': '2024-01-31',
        'created_at': '2024-01-01T10:00:00Z',
        'updated_at': '2024-01-01T10:00:00Z',
        'vozac_id': null, // NULL iz baze
        'poslednje_putovanje': null,
        'statistics': {},
      };

      final putnik = MesecniPutnik.fromMap(problematicniPodaci);
      print('✅ fromMap uspešno parsirao podatke sa null vozac_id');

      final backToMap = putnik.toMap();
      print('✅ toMap ponovo konvertovao u mapu');

      expect(backToMap['vozac_id'], isNull);
      expect(backToMap['putnik_ime'], equals('Test Putnik'));

      print('🎯 fromMap/toMap roundtrip USPEŠAN!');
    });

    test('Proverava sva UUID polja u modelu', () {
      print('\n🔍 Provera svih UUID polja u MesecniPutnik modelu...\n');

      final putnik = MesecniPutnik(
        id: '123e4567-e89b-12d3-a456-426614174000', // UUID ✅
        putnikIme: 'Test All UUIDs',
        tip: 'djak',
        polasciPoDanu: {
          'pon': ['07:00 BC']
        },
        datumPocetkaMeseca: DateTime(2024, 1, 1),
        datumKrajaMeseca: DateTime(2024, 1, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: '', // Prazan string -> treba biti null
      );

      final map = putnik.toMap();

      // Proverava sva UUID polja
      print('ID: ${map['id']} (${map['id'].runtimeType})');
      print('vozac_id: ${map['vozac_id']} (${map['vozac_id'].runtimeType})');

      expect(map['id'], isA<String>());
      expect(map['id'], isNotEmpty);
      expect(map['vozac_id'], isNull); // Ključno!

      print('🎯 Sva UUID polja su ispravno formirana!');
    });
  });
}
