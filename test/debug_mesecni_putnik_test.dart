import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/mesecni_putnik.dart';
import 'package:gavra_android/services/mesecni_putnik_service_novi.dart';

void main() {
  group('Debug mesečni putnici', () {
    test('Kreiraj test mesečnog putnika', () {
      // Kreiraj test objekat
      final testPutnik = MesecniPutnik(
        id: 'test-123',
        putnikIme: 'Test Putnik',
        tip: 'ucenik',
        polasciPoDanu: {
          'pon': ['5:00 BC', '14:00 VS'],
          'uto': ['5:00 BC', '14:00 VS'],
          'sre': ['5:00 BC', '14:00 VS'],
          'cet': ['5:00 BC', '14:00 VS'],
          'pet': ['5:00 BC', '14:00 VS'],
        },
        radniDani: 'pon,uto,sre,cet,pet',
        datumPocetkaMeseca: DateTime(2025, 10, 1),
        datumKrajaMeseca: DateTime(2025, 10, 31),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Test osnovne funkcionalnosti
      expect(testPutnik.putnikIme, 'Test Putnik');
      expect(testPutnik.tip, 'ucenik');
      expect(testPutnik.aktivan, true); // default vrednost
      expect(testPutnik.obrisan, false); // default vrednost
      expect(testPutnik.polasciPoDanu.keys.length, 5); // 5 radnih dana

      // Test da li može da se konvertuje u mapu
      final mapa = testPutnik.toMap();
      expect(mapa['putnik_ime'], 'Test Putnik');
      expect(mapa['tip'], 'ucenik');
      expect(mapa['aktivan'], true);
      expect(mapa['obrisan'], false);

      print('✅ Test mesečni putnik uspešno kreiran!');
      print('📋 Mapa: $mapa');
    });

    test('Test RealTime service kombinaciji', () {
      // Test da li RealtimeService može da parsira mesečne putnike
      final mockData = {
        'id': 'test-456',
        'putnik_ime': 'Mock Putnik',
        'tip': 'ucenik',
        'polasci_po_danu': {
          'pon': ['5:00 BC', '14:00 VS'],
          'pet': ['5:00 BC', '14:00 VS'],
        },
        'radni_dani': 'pon,pet',
        'aktivan': true,
        'obrisan': false,
        'datum_pocetka_meseca': '2025-10-01',
        'datum_kraja_meseca': '2025-10-31',
        'created_at': '2025-10-03T10:00:00Z',
        'updated_at': '2025-10-03T10:00:00Z',
      };

      // Test da li MesecniPutnik.fromMap može da parsira
      expect(() {
        final putnik = MesecniPutnik.fromMap(mockData);
        expect(putnik.putnikIme, 'Mock Putnik');
        expect(putnik.tip, 'ucenik');
        print('✅ MesecniPutnik.fromMap radi ispravno!');
      }, returnsNormally);
    });
  });
}
