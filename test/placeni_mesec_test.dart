import 'package:flutter_test/flutter_test.dart';
import '../lib/models/mesecni_putnik_novi.dart';

void main() {
  test('Placeni mesec - int tip', () {
    final map = {
      'id': 'test-id',
      'putnik_ime': 'Test Putnik',
      'tip': 'radnik',
      'polasci_po_danu': {
        'pon': {'bc': '07:00', 'vs': null}
      },
      'datum_pocetka_meseca': '2025-10-01',
      'datum_kraja_meseca': '2025-10-31',
      'placeni_mesec': 10, // Integer kao što šalje azurirajPlacanjeZaMesec
      'placena_godina': 2025,
    };

    final putnik = MesecniPutnik.fromMap(map);

    print(
        'Placeni mesec: ${putnik.placeniMesec} (${putnik.placeniMesec.runtimeType})');
    expect(putnik.placeniMesec, equals(10));
    expect(putnik.placenaGodina, equals(2025));

    final toMapResult = putnik.toMap();
    print('toMap placeni_mesec: ${toMapResult['placeni_mesec']}');
    expect(toMapResult['placeni_mesec'], equals(10));
  });
}
