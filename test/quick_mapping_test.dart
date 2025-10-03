import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/mesecni_putnik_novi.dart';

void main() {
  group('MesecniPutnikNovi toMap test', () {
    test('toMap should exclude empty id for INSERT operation', () {
      final putnik = MesecniPutnik(
        id: '', // Empty ID simulates new record
        putnikIme: 'Test Putnik Test Prezime',
        tip: 'radnik',
        brojTelefona: '123456789',
        polasciPoDanu: {
          'pon': ['6:00 BC']
        },
        datumPocetkaMeseca: DateTime(2024, 1, 1),
        datumKrajaMeseca: DateTime(2024, 1, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: 'vozac-123-uuid',
      );

      final map = putnik.toMap();

      print('Map for INSERT (empty id): $map');
      expect(map.containsKey('id'), false);
      expect(map['vozac_id'], equals('vozac-123-uuid'));
      expect(map['putnik_ime'], equals('Test Putnik Test Prezime'));
    });

    test('toMap should include valid id for UPDATE operation', () {
      final putnik = MesecniPutnik(
        id: 'existing-uuid-123',
        putnikIme: 'Updated Putnik Updated Prezime',
        tip: 'radnik',
        brojTelefona: '987654321',
        polasciPoDanu: {
          'pon': ['6:00 BC']
        },
        datumPocetkaMeseca: DateTime(2024, 1, 1),
        datumKrajaMeseca: DateTime(2024, 1, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: 'vozac-456-uuid',
      );

      final map = putnik.toMap();

      print('Map for UPDATE (valid id): $map');
      expect(map.containsKey('id'), true);
      expect(map['id'], equals('existing-uuid-123'));
      expect(map['vozac_id'], equals('vozac-456-uuid'));
      expect(map['putnik_ime'], equals('Updated Putnik Updated Prezime'));
    });

    test('toMap should handle null values correctly', () {
      final putnik = MesecniPutnik(
        id: '',
        putnikIme: 'Minimal Putnik Minimal Prezime',
        tip: 'radnik',
        brojTelefona: null,
        polasciPoDanu: {
          'pon': ['6:00 BC']
        },
        datumPocetkaMeseca: DateTime(2024, 1, 1),
        datumKrajaMeseca: DateTime(2024, 1, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vozac: 'vozac-789-uuid',
      );

      final map = putnik.toMap();

      print('Map with nulls: $map');
      expect(map.containsKey('id'), false);
      expect(map['broj_telefona'], isNull);
    });
  });
}
