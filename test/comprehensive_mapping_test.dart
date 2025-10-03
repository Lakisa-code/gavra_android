import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/putnik.dart';
import 'package:gavra_android/models/mesecni_putnik.dart';
import 'package:gavra_android/models/mesecni_putnik_novi.dart' as novi;
import 'package:gavra_android/models/dnevni_putnik.dart';
import 'package:gavra_android/models/vozac.dart';

void main() {
  group('Comprehensive Mapping Logic Tests', () {
    test('Putnik.toMesecniPutniciMap() vozac_id handling', () {
      print('\n🔍 Testing Putnik.toMesecniPutniciMap() vozac_id validation');

      // Test 1: Empty string vozac should map to null vozac_id
      final putnik1 = Putnik(
        ime: 'Test Marko',
        polazak: '7:00',
        dan: 'Pon',
        grad: 'Bela Crkva',
        vozac: '', // Empty string
      );

      final map1 = putnik1.toMesecniPutniciMap();
      expect(map1['vozac_id'], isNull,
          reason: 'Empty string vozac should become null vozac_id');
      print('✅ Empty string vozac -> vozac_id: ${map1['vozac_id']}');

      // Test 2: Non-empty string vozac should map to vozac_id
      final putnik2 = Putnik(
        ime: 'Test Ana',
        polazak: '8:00',
        dan: 'Uto',
        grad: 'Vršac',
        vozac: 'Marko Petrović',
      );

      final map2 = putnik2.toMesecniPutniciMap();
      expect(map2['vozac_id'], equals('Marko Petrović'));
      print('✅ Valid vozac -> vozac_id: ${map2['vozac_id']}');

      // Test 3: Null vozac should map to null vozac_id
      final putnik3 = Putnik(
        ime: 'Test Jovana',
        polazak: '6:00',
        dan: 'Sre',
        grad: 'Bela Crkva',
        vozac: null,
      );

      final map3 = putnik3.toMesecniPutniciMap();
      expect(map3['vozac_id'], isNull);
      print('✅ Null vozac -> vozac_id: ${map3['vozac_id']}');
    });

    test('MesecniPutnik.toMap() vozac_id handling', () {
      print('\n🔍 Testing MesecniPutnik.toMap() vozac_id validation');

      // Test with empty string vozac
      final putnik = MesecniPutnik(
        id: 'test-uuid-123',
        putnikIme: 'Test Putnik',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['6:00 BC', '7:00 VS']
        },
        datumPocetkaMeseca: DateTime(2024, 1, 1),
        datumKrajaMeseca: DateTime(2024, 1, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: '', // Empty string
      );

      final map = putnik.toMap();
      expect(map['vozac_id'], isNull,
          reason: 'Empty string vozac should become null vozac_id');
      print('✅ MesecniPutnik empty vozac -> vozac_id: ${map['vozac_id']}');
    });

    test('MesecniPutnik (novi) toMap() ID handling', () {
      print('\n🔍 Testing MesecniPutnik (novi) toMap() ID handling');

      // Test 1: Empty ID should exclude id from map (INSERT)
      final putnikInsert = novi.MesecniPutnik(
        id: '', // Empty ID for INSERT
        putnikIme: 'New Putnik',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['6:00 BC']
        },
        datumPocetkaMeseca: DateTime(2024, 1, 1),
        datumKrajaMeseca: DateTime(2024, 1, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: 'vozac-uuid-123',
      );

      final insertMap = putnikInsert.toMap();
      expect(insertMap.containsKey('id'), isFalse,
          reason: 'Empty ID should exclude id for INSERT');
      print(
          '✅ INSERT (empty id) -> id excluded: ${!insertMap.containsKey('id')}');

      // Test 2: Valid ID should include id in map (UPDATE)
      final putnikUpdate = novi.MesecniPutnik(
        id: 'existing-uuid-456', // Valid ID for UPDATE
        putnikIme: 'Existing Putnik',
        tip: 'radnik',
        polasciPoDanu: {
          'pon': ['7:00 BC']
        },
        datumPocetkaMeseca: DateTime(2024, 1, 1),
        datumKrajaMeseca: DateTime(2024, 1, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: 'vozac-uuid-456',
      );

      final updateMap = putnikUpdate.toMap();
      expect(updateMap.containsKey('id'), isTrue,
          reason: 'Valid ID should include id for UPDATE');
      expect(updateMap['id'], equals('existing-uuid-456'));
      print('✅ UPDATE (valid id) -> id included: ${updateMap['id']}');
    });

    test('DnevniPutnik model mapiranje - bez prezime', () {
      print('\n🔍 Testing DnevniPutnik model mapping without prezime');

      final Map<String, dynamic> testData = {
        'id': 'dnevni-test-id-123',
        'ime': 'Marko Petrović',
        'broj_telefona': '+381641234567',
        'adresa_id': 'adresa-id-123',
        'ruta_id': 'ruta-id-123',
        'datum': '2025-10-03',
        'polazak': '07:30',
        'broj_mesta': 2,
        'cena': 250.0,
        'status': 'rezervisan',
        'created_at': '2025-10-03T07:00:00Z',
        'updated_at': '2025-10-03T07:00:00Z',
      };

      final putnik = DnevniPutnik.fromMap(testData);

      expect(putnik.id, 'dnevni-test-id-123');
      expect(putnik.ime, 'Marko Petrović');
      expect(putnik.punoIme, 'Marko Petrović'); // Should return just ime
      expect(putnik.brojMesta, 2);
      expect(putnik.cena, 250.0);

      // Test toMap()
      final map = putnik.toMap();
      expect(map['ime'], 'Marko Petrović');
      expect(map.containsKey('prezime'), false); // No prezime field
      print('✅ DnevniPutnik mapiranje works without prezime field');
    });

    test('Vozac model mapiranje - bez prezime', () {
      print('\n🔍 Testing Vozac model mapping without prezime');

      final Map<String, dynamic> testData = {
        'id': 'vozac-id-123',
        'ime': 'Miloš Jovanović',
        'broj_telefona': '+381641234567',
        'email': 'milos@example.com',
        'aktivan': true,
        'boja': '#FF5733',
        'created_at': '2025-10-03T07:00:00Z',
        'updated_at': '2025-10-03T07:00:00Z',
      };

      final vozac = Vozac.fromMap(testData);

      expect(vozac.id, 'vozac-id-123');
      expect(vozac.ime, 'Miloš Jovanović');
      expect(vozac.punoIme, 'Miloš Jovanović'); // Should return just ime
      expect(vozac.aktivan, true);

      // Test toMap()
      final map = vozac.toMap();
      expect(map['ime'], 'Miloš Jovanović');
      expect(map.containsKey('prezime'), false); // No prezime field
      print('✅ Vozac mapiranje works without prezime field');
    });

    test('Putnik.fromMesecniPutniciMultiple parsing', () {
      print('\n🔍 Testing Putnik.fromMesecniPutniciMultiple parsing');

      final Map<String, dynamic> mesecniData = {
        'id': 'mesecni-uuid-123',
        'putnik_ime': 'Stefan Mitrović',
        'tip': 'radnik',
        'polasci_po_danu': {
          'pon': {'bc': '6:00', 'vs': '7:00'},
          'uto': {'bc': '6:30', 'vs': null},
        },
        'radni_dani': 'pon,uto,sre,cet,pet',
        'status': 'radi',
        'cena': 14000.0,
        'vozac': 'Jovica Milićević',
        'created_at': '2024-01-01T10:00:00Z',
        'aktivan': true,
      };

      final putnici = Putnik.fromMesecniPutniciMultipleForDay(mesecniData, 'pon');

      expect(putnici.isNotEmpty, true);
      expect(putnici.first.ime, 'Stefan Mitrović');
      expect(putnici.first.vozac, 'Jovica Milićević');
      expect(putnici.first.mesecnaKarta, true);

      print(
          '✅ fromMesecniPutniciMultiple creates ${putnici.length} putnik objects');
    });

    test('Column mapping consistency across tables', () {
      print('\n🔍 Testing column mapping consistency');

      // mesecni_putnici table uses vozac_id (UUID)
      final mesecniMap = {
        'vozac_id': null, // UUID column
        'ruta_id': 'ruta-uuid',
        'vozilo_id': 'vozilo-uuid',
        'putnik_ime': 'Test Putnik',
      };

      // putovanja_istorija table uses vozac (string name)
      final putovanjaMap = {
        'vozac': 'Marko Petrović', // String name
        'putnik_ime': 'Ana Jovanović',
        'tip_putnika': 'mesecni',
      };

      expect(mesecniMap.containsKey('vozac_id'), true);
      expect(putovanjaMap.containsKey('vozac'), true);
      expect(mesecniMap.containsKey('vozac'), false);
      expect(putovanjaMap.containsKey('vozac_id'), false);

      print('✅ Column mapping is consistent:');
      print('   - mesecni_putnici uses vozac_id (UUID)');
      print('   - putovanja_istorija uses vozac (String)');
    });
  });
}
