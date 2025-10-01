import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/mesecni_putnik.dart';

void main() {
  group('MesecniPutnik Model Tests', () {
    test('fromMap should handle putnik_ime column correctly', () {
      final map = {
        'id': 'test-id',
        'putnik_ime': 'Test Putnik',
        'tip': 'osnovna',
        'polasci_po_danu': '{"pon": ["6 VS"]}',
        'datum_pocetka_meseca': '2025-01-01',
        'datum_kraja_meseca': '2025-01-31',
        'created_at': '2025-01-01T00:00:00Z',
        'updated_at': '2025-01-01T00:00:00Z',
      };

      final putnik = MesecniPutnik.fromMap(map);

      expect(putnik.id, 'test-id');
      expect(putnik.putnikIme, 'Test Putnik');
      expect(putnik.tip, 'osnovna');
    });

    test('fromMap should handle fallback to ime column', () {
      final map = {
        'id': 'test-id',
        'ime': 'Test Putnik Fallback',
        'tip': 'osnovna',
        'polasci_po_danu': '{"pon": ["6 VS"]}',
        'datum_pocetka_meseca': '2025-01-01',
        'datum_kraja_meseca': '2025-01-31',
        'created_at': '2025-01-01T00:00:00Z',
        'updated_at': '2025-01-01T00:00:00Z',
      };

      final putnik = MesecniPutnik.fromMap(map);

      expect(putnik.id, 'test-id');
      expect(putnik.putnikIme, 'Test Putnik Fallback');
      expect(putnik.tip, 'osnovna');
    });

    test('toMap should use putnik_ime column', () {
      final putnik = MesecniPutnik(
        id: 'test-id',
        putnikIme: 'Test Putnik',
        tip: 'osnovna',
        polasciPoDanu: {
          'pon': ['6 VS']
        },
        datumPocetkaMeseca: DateTime(2025, 1, 1),
        datumKrajaMeseca: DateTime(2025, 1, 31),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final map = putnik.toMap();

      expect(map['putnik_ime'], 'Test Putnik');
      expect(map['ime'], isNull); // Should not have 'ime' key
    });
  });
}
