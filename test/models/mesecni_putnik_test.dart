import 'package:flutter_test/flutter_test.dart';
import '../../lib/models/mesecni_putnik_novi.dart';

void main() {
  group('MesecniPutnik Model Tests', () {
    test('UUID handling - null vozac_id test', () {
      // Test case: prazan string za vozac
      final putnik = MesecniPutnik(
        id: '123e4567-e89b-12d3-a456-426614174000',
        putnikIme: 'Test Putnik',
        tip: 'djak',
        polasciPoDanu: {
          'pon': ['07:00 BC']
        },
        datumPocetkaMeseca: DateTime(2024, 1, 1),
        datumKrajaMeseca: DateTime(2024, 1, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: '', // PRAZAN STRING - treba da bude null u toMap()
      );

      final map = putnik.toMap();

      // Test da li je prazan string konvertovan u null
      expect(map['vozac_id'], isNull,
          reason: 'Prazan string za vozac_id treba da bude null u bazi');

      print('✅ Test 1 PASSED: Prazan string vozac_id konvertovan u null');
    });

    test('UUID handling - valid vozac_id test', () {
      final validUuid = '550e8400-e29b-41d4-a716-446655440000';

      final putnik = MesecniPutnik(
        id: '123e4567-e89b-12d3-a456-426614174000',
        putnikIme: 'Test Putnik 2',
        tip: 'djak',
        polasciPoDanu: {
          'uto': ['08:00 VS']
        },
        datumPocetkaMeseca: DateTime(2024, 1, 1),
        datumKrajaMeseca: DateTime(2024, 1, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: validUuid,
      );

      final map = putnik.toMap();

      // Test da li je validan UUID sačuvan
      expect(map['vozac_id'], equals(validUuid),
          reason: 'Validan UUID za vozac_id treba da ostane isti');

      print('✅ Test 2 PASSED: Validan UUID vozac_id sačuvan ispravno');
    });

    test('fromMap and toMap roundtrip test', () {
      final originalMap = {
        'id': '123e4567-e89b-12d3-a456-426614174000',
        'putnik_ime': 'Marko Petrović',
        'tip': 'djak',
        'polasci_po_danu': {
          'pon': ['07:30 BC', '15:00 VS'],
          'uto': ['07:30 BC'],
        },
        'datum_pocetka_meseca': '2024-01-01',
        'datum_kraja_meseca': '2024-01-31',
        'created_at': '2024-01-01T10:00:00Z',
        'updated_at': '2024-01-01T10:00:00Z',
        'vozac_id': null, // NULL UUID
        'poslednje_putovanje': '2024-01-15T08:30:00Z',
        'statistics': {},
      };

      // fromMap -> toMap test
      final putnik = MesecniPutnik.fromMap(originalMap);
      final resultMap = putnik.toMap();

      expect(resultMap['vozac_id'], isNull);
      expect(resultMap['putnik_ime'], equals('Marko Petrović'));
      expect(resultMap['poslednje_putovanje'], contains('2024-01-15'));

      print('✅ Test 3 PASSED: fromMap -> toMap roundtrip funkcioniše');
    });

    test('Error prone fields validation', () {
      // Test minimum required fields
      final testMap = {
        'id': '123e4567-e89b-12d3-a456-426614174000',
        'putnik_ime': 'Test User',
        'tip': 'djak',
        'polasci_po_danu': {
          'pon': ['07:00 BC']
        },
        'datum_pocetka_meseca': '2024-01-01',
        'datum_kraja_meseca': '2024-01-31',
        'created_at': '2024-01-01T10:00:00Z',
        'updated_at': '2024-01-01T10:00:00Z',
        'vozac_id': '', // PRAZAN STRING
        'poslednje_putovanje': null,
        'statistics': null,
      };

      expect(() => MesecniPutnik.fromMap(testMap), returnsNormally,
          reason: 'Model treba da rukuje null/empty vrednostima gracefully');

      final putnik = MesecniPutnik.fromMap(testMap);
      final map = putnik.toMap();

      // Validacija da nema prazne stringove za UUID
      expect(map['vozac_id'], isNull);
      expect(map['putnik_ime'], isNotNull);
      expect(map['statistics'], isA<Map>());

      print('✅ Test 4 PASSED: Error-prone fields handling radi ispravno');
    });

    test('poslednje_putovanje column name test', () {
      // Test da se koristi ispravno ime kolone
      final putnik = MesecniPutnik(
        id: '123e4567-e89b-12d3-a456-426614174000',
        putnikIme: 'Test Putnik',
        tip: 'djak',
        polasciPoDanu: {
          'pon': ['07:00 BC']
        },
        datumPocetkaMeseca: DateTime(2024, 1, 1),
        datumKrajaMeseca: DateTime(2024, 1, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        poslednjePutovanje: DateTime(2024, 1, 15),
      );

      final map = putnik.toMap();

      // Test da se koristi 'poslednje_putovanje' a ne 'poslednji_putovanje'
      expect(map.containsKey('poslednje_putovanje'), isTrue,
          reason: 'Map treba da sadrži poslednje_putovanje kolonu');
      expect(map.containsKey('poslednji_putovanje'), isFalse,
          reason: 'Map NE treba da sadrži staro ime poslednji_putovanje');

      print('✅ Test 5 PASSED: poslednje_putovanje kolona ispravno imenovana');
    });
  });
}
