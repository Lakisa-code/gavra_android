import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/dnevni_putnik.dart';
import 'package:gavra_android/models/vozac.dart';

void main() {
  group('Model mapiranje testovi', () {
    test('DnevniPutnik model mapiranje - bez prezime', () {
      final Map<String, dynamic> testData = {
        'id': 'test-id-123',
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

      expect(putnik.id, 'test-id-123');
      expect(putnik.ime, 'Marko Petrović');
      expect(putnik.punoIme, 'Marko Petrović'); // Sada vraća samo ime
      expect(putnik.brojMesta, 2);
      expect(putnik.cena, 250.0);
      expect(putnik.status, DnevniPutnikStatus.rezervisan);

      // Test toMap()
      final map = putnik.toMap();
      expect(map['ime'], 'Marko Petrović');
      expect(map['broj_mesta'], 2);
      expect(map.containsKey('prezime'), false); // Nema prezime
    });

    test('Vozac model mapiranje - bez prezime', () {
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
      expect(vozac.punoIme, 'Miloš Jovanović'); // Sada vraća samo ime
      expect(vozac.aktivan, true);

      // Test toMap()
      final map = vozac.toMap();
      expect(map['ime'], 'Miloš Jovanović');
      expect(map.containsKey('prezime'), false); // Nema prezime
    });
  });
}
