import 'package:flutter_test/flutter_test.dart';
import 'package:gavra_android/models/mesecni_putnik.dart';

void main() {
  test('MesecniPutnik.toMap normalizes polasci and builds statistics', () {
    final mp = MesecniPutnik(
      id: '123',
      putnikIme: 'Test',
      tip: 'radnik',
      polasciPoDanu: {
        'pon': ['6:00 BC', '14:00 VS'],
        'uto': ['6:00 BC'],
      },
      datumPocetkaMeseca: DateTime(2025, 9),
      datumKrajaMeseca: DateTime(2025, 9, 30),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      ukupnaCenaMeseca: 17000,
      cena: 17000,
    );

    final map = mp.toMap();
    expect(map['polasci_po_danu']['pon']['bc'], '06:00');
    expect(map['polasci_po_danu']['pon']['vs'], '14:00');
    expect(map['statistics']['trips_total'], 0);
  });
}
